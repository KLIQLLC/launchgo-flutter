import Flutter
import UIKit
import GoogleMaps
import stream_video_push_notification
import flutter_callkit_incoming
import PushKit
import CallKit
import Security
import AVFAudio

@main
@objc class AppDelegate: FlutterAppDelegate, CallkitIncomingAppDelegate {
  
  
  private var callValidityTimer: Timer?
  private var activeCallCid: String?
  private var methodChannel: FlutterMethodChannel?
  private var callKitChannel: FlutterMethodChannel?  // Channel for Dart to force end CallKit
  private var pushKitChannel: FlutterMethodChannel?  // Channel for VoIP push control
  private var apnsChannel: FlutterMethodChannel?     // Channel for APNs token (non-VoIP) for chat pushes
  private var streamVideoAuthChannel: FlutterMethodChannel? // Channel for storing Stream Video auth for native reject
  private var videoToggleChannel: FlutterMethodChannel? // Channel to notify Flutter when user taps Video button
  private let callObserver = CXCallObserver() // For observing CallKit state
  
  // Keep a strong reference to PushKit registry
  private let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
  
  // Track current VoIP token
  private var currentVoipToken: String?
  
  // Track current APNs token (non-VoIP)
  private var currentApnsToken: String?
  
  // Keychain keys for native Stream Video reject flow
  private let keychainService = "com.launchgo.streamvideo"
  private let keychainAccountToken = "user_token"
  private let keychainAccountApiKey = "api_key"
  
  // Native polling to stop CallKit if cancel push is missed (cold start)
  private var nativeCallPollTimer: Timer?
  private var nativePollCallCid: String?
  
  // Track if VoIP is enabled (can be disabled on logout)
  private var voipEnabled: Bool = true
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCjAwFEVV741BblWxJ9esBvD5v2enGhVg4")
    GeneratedPluginRegistrant.register(with: self)

    // Setup method channels
    if let controller = window?.rootViewController as? FlutterViewController {
      // Channel for call validity timer
      methodChannel = FlutterMethodChannel(
        name: "com.launchgo.app/call_validity",
        binaryMessenger: controller.binaryMessenger
      )
      
      methodChannel?.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "startTimer":
          if let args = call.arguments as? [String: Any],
             let cid = args["cid"] as? String {
            self?.startCallValidityTimer(callCid: cid)
            result(nil)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing cid", details: nil))
          }
        case "stopTimer":
          self?.stopCallValidityTimer()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      
      // Channel for Dart to force end CallKit (uses saveEndCall which is reliable)
      callKitChannel = FlutterMethodChannel(
        name: "com.launchgo.app/callkit",
        binaryMessenger: controller.binaryMessenger
      )
      
      callKitChannel?.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "forceEndAllCalls":
          self?.forceEndAllCallKitCalls()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      
      // Channel for VoIP push control (enable/disable/getToken)
      pushKitChannel = FlutterMethodChannel(
        name: "com.launchgo.app/pushkit",
        binaryMessenger: controller.binaryMessenger
      )
      
      pushKitChannel?.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "enableVoip":
          guard let self else {
            result(nil)
            return
          }
          self.voipEnabled = true
          // Re-enable PushKit token updates.
          self.voipRegistry.desiredPushTypes = [.voIP]
          print("[VC] 📞 [AppDelegate] PushKit ENABLED (voipEnabled=true, desiredPushTypes=[voIP])")
          result(nil)
        case "disableVoip":
          guard let self else {
            result(nil)
            return
          }
          self.voipEnabled = false
          // Stop PushKit token updates so we can't re-register devices after logout.
          self.voipRegistry.desiredPushTypes = []
          // Best-effort: tell Stream SDK token is invalidated.
          StreamVideoPKDelegateManager.shared.pushRegistry(self.voipRegistry, didInvalidatePushTokenFor: .voIP)
          print("[VC] 📞 [AppDelegate] PushKit DISABLED (voipEnabled=false, desiredPushTypes=[])")
          result(nil)
        case "getVoipToken":
          
          result(self?.currentVoipToken)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      
      // Channel for APNs token (non-VoIP) used for chat pushes (PushProvider.apn)
      apnsChannel = FlutterMethodChannel(
        name: "com.launchgo.app/apns",
        binaryMessenger: controller.binaryMessenger
      )
      
      apnsChannel?.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "getApnsToken":
          let tokenPrefix = self?.currentApnsToken?.prefix(16) ?? "nil"
          
          result(self?.currentApnsToken)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      
      // Channel to store Stream Video auth in Keychain so native iOS can reject calls when Flutter is not running.
      streamVideoAuthChannel = FlutterMethodChannel(
        name: "com.launchgo.app/stream_video_auth",
        binaryMessenger: controller.binaryMessenger
      )
      
      streamVideoAuthChannel?.setMethodCallHandler { [weak self] (call, result) in
        guard let self else {
          result(FlutterError(code: "NO_SELF", message: "AppDelegate deallocated", details: nil))
          return
        }
        switch call.method {
        case "set":
          if let args = call.arguments as? [String: Any],
             let apiKey = args["apiKey"] as? String,
             let token = args["token"] as? String {
            self.keychainSet(account: self.keychainAccountApiKey, value: apiKey)
            self.keychainSet(account: self.keychainAccountToken, value: token)
            
            result(true)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing apiKey/token", details: nil))
          }
        case "clear":
          self.keychainDelete(account: self.keychainAccountApiKey)
          self.keychainDelete(account: self.keychainAccountToken)
          
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      
      // Channel to notify Flutter when user taps Video button in CallKit
      videoToggleChannel = FlutterMethodChannel(
        name: "com.launchgo.app/video_toggle",
        binaryMessenger: controller.binaryMessenger
      )
    }

    // Register for VoIP push notifications - we handle them ourselves
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - APNs (non-VoIP) token
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    currentApnsToken = token
    
    
    // Best-effort notify Flutter if it is listening (optional)
    apnsChannel?.invokeMethod("apnsTokenUpdated", arguments: ["token": token])
    
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // MARK: - CallkitIncomingAppDelegate (native callbacks for CallKit actions)
  
  func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
    // Flutter handles accept (and joining). Just fulfill.
    
    stopNativeCallPoll()
    action.fulfill()
  }
  
  func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    
    stopNativeCallPoll()
    // If VoIP is disabled (logged out), just end UI.
    if !voipEnabled {
      action.fulfill()
      return
    }
    
    // Reject call on Stream so caller stops ringing even if Flutter is not running.
    nativeRejectStreamVideoCall(from: call, reason: "decline")
    action.fulfill()
  }
  
