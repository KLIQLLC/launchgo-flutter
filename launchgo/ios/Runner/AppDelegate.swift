import Flutter
import UIKit
import GoogleMaps
import stream_video_push_notification
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  private var callValidityTimer: Timer?
  private var activeCallCid: String?
  private var methodChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCjAwFEVV741BblWxJ9esBvD5v2enGhVg4")
    GeneratedPluginRegistrant.register(with: self)

    // Setup method channel for call validity timer
    if let controller = window?.rootViewController as? FlutterViewController {
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
    }

    // Register for VoIP push notifications (Stream SDK handles CallKit)
    StreamVideoPKDelegateManager.shared.registerForPushNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Call Validity Timer
  
  private func startCallValidityTimer(callCid: String) {
    print("[AppDelegate] 📞 Starting call validity timer for: \(callCid)")
    activeCallCid = callCid
    
    // Stop any existing timer
    callValidityTimer?.invalidate()
    
    // Timer fires every 2 seconds to check if call is still valid
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
          print("[AppDelegate] 📞 Call cancelled - ending CallKit")
          SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
          self?.stopCallValidityTimer()
        }
      } else if let error = result as? FlutterError {
        print("[AppDelegate] ⚠️ Error: \(error.message ?? "unknown")")
      }
    }
  }
}
