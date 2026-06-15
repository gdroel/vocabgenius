import Flutter
import UIKit
import UserNotifications
import WidgetKit
import StoreKit
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
  // True once Flutter has attached its Dart handler (signalled by its first
  // getInitialRoute call). The channel object is created during launch, well
  // before Dart runs, so `pushChannel != nil` is NOT a reliable readiness
  // check — invoking it before the Dart handler exists silently drops the call.
  // Until this flips true we buffer taps into pendingRoute instead.
  private var flutterReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // Become the notification delegate before any plugin claims it
    // (flutter_local_notifications only takes it while it's still nil). We do
    // NOT prompt for permission at launch — onboarding asks for it on the
    // "word of the day" screen. If the user has already granted it on a prior
    // launch, refresh the APNs token so server pushes keep working.
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.getNotificationSettings { settings in
      if settings.authorizationStatus == .authorized {
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
    if flutterReady, let channel = pushChannel {
      channel.invokeMethod("onNotificationTap", arguments: route)
    } else {
      // Cold-start tap: Dart hasn't attached its handler yet. Buffer the route
      // so Flutter picks it up via getInitialRoute once it's running.
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
      case "storeEnvironment":
        // "sandbox" for Xcode/TestFlight builds, "production" for the App Store.
        // Mirrors the Sandbox/Production environment Apple stamps on its server
        // notifications so client telemetry can be filtered to real users. The
        // App Store receipt's filename is the canonical signal — "sandboxReceipt"
        // in sandbox, "receipt" in production — and #if DEBUG short-circuits
        // Xcode runs that may not have a receipt URL yet.
        #if DEBUG
        result("sandbox")
        #else
        let isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        result(isSandbox ? "sandbox" : "production")
        #endif
      case "requestAppReview":
        // System decides whether to actually surface the prompt (rate-limited
        // by Apple to a few times a year); calling it is always safe.
        if let scene = UIApplication.shared.connectedScenes
          .first(where: { $0.activationState == .foregroundActive })
          as? UIWindowScene {
          SKStoreReviewController.requestReview(in: scene)
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
        // Flutter's init asking for any buffered cold-start route — also our
        // signal that the Dart handler is now attached, so later (warm) taps
        // can be delivered live over the channel.
        self?.flutterReady = true
        let route = self?.pendingRoute
        self?.pendingRoute = nil
        result(route)
      case "registerForRemoteNotifications":
        // The user just granted notification permission in onboarding; pull an
        // APNs token now so server-driven "word of the day" pushes can deliver.
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = push
  }
}
