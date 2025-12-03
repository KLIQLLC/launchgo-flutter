import Flutter
import UIKit
import GoogleMaps
import stream_video_push_notification

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCjAwFEVV741BblWxJ9esBvD5v2enGhVg4")
    GeneratedPluginRegistrant.register(with: self)

    // Register for VoIP push notifications
    StreamVideoPKDelegateManager.shared.registerForPushNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}