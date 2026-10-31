import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      // 1. Kênh Cập nhật ứng dụng iOS (Version check, mở liên kết Safari)
      let updaterChannel = FlutterMethodChannel(
        name: "com.abom.utas.utas/app_updater",
        binaryMessenger: controller.binaryMessenger
      )
      updaterChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "getAppVersion":
          let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4.1"
          result(version)
        case "openUrl":
          guard let args = call.arguments as? [String: Any],
                let urlStr = args["url"] as? String,
                let url = URL(string: urlStr) else {
            result(false)
            return
          }
          if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
              result(success)
            }
          } else {
            result(false)
          }
        case "installApk":
          result(FlutterError(code: "UNSUPPORTED_PLATFORM",
                              message: "iOS does not support APK installation",
                              details: nil))
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // 2. Kênh Widget Pin (iOS WidgetKit yêu cầu người dùng thêm thủ công từ Home Screen)
      let pinChannel = FlutterMethodChannel(
        name: "com.abom.utas.utas/widget_pin",
        binaryMessenger: controller.binaryMessenger
      )
      pinChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "isPinSupported":
          result(false)
        case "requestPinWidget":
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
