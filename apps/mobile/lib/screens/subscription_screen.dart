import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isLoading = false;
  bool _isLoadingPlans = true;
  bool _billingAvailable = false;
  List<dynamic> _plans = [];
  bool _isPremium = false;
  final Map<String, ProductDetails> _productDetailsById = {};
  final Set<String> _handledTokens = {};

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {},
    );
    _loadPlans();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  String _planLabel(String type) {
    switch (type) {
      case 'PREMIUM':
        return 'Hàng tháng';
      case 'LIFETIME':
        return 'Hàng năm';
      default:
        return 'Miễn phí';
    }
  }

  String _planProductId(Map<String, dynamic> plan) {
    return plan['androidProductId']?.toString() ??
        plan['productId']?.toString() ??
        '';
  }

  String _formatMoney(dynamic value) {
    final amount = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return '${_moneyFormat.format(amount)} đ';
  }

  String _displayPrice(Map<String, dynamic> plan) {
    final productId = _planProductId(plan);
    final product = _productDetailsById[productId];
    if (product != null) {
      return product.price;
    }
    return _formatMoney(plan['price']);
  }

  Map<String, dynamic>? _planForProductId(String productId) {
    for (final plan in _plans) {
      final map = plan is Map<String, dynamic>
          ? plan
          : Map<String, dynamic>.from(plan as Map);
      if (_planProductId(map) == productId) {
        return map;
      }
    }
    return null;
  }

  Future<void> _loadPlans() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getPlans();
      final resStatus = await api.checkPremiumStatus();
      final plans = (res.data as List?) ?? [];

      final billingAvailable = await _inAppPurchase.isAvailable();
      final productDetailsById = <String, ProductDetails>{};

      if (billingAvailable) {
        final productIds = plans
            .map((plan) =>
                plan is Map ? plan['androidProductId']?.toString() ?? '' : '')
            .where((id) => id.isNotEmpty)
            .toSet();

        if (productIds.isNotEmpty) {
          final response = await _inAppPurchase.queryProductDetails(productIds);
          for (final product in response.productDetails) {
            productDetailsById[product.id] = product;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _isPremium = resStatus.data['isPremium'] ?? false;
        _billingAvailable = billingAvailable;
        _productDetailsById
          ..clear()
          ..addAll(productDetailsById);
        _isLoadingPlans = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPlans = false);
      }
    }
  }

  Future<void> _buyPlan(Map<String, dynamic> plan) async {
    final productId = _planProductId(plan);
    final product = _productDetailsById[productId];

    if (!_billingAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Google Play Billing chưa sẵn sàng trên thiết bị này.'),
          ),
        );
      }
      return;
    }

    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy gói trên Google Play: $productId'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bắt đầu giao dịch: $e')),
        );
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (!_billingAvailable) return;

    setState(() => _isLoading = true);
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khôi phục giao dịch thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      final token = purchase.verificationData.serverVerificationData.isNotEmpty
          ? purchase.verificationData.serverVerificationData
          : purchase.purchaseID ?? purchase.productID;

      try {
        if (purchase.status == PurchaseStatus.pending) {
          if (mounted) {
            setState(() => _isLoading = true);
          }
          continue;
        }

        if (purchase.status == PurchaseStatus.error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  purchase.error?.message ?? 'Giao dịch Google Play thất bại',
                ),
              ),
            );
          }
          continue;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (_handledTokens.contains(token)) {
            continue;
          }
          _handledTokens.add(token);
          await _verifyPurchase(purchase);
        }
      } finally {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final plan = _planForProductId(purchase.productID);
    if (plan == null) {
      throw StateError(
          'Không tìm thấy cấu hình gói phù hợp cho ${purchase.productID}');
    }

    final api = ref.read(apiClientProvider);
    final response = await api.verifyGooglePlaySubscription({
      'productId': purchase.productID,
      'purchaseToken': purchase.verificationData.serverVerificationData,
      'orderId': purchase.purchaseID,
      'planType': plan['type'],
    });

    if (!mounted) return;

    setState(() => _isPremium = true);

    try {
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.data['verified'] == true
                ? 'Thanh toán Google Play thành công! Bạn đã là Premium.'
                : 'Thanh toán đã hoàn tất.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPlans = _plans.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói Premium'),
        actions: [
          if (_billingAvailable)
            TextButton.icon(
              onPressed: _isLoading ? null : _restorePurchases,
              icon: const Icon(Icons.restore, color: Colors.white),
              label: const Text(
                'Khôi phục',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoadingPlans
          ? const Center(child: CircularProgressIndicator())
          : !hasPlans
              ? const Center(child: Text('Không tải được danh sách gói.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nâng tầm học Tiếng Hàn',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mua và gia hạn trực tiếp qua Google Play Store. Giá hiển thị đã được định dạng để dễ đọc.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      if (!_billingAvailable)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            defaultTargetPlatform == TargetPlatform.android
                                ? 'Thiết bị chưa sẵn sàng cho Google Play Billing. Hãy chạy bản release / internal test đã cài từ Play Store và đăng nhập đúng tài khoản test.'
                                : 'Google Play Billing chỉ hoạt động trên Android.',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      if (_isPremium) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tài khoản của bạn đang có Premium.',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ..._plans
                          .where((plan) => plan['type'] != 'FREE')
                          .map((plan) {
                        final map = plan is Map<String, dynamic>
                            ? plan
                            : Map<String, dynamic>.from(plan as Map);
                        final isAnnual = map['type'] == 'LIFETIME';
                        final title = _planLabel(map['type']?.toString() ?? '');
                        final productId = _planProductId(map);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isAnnual
                                  ? Colors.amber
                                  : Colors.blue.shade200,
                              width: isAnnual ? 2 : 1,
                            ),
                          ),
                          elevation: isAnnual ? 4 : 1,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isAnnual
                                            ? Colors.amber.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                    if (isAnnual)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'ĐỀ XUẤT',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _displayPrice(map),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  map['duration'] ?? '',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                if (productId.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Google Play ID: $productId',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const Divider(height: 32),
                                ...(map['features'] as List).map(
                                  (feature) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(feature.toString())),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isAnnual ? Colors.amber : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _isLoading || _isPremium
                                        ? null
                                        : () => _buyPlan(map),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text('Mua qua Google Play'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
