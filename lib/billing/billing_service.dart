import 'dart:async';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Public RevenueCat SDK key. Safe to ship in the binary — RC keys are public
// by design and are scoped per-platform in the dashboard.
const _revenueCatApiKey = 'appl_RPjmAwadUSDGppZlitlegDrWKAs';

// Must match the entitlement identifier configured in the RevenueCat dashboard.
const proEntitlementId = 'Professor Pip Pro';

const _entitlementCacheKey = 'pip_entitlement_active_v1';

class BillingService extends ChangeNotifier {
  final FacebookAppEvents _fb = FacebookAppEvents();

  bool _isPro = false;
  bool _configured = false;
  Offering? _currentOffering;
  String? _lastError;

  bool get isPro => _isPro;
  bool get storeAvailable => _configured && _currentOffering != null;
  Offering? get currentOffering => _currentOffering;
  Package? get annualPackage => _currentOffering?.annual;
  Package? get monthlyPackage => _currentOffering?.monthly;
  String? get lastError => _lastError;

  /// Formatted, localized price for the annual package (e.g. "$59.99").
  String? get annualPriceLabel => annualPackage?.storeProduct.priceString;

  /// Formatted, localized price for the monthly package (e.g. "$4.99").
  String? get monthlyPriceLabel => monthlyPackage?.storeProduct.priceString;

  void loadCachedPro(SharedPreferences prefs) {
    _isPro = prefs.getBool(_entitlementCacheKey) ?? false;
    _pushProStatusToWidget(_isPro);
  }

  Future<void> init() async {
    if (_configured) return;
    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.warn,
      );
      await Purchases.configure(PurchasesConfiguration(_revenueCatApiKey));
      _configured = true;
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'RevenueCat configuration failed';
      notifyListeners();
      return;
    }

    Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);

    // Hydrate entitlement + offerings concurrently. CustomerInfo returns the
    // cached state immediately and refreshes from the server in the background;
    // the listener catches any drift.
    await Future.wait<void>([
      _refreshCustomerInfo(),
      _refreshOfferings(),
    ]);

    notifyListeners();
  }

  Future<void> _refreshCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      await _applyCustomerInfo(info);
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'Failed to load customer info';
    }
  }

  Future<void> _refreshOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      _currentOffering = offerings.current;
      if (_currentOffering == null) {
        _lastError = 'No current offering configured in RevenueCat dashboard';
      }
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'Failed to load offerings';
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    _applyCustomerInfo(info);
  }

  Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final active =
        info.entitlements.all[proEntitlementId]?.isActive ?? false;
    if (active == _isPro) return;
    _isPro = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementCacheKey, active);
    _pushProStatusToWidget(active);
    notifyListeners();
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfo);
    super.dispose();
  }

  /// Buys the annual package from the current offering.
  /// Returns true if the user now has the Pro entitlement.
  Future<bool> buyAnnual() => _purchase(annualPackage);

  /// Buys the monthly package from the current offering.
  Future<bool> buyMonthly() => _purchase(monthlyPackage);

  Future<bool> _purchase(Package? package) async {
    if (package == null) {
      _lastError = 'Package unavailable — check the RevenueCat offering';
      notifyListeners();
      return false;
    }
    _lastError = null;

    try {
      final wasPro = _isPro;
      final result = await Purchases.purchase(PurchaseParams.package(package));
      await _applyCustomerInfo(result.customerInfo);
      final nowPro =
          result.customerInfo.entitlements.all[proEntitlementId]?.isActive ??
              false;
      if (nowPro && !wasPro) {
        await _logStartTrial(package);
      }
      return nowPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        // Silent — user explicitly dismissed the purchase sheet.
        return false;
      }
      _lastError = e.message ?? code.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> restore() async {
    _lastError = null;
    try {
      final info = await Purchases.restorePurchases();
      await _applyCustomerInfo(info);
      return _isPro;
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'Restore failed';
      notifyListeners();
      return false;
    }
  }

  /// Presents the RevenueCat-managed paywall configured in the dashboard.
  /// Use this when you want the paywall layout/copy/pricing managed remotely
  /// rather than the bundled Pip-branded screen.
  Future<PaywallResult> presentRevenueCatPaywall({
    bool displayCloseButton = true,
  }) {
    return RevenueCatUI.presentPaywall(
      offering: _currentOffering,
      displayCloseButton: displayCloseButton,
    );
  }

  /// Presents the RevenueCat Customer Center modal — handles cancel,
  /// restore, refund requests, plan changes, and support contact.
  Future<void> presentCustomerCenter() {
    return RevenueCatUI.presentCustomerCenter();
  }

  Future<void> _logStartTrial(Package package) async {
    final product = package.storeProduct;
    try {
      await _fb.logStartTrial(
        orderId: product.identifier,
        currency: product.currencyCode,
        price: product.price,
      );
    } catch (_) {
      // Non-fatal: analytics failure must not block the purchase flow.
    }
  }

  static const _widgetChannel = MethodChannel('professor_pip/widget');

  void _pushProStatusToWidget(bool isPro) {
    _widgetChannel.invokeMethod('setProStatus', isPro).catchError((_) {});
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _isPro = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementCacheKey, false);
    _pushProStatusToWidget(false);
    notifyListeners();
  }
}

class BillingScope extends InheritedNotifier<BillingService> {
  const BillingScope({
    super.key,
    required BillingService service,
    required super.child,
  }) : super(notifier: service);

  static BillingService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BillingScope>();
    assert(scope != null, 'BillingScope missing');
    return scope!.notifier!;
  }
}