  func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    // Hangup after accept; let Flutter/SDK handle. Just fulfill.
    
    stopNativeCallPoll()
    action.fulfill()
  }
  
  func onTimeOut(_ call: flutter_callkit_incoming.Call) {
    
    stopNativeCallPoll()
    if !voipEnabled { return }
    nativeRejectStreamVideoCall(from: call, reason: "timeout")
  }
  
  func didActivateAudioSession(_ audioSession: AVAudioSession) {}
  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {}
  
  // MARK: - Native reject call (Stream Video)
  
  private func nativeRejectStreamVideoCall(from call: flutter_callkit_incoming.Call, reason: String) {
    // Extract call_cid from CallKit extra payload
    let extra = call.data.extra as? [String: Any]
    let callCid = extra?["call_cid"] as? String ?? extra?["stream_call_cid"] as? String
    guard let callCid, callCid.contains(":") else {
      
      return
    }
    let parts = callCid.split(separator: ":", maxSplits: 1).map(String.init)
    if parts.count != 2 { return }
    let callType = parts[0]
    let callId = parts[1]
    
    guard let apiKey = keychainGet(account: keychainAccountApiKey),
          let token = keychainGet(account: keychainAccountToken) else {
      
      return
    }
    
    // Fire-and-forget request in a short background task
    var bg: UIBackgroundTaskIdentifier = .invalid
    bg = UIApplication.shared.beginBackgroundTask(withName: "reject_call") {
      UIApplication.shared.endBackgroundTask(bg)
      bg = .invalid
    }
    
    let urlStr = "https://video.stream-io-api.com/video/call/\(callType)/\(callId)/reject?api_key=\(apiKey)"
    guard let url = URL(string: urlStr) else { return }
    
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let body: [String: Any] = ["reason": reason]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) as Foundation.Data
    
    
    URLSession.shared.dataTask(with: req) { _, response, error in
      if let error {
        
      } else if let http = response as? HTTPURLResponse {
        
      }
      if bg != .invalid {
        UIApplication.shared.endBackgroundTask(bg)
      }
    }.resume()
  }
  
  private func startNativeCallPoll(callCid: String) {
    // Poll call state from Stream Video API and end CallKit if call ended/rejected.
    nativeCallPollTimer?.invalidate()
    nativePollCallCid = callCid
    
    // Poll every 2s, max ~90s
    var ticks = 0
    nativeCallPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      ticks += 1
      if ticks > 45 { // 90 seconds
        self.stopNativeCallPoll()
        return
      }
      self.pollCallOnce()
    }
    RunLoop.current.add(nativeCallPollTimer!, forMode: .common)
    pollCallOnce()
  }
  
  private func stopNativeCallPoll() {
    nativeCallPollTimer?.invalidate()
    nativeCallPollTimer = nil
    nativePollCallCid = nil
  }
  
  private func pollCallOnce() {
    guard voipEnabled else { return }
    guard let callCid = nativePollCallCid else { return }
    guard callCid.contains(":") else { return }
    let parts = callCid.split(separator: ":", maxSplits: 1).map(String.init)
    if parts.count != 2 { return }
    let callType = parts[0]
    let callId = parts[1]
    
    guard let apiKey = keychainGet(account: keychainAccountApiKey),
          let token = keychainGet(account: keychainAccountToken) else {
      // no auth -> can't poll
      return
    }
    
    let urlStr = "https://video.stream-io-api.com/video/call/\(callType)/\(callId)?api_key=\(apiKey)"
    guard let url = URL(string: urlStr) else { return }
    
    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.setValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
      guard let self else { return }
      if error != nil { return }
      guard let http = response as? HTTPURLResponse else { return }
      // If call is gone (404) treat as ended and stop ringing.
      if http.statusCode == 404 {
        DispatchQueue.main.async {
          
          self.forceEndAllCallKitCalls()
          self.stopNativeCallPoll()
        }
        return
      }
      guard http.statusCode >= 200 && http.statusCode < 300 else { return }
      guard let data else { return }
      
      // Heuristic parse: if call.ended_at is non-null OR the response contains call.rejected/ended indicators, stop ringing.
      if let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
         let call = json["call"] as? [String: Any] {
        let endedAt = call["ended_at"]
        if endedAt != nil && !(endedAt is NSNull) {
          DispatchQueue.main.async {
            
            self.forceEndAllCallKitCalls()
            self.stopNativeCallPoll()
          }
          return
        }
      }
    }.resume()
  }
  
  // MARK: - Keychain helpers
  
  private func keychainSet(account: String, value: String) {
    let data = value.data(using: .utf8) ?? Foundation.Data()
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account
    ]
    let attrs: [String: Any] = [kSecValueData as String: data]
    let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
    if status == errSecItemNotFound {
      var addQuery = query
      addQuery[kSecValueData as String] = data
      SecItemAdd(addQuery as CFDictionary, nil)
    }
  }
  
  private func keychainGet(account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Foundation.Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
  
  private func keychainDelete(account: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account
    ]
    SecItemDelete(query as CFDictionary)
  }
  
  // MARK: - Call Validity Timer
  
  private func startCallValidityTimer(callCid: String) {
    print("[AppDelegate] 📞 Starting call validity timer for: \(callCid)")
    activeCallCid = callCid
    
    // Stop any existing timer
    callValidityTimer?.invalidate()
    
    // Timer fires every second to check if call is still valid
    callValidityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.checkCallValidity()
    }
    
    // Keep timer running when app is in background
    RunLoop.current.add(callValidityTimer!, forMode: .common)
    
    // Fire immediately
    checkCallValidity()
  }
  
  private func stopCallValidityTimer() {
    print("[AppDelegate] 📞 Stopping call validity timer")
    callValidityTimer?.invalidate()
    callValidityTimer = nil
    activeCallCid = nil
  }
  
  private func checkCallValidity() {
    guard let cid = activeCallCid else { return }
    
    print("[AppDelegate] 📞 Checking call validity for: \(cid)")
    
    // Ask Flutter if call is still valid
    methodChannel?.invokeMethod("checkCallValidity", arguments: ["cid": cid]) { [weak self] result in
      if let isValid = result as? Bool {
        print("[AppDelegate] 📞 Call validity: \(isValid)")
        if !isValid {
          print("[AppDelegate] 📞 Call cancelled - ending CallKit via saveEndCall")
          self?.forceEndAllCallKitCalls()
          self?.stopCallValidityTimer()
        }
      } else if let error = result as? FlutterError {
        print("[AppDelegate] ⚠️ Error: \(error.message ?? "unknown")")
      }
    }
  }
  
  // MARK: - Force End CallKit (uses saveEndCall which bypasses plugin's internal call list)
  
  /// Ends all CallKit calls using saveEndCall() which directly reports to iOS.
  /// This is more reliable than endAllCalls() which fails if calls aren't in plugin's internal list.
  private func forceEndAllCallKitCalls() {
    let calls = callObserver.calls
    print("[AppDelegate] 📞 forceEndAllCallKitCalls: found \(calls.count) system calls")
    
    for call in calls {
      print("[AppDelegate] 📞 Ending call via saveEndCall: \(call.uuid.uuidString)")
      // reason 2 = CXCallEndedReason.remoteEnded
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.saveEndCall(call.uuid.uuidString, 2)
    }
    
    // Also call endAllCalls as backup (handles plugin's internal state)
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
  }
}

