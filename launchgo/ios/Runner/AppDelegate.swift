import Flutter
import UIKit
import GoogleMaps
import stream_video_push_notification
import flutter_callkit_incoming
import PushKit
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  private var callValidityTimer: Timer?
  private var activeCallCid: String?
  private var methodChannel: FlutterMethodChannel?
  private var callKitChannel: FlutterMethodChannel?  // Channel for Dart to force end CallKit
  private let callObserver = CXCallObserver() // For observing CallKit state
  
  // Keep a strong reference to PushKit registry
  private let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
  
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
    }

    // Register for VoIP push notifications - we handle them ourselves
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
    print("[AppDelegate] 📞 VoIP token updated: \(token.prefix(16))…")
    // Forward token to Stream SDK
    StreamVideoPKDelegateManager.shared.pushRegistry(registry, didUpdate: pushCredentials, for: type)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    print("[AppDelegate] 📞 VoIP token invalidated")
    StreamVideoPKDelegateManager.shared.pushRegistry(registry, didInvalidatePushTokenFor: type)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    print("[AppDelegate] 📞 VoIP push received")

    // NOTE:
    // Do NOT call into Flutter here (app may be terminated / Flutter not running in TestFlight),
    // otherwise we would incorrectly ignore VoIP pushes and only regular pushes would show.
    // Logout protection is handled by unregistering VoIP token from Stream on logout.

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
      print("[AppDelegate] 📞 Push type=\(pushType ?? "nil") call_cid=\(streamCallCid ?? "nil") caller=\(callerName)")
    }

    // Handle call cancellation pushes
    if pushType == "call.miss" || pushType == "call.ended" || pushType == "call.rejected" {
      print("[AppDelegate] 📞 Call cancel push - ending CallKit")
      forceEndAllCallKitCalls()
      completion()
      return
    }

    // Only show CallKit for call.ring pushes
    guard pushType == "call.ring", let callCid = streamCallCid else {
      print("[AppDelegate] 📞 Not a call.ring or no call_cid, ignoring")
      completion()
      return
    }

    // Extract just the call ID from the call_cid (format: "default:xxx")
    let callId = callCid.components(separatedBy: ":").last ?? callCid

    // End any previous CallKit calls before showing new one (prevents stacking)
    print("[AppDelegate] 📞 Clearing previous CallKit calls before showing new one")
    forceEndAllCallKitCalls()

    print("[AppDelegate] 📞 Showing CallKit for callId=\(callId)")

    // Create a unique UUID for CallKit
    let uuid = UUID()

    // Build CallKitParams for flutter_callkit_incoming
    let callKitParams: [String: Any] = [
      "id": uuid.uuidString,
      "nameCaller": callerName,
      "appName": "LaunchGo",
      "handle": "Video Call",
      "type": 1, // 1 = video call
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
        "supportsVideo": true,
        "maximumCallGroups": 1,
        "maximumCallsPerCallGroup": 1,
        "audioSessionMode": "videoChat",
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

    print("[AppDelegate] 📞 CallKit shown uuid=\(uuid.uuidString)")

    completion()
  }
}
