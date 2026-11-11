import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var pendingInviteLink: String?
  private var deepLinkChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      pendingInviteLink = url.absoluteString
    }
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
          let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.1"
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

      // 3. Kênh Deep Link Kết Bạn & Chia sẻ liên kết trên iOS
      let dlChannel = FlutterMethodChannel(
        name: "com.abom.utas.utas/deep_link",
        binaryMessenger: controller.binaryMessenger
      )
      self.deepLinkChannel = dlChannel
      dlChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "getInitialLink":
          let link = self?.pendingInviteLink
          self?.pendingInviteLink = nil
          result(link)
        case "shareText":
          guard let args = call.arguments as? [String: Any],
                let text = args["text"] as? String,
                !text.isEmpty else {
            result(false)
            return
          }
          let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
          }
          controller.present(activityVC, animated: true) {
            result(true)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let link = url.absoluteString
    pendingInviteLink = link
    deepLinkChannel?.invokeMethod("onDeepLink", arguments: link)
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      let link = url.absoluteString
      pendingInviteLink = link
      deepLinkChannel?.invokeMethod("onDeepLink", arguments: link)
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
