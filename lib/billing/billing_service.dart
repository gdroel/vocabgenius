import 'dart:async';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../telemetry.dart';

// Public RevenueCat SDK key. Safe to ship in the binary — RC keys are public
// by design and are scoped per-platform in the dashboard.
const _revenueCatApiKey = 'appl_RPjmAwadUSDGppZlitlegDrWKAs';

// Must match the entitlement identifier configured in the RevenueCat dashboard.
const proEntitlementId = 'Professor Pip Pro';

// The discounted monthly SKU promoted via push (the $1.99 "60% off" offer).
// Targeted by product id rather than the offering's $rc_monthly package so the
// push paywall always charges this exact product regardless of how the current
// offering is wired. The original "pipmonthly" plan is still supported via the
// offering's monthly package (see [pipMonthlyPackage]). Buying either grants
// the same [proEntitlementId].
const pipMonthlyTwoProductId = 'professorpipmonthlytwo';

const _entitlementCacheKey = 'pip_entitlement_active_v1';

class BillingService extends ChangeNotifier {
  final FacebookAppEvents _fb = FacebookAppEvents();

  bool _isPro = false;
  bool _configured = false;
  Offering? _currentOffering;
  StoreProduct? _pipMonthlyTwoProduct;
  String? _lastError;

  // Set once RevenueCat is configured. Reading the app user id before this is
  // true triggers a NON-catchable native fatal error in the SDK, so telemetry
  // and push must gate on it.
  static bool _revenueCatConfigured = false;

  /// Invoked once, right after RevenueCat is configured. PushService hooks
  /// this to register its device token under the real app user id.
  static VoidCallback? onRevenueCatConfigured;

  /// The RevenueCat app user id, or null if the SDK isn't configured yet.
  /// Never throws and never crashes the SDK.
  static Future<String?> currentAppUserId() async {
    if (!_revenueCatConfigured) return null;
    try {
      return await Purchases.appUserID;
    } catch (_) {
      return null;
    }
  }

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
      _revenueCatConfigured = true;
      Telemetry.appOpened();
      onRevenueCatConfigured?.call();
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

  /// The original monthly ($rc_monthly) package — the "pipmonthly" plan. Still
  /// supported for existing subscribers and any non-promo monthly path.
  Package? get pipMonthlyPackage => _currentOffering?.monthly;

  /// Localized price for the original monthly product (e.g. "$4.99").
  String? get pipMonthlyPriceLabel =>
      pipMonthlyPackage?.storeProduct.priceString;

  /// Buys the original monthly plan. Grants the same Pro entitlement as annual.
  Future<bool> buyPipMonthly() => _purchase(pipMonthlyPackage);

  /// The discounted monthly product (professorpipmonthlytwo) promoted via push,
  /// once loaded via [loadPipMonthlyTwo].
  StoreProduct? get pipMonthlyTwoProduct => _pipMonthlyTwoProduct;

  /// Localized, store-formatted price for the discounted monthly product
  /// (e.g. "$1.99"), or null until [loadPipMonthlyTwo] has resolved it.
  String? get pipMonthlyTwoPriceLabel => _pipMonthlyTwoProduct?.priceString;

  /// Fetches [pipMonthlyTwoProductId] from the store so its localized price is
  /// available for the push paywall. Best-effort and idempotent — a failure or
  /// missing product just leaves the label null (the UI falls back to a
  /// hardcoded price).
  Future<void> loadPipMonthlyTwo() async {
    if (_pipMonthlyTwoProduct != null) return;
    try {
      final products = await Purchases.getProducts([pipMonthlyTwoProductId]);
      if (products.isNotEmpty) {
        _pipMonthlyTwoProduct = products.first;
        notifyListeners();
      }
    } on PlatformException {
      // Best-effort: leave the fallback price in place.
    }
  }

  /// Buys the discounted monthly plan (professorpipmonthlytwo) promoted via
  /// push. Targets the product directly so the push paywall always charges this
  /// exact 60%-off SKU. Grants the same Pro entitlement as every other plan.
  /// Deliberately does NOT fall back to the full-price monthly — charging more
  /// than the advertised price would be wrong, so an unavailable product
  /// surfaces an error instead.
  Future<bool> buyPipMonthlyTwo() async {
    await loadPipMonthlyTwo();
    final product = _pipMonthlyTwoProduct;
    if (product == null) {
      _lastError = 'This offer is unavailable right now. Please try again.';
      notifyListeners();
      return false;
    }
    return _runPurchase(PurchaseParams.storeProduct(product), product);
  }

  Future<bool> _purchase(Package? package) {
    if (package == null) {
      _lastError = 'Package unavailable — check the RevenueCat offering';
      notifyListeners();
      return Future.value(false);
    }
    return _runPurchase(
      PurchaseParams.package(package),
      package.storeProduct,
    );
  }

  /// Core purchase flow shared by package- and product-based purchases.
  /// [product] is used only for start-trial analytics and entitlement logging.
  Future<bool> _runPurchase(PurchaseParams params, StoreProduct product) async {
    _lastError = null;

    try {
      final wasPro = _isPro;
      final result = await Purchases.purchase(params);
      await _applyCustomerInfo(result.customerInfo);
      final nowPro =
          result.customerInfo.entitlements.all[proEntitlementId]?.isActive ??
              false;
      if (nowPro && !wasPro) {
        await _logStartTrial(product);
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

  Future<void> _logStartTrial(StoreProduct product) async {
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