// MARK: - PKPushRegistryDelegate
extension AppDelegate: PKPushRegistryDelegate {
  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    
    // Store token for Dart to retrieve
    currentVoipToken = token
    let prefix = String(token.prefix(16))
    print("[VC] 📞 [AppDelegate] PushKit didUpdate token=\(prefix)... voipEnabled=\(voipEnabled)")
    
    // CRITICAL: If user is logged out, do NOT forward token to Stream SDK,
    // otherwise it can (re)register voip_apns device after logout.
    if !voipEnabled {
      print("[VC] 📞 [AppDelegate] PushKit token update ignored (voipEnabled=false)")
      return
    }
    
    // Forward token to Stream SDK (this registers/updates voip_apns device)
    StreamVideoPKDelegateManager.shared.pushRegistry(registry, didUpdate: pushCredentials, for: type)
    print("[VC] 📞 [AppDelegate] PushKit token forwarded to StreamVideoPKDelegateManager")
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    
    StreamVideoPKDelegateManager.shared.pushRegistry(registry, didInvalidatePushTokenFor: type)
    print("[VC] 📞 [AppDelegate] PushKit didInvalidatePushTokenFor type=\(type.rawValue)")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    

    // If VoIP is disabled (user logged out), ignore the push but still call completion
    if !voipEnabled {
      
      completion()
      return
    }

