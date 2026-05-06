import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const annualProductId = 'pipannualplan';
const _entitlementCacheKey = 'pip_entitlement_active_v1';

class BillingService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _isPro = false;
  bool _available = false;
  ProductDetails? _annualProduct;
  String? _lastError;

  bool get isPro => _isPro;
  bool get storeAvailable => _available;
  ProductDetails? get annualProduct => _annualProduct;
  String? get lastError => _lastError;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_entitlementCacheKey) ?? false;

    _available = await _iap.isAvailable();
    if (!_available) {
      _lastError = 'Store not available';
      notifyListeners();
      return;
    }

    _sub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _lastError = error.toString();
        notifyListeners();
      },
    );

    final response = await _iap.queryProductDetails({annualProductId});
    if (response.productDetails.isNotEmpty) {
      _annualProduct = response.productDetails.first;
    } else if (response.notFoundIDs.contains(annualProductId)) {
      _lastError = 'Product $annualProductId not found in App Store Connect';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> buyAnnual() async {
    final product = _annualProduct;
    if (product == null) {
      _lastError = 'Product not loaded';
      notifyListeners();
      return false;
    }
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final p in updates) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (p.productID == annualProductId) {
            await _setPro(true);
          }
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
        case PurchaseStatus.error:
          _lastError = p.error?.message ?? 'Purchase error';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  Future<void> _setPro(bool value) async {
    if (_isPro == value) return;
    _isPro = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementCacheKey, value);
    notifyListeners();
  }

  // Test-only helper to clear the cached entitlement.
  @visibleForTesting
  Future<void> resetForTesting() => _setPro(false);
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
