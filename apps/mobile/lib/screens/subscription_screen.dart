import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';
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
  bool _isAdFree = false;
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
        _isAdFree = resStatus.data['isPremium'] ?? false;
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

    setState(() => _isAdFree = true);

    try {
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.data['verified'] == true
                ? 'Thanh toán Google Play thành công! Quảng cáo đã được tắt.'
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
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gói không quảng cáo',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: theme.gradient),
          ),
        ),
        actions: [
          if (_billingAvailable)
            TextButton.icon(
              onPressed: _isLoading ? null : _restorePurchases,
              icon: const Icon(Icons.restore, color: Colors.white),
              label: const Text(
                'Khôi phục',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoadingPlans
          ? const Center(child: CircularProgressIndicator())
          : !hasPlans
              ? const Center(child: Text('Không tải được danh sách gói.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'Học tập không giới hạn 🚀',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mua và gia hạn trực tiếp qua Google Play Store để tắt hoàn toàn quảng cáo và mở khóa mọi tính năng.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!_billingAvailable)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            defaultTargetPlatform == TargetPlatform.android
                                ? 'Thiết bị chưa sẵn sàng cho Google Play Billing. Hãy chạy bản release / internal test đã cài từ Play Store.'
                                : 'Google Play Billing chỉ hoạt động trên thiết bị Android.',
                            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (_isAdFree) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, color: Colors.white, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tài khoản của bạn đã kích hoạt tính năng không quảng cáo. Cảm ơn bạn đã ủng hộ!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ..._plans
                          .where((plan) => plan['type'] != 'FREE')
                          .map((plan) {
                        final map = plan is Map<String, dynamic>
                            ? plan
                            : Map<String, dynamic>.from(plan as Map);
                        final isAnnual = map['type'] == 'LIFETIME';
                        final title = _planLabel(map['type']?.toString() ?? '');
                        final productId = _planProductId(map);

                        // Premium colors
                        final cardGradient = isAnnual
                            ? const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [theme.seedColor.withOpacity(0.85), theme.seedColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            gradient: cardGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: (isAnnual ? const Color(0xFFD97706) : theme.seedColor)
                                    .withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Subtle diagonal light stripe for reflection effect
                                Positioned(
                                  top: -50,
                                  right: -50,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            title,
                                            style: GoogleFonts.outfit(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (isAnnual)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'KHUYÊN DÙNG ⭐',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFFD97706),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _displayPrice(map),
                                        style: GoogleFonts.outfit(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        map['duration'] ?? '',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (productId.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: $productId',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Divider(color: Colors.white24, height: 1),
                                      ),
                                      ...(map['features'] as List).map(
                                        (feature) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle_outline,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  feature.toString(),
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: isAnnual
                                                ? const Color(0xFFB45309)
                                                : theme.seedColor,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 2,
                                            shadowColor: Colors.black.withOpacity(0.2),
                                          ),
                                          onPressed: _isLoading || _isAdFree
                                              ? null
                                              : () => _buyPlan(map),
                                          child: _isLoading
                                              ? SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    color: isAnnual
                                                        ? const Color(0xFFB45309)
                                                        : theme.seedColor,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  'Mua ngay qua Google Play',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
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