    // Extract Stream call info from payload
    var streamCallCid: String? = nil
    var pushType: String? = nil
    var callerName: String = "Incoming Call"

    let streamPayload = payload.dictionaryPayload["stream"] as? [String: Any]
                        ?? payload.dictionaryPayload["stream_video"] as? [String: Any]

    if let stream = streamPayload {
      streamCallCid = stream["call_cid"] as? String
      pushType = stream["type"] as? String
      callerName = stream["created_by_display_name"] as? String ?? "Incoming Call"
      
    }

    // Handle call cancellation pushes.
    // Stream can send different call.* types depending on SDK/server version.
    // If we receive ANY call.* push that is NOT call.ring, it means the ringing UI should end.
    if let pt = pushType, pt.hasPrefix("call.") && pt != "call.ring" {
      
      forceEndAllCallKitCalls()
      completion()
      return
    }

    // Only show CallKit for call.ring pushes
    guard pushType == "call.ring", let callCid = streamCallCid else {
      
      completion()
      return
    }

    // Extract just the call ID from the call_cid (format: "default:xxx")
    let callId = callCid.components(separatedBy: ":").last ?? callCid

    // End any previous CallKit calls before showing new one (prevents stacking)
    
    forceEndAllCallKitCalls()

    

    // Create a unique UUID for CallKit
    let uuid = UUID()

    // Build CallKitParams for flutter_callkit_incoming
    // type: 0 = audio call (hasVideo: false) - user can tap Video button to upgrade
    // This keeps the call in CallKit audio mode until user explicitly requests video
    let callKitParams: [String: Any] = [
      "id": uuid.uuidString,
      "nameCaller": callerName,
      "appName": "LaunchGo",
      "handle": "Audio Call",
      "type": 0, // 0 = audio call - stays in CallKit UI until user taps Video
      "textAccept": "Accept",
      "textDecline": "Decline",
      "duration": 60000, // 60 seconds ring
      "extra": [
        "call_cid": callCid,
        "call_id": callId,
        "stream_call_cid": callCid
      ],
      "ios": [
        "iconName": "CallKitIcon",
        "handleType": "generic",
        "supportsVideo": true, // Show Video button in CallKit UI
        "maximumCallGroups": 1,
        "maximumCallsPerCallGroup": 1,
        "audioSessionMode": "voiceChat", // Audio mode for now, video later
        "audioSessionActive": true,
        "audioSessionPreferredSampleRate": 44100.0,
        "audioSessionPreferredIOBufferDuration": 0.005,
        "supportsDTMF": false,
        "supportsHolding": false,
        "supportsGrouping": false,
        "supportsUngrouping": false,
        "ringtonePath": nil
      ]
    ]

    // Show CallKit via flutter_callkit_incoming
    let callData = flutter_callkit_incoming.Data(args: callKitParams as NSDictionary)
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      callData,
      fromPushKit: true
    )

    

    // Cold-start safety: start polling Stream Video call state so we can stop ringing
    // even if the cancel push is missed by APNs/PushKit.
    startNativeCallPoll(callCid: callCid)

    completion()
  }
}
