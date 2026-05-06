import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let appGroupId = "group.com.gaberoeloffs.professorpip"
  private static let followedTopicsKey = "followedTopics"
  private static let channelName = "professor_pip/widget"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ProfessorPipWidgetChannel")
    if let messenger = registrar?.messenger() {
      let channel = FlutterMethodChannel(
        name: AppDelegate.channelName,
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "setFollowedTopics":
          let ids = (call.arguments as? [String]) ?? []
          let defaults = UserDefaults(suiteName: AppDelegate.appGroupId)
          defaults?.set(ids, forKey: AppDelegate.followedTopicsKey)
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
