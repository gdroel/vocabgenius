import Flutter
import UIKit
import UserNotifications
import WidgetKit
import FBSDKCoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let appGroupId = "group.com.gaberoeloffs.professorpip"
  private static let followedTopicsKey = "followedTopics"
  private static let lastWordKey = "lastWord"
  private static let proStatusKey = "proStatus"
  private static let wordsPerDayKey = "wordsPerDay"
  private static let channelName = "professor_pip/widget"
  private static let pushChannelName = "professor_pip/push"

  // Push state. The APNs device token and a cold-start tap route can both
  // arrive before the Flutter method channel exists, so we hold them until
  // Flutter asks for them.
  private var pushChannel: FlutterMethodChannel?
  private var pendingDeviceToken: String?
  private var pendingRoute: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // Become the notification delegate before any plugin claims it
    // (flutter_local_notifications only takes it while it's still nil), then
    // ask for permission and register for remote notifications.
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, _ in
      if granted {
        DispatchQueue.main.async { application.registerForRemoteNotifications() }
      }
    }

    // App cold-started by tapping a push: remember where to go.
    if let notif = launchOptions?[.remoteNotification] as? [String: Any],
       let route = notif["route"] as? String {
      pendingRoute = route
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handled = ApplicationDelegate.shared.application(
      app,
      open: url,
      sourceApplication: options[.sourceApplication] as? String,
      annotation: options[.annotation]
    )
    return handled || super.application(app, open: url, options: options)
  }

  // MARK: - Remote notification registration

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    pendingDeviceToken = hex
    pushChannel?.invokeMethod("onToken", arguments: hex)
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("Push registration failed: \(error.localizedDescription)")
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  // MARK: - UNUserNotificationCenterDelegate

  // Show pushes even while the app is in the foreground.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // User tapped a notification — navigate to the fixed screen.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let route = (response.notification.request.content.userInfo["route"] as? String) ?? "hello"
    if let channel = pushChannel {
      channel.invokeMethod("onNotificationTap", arguments: route)
    } else {
      pendingRoute = route
    }
    completionHandler()
  }

  // MARK: - Method channels

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ProfessorPipWidgetChannel")
    guard let messenger = registrar?.messenger() else { return }

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
      case "setLastWord":
        let defaults = UserDefaults(suiteName: AppDelegate.appGroupId)
        if let dict = call.arguments as? [String: Any] {
          defaults?.set(dict, forKey: AppDelegate.lastWordKey)
        } else {
          defaults?.removeObject(forKey: AppDelegate.lastWordKey)
        }
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      case "setProStatus":
        let isPro = (call.arguments as? Bool) ?? false
        let defaults = UserDefaults(suiteName: AppDelegate.appGroupId)
        defaults?.set(isPro, forKey: AppDelegate.proStatusKey)
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      case "setWordsPerDay":
        let count = (call.arguments as? Int) ?? 12
        let defaults = UserDefaults(suiteName: AppDelegate.appGroupId)
        defaults?.set(count, forKey: AppDelegate.wordsPerDayKey)
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Push channel: hand Flutter the device token / launch route it may have
    // missed, and field the live callbacks above.
    let push = FlutterMethodChannel(
      name: AppDelegate.pushChannelName,
      binaryMessenger: messenger
    )
    push.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getDeviceToken":
        result(self?.pendingDeviceToken)
      case "getInitialRoute":
        let route = self?.pendingRoute
        self?.pendingRoute = nil
        result(route)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = push
  }
}
