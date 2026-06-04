import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../core/ads_manager.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isLoading = false;
  bool _billingAvailable = false;
  final Map<String, ProductDetails> _products = {};
  final Set<String> _handledTokens = {};

  final List<Map<String, dynamic>> _ticketPackages = [
    {
      'id': 'ai_tickets_10',
      'title': 'Gói Khởi Động',
      'count': 10,
      'price': '49.000 đ',
      'description': 'Lý tưởng để thử nghiệm tính năng sửa văn bản bằng AI.',
      'icon': Icons.flash_on,
      'color': Colors.amber,
    },
    {
      'id': 'ai_tickets_30',
      'title': 'Gói Tăng Tốc',
      'count': 30,
      'price': '99.000 đ',
      'description': 'Dành cho ôn luyện thi TOPIK Viết Câu 53 & 54 mức độ trung bình.',
      'icon': Icons.rocket_launch,
      'color': Colors.blueAccent,
    },
    {
      'id': 'ai_tickets_100',
      'title': 'Gói Về Đích',
      'count': 100,
      'price': '249.000 đ',
      'description': 'Tiết kiệm nhất! Ôn luyện chuyên sâu và sửa bài viết thả ga.',
      'icon': Icons.workspace_premium,
      'color': Colors.purpleAccent,
    },
  ];

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (err) {
        debugPrint('Purchase stream error: $err');
      },
    );
    _initializeBilling();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeBilling() async {
    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!mounted) return;
      setState(() {
        _billingAvailable = isAvailable;
      });

      if (isAvailable) {
        final productIds = _ticketPackages.map((p) => p['id'] as String).toSet();
        final response = await _inAppPurchase.queryProductDetails(productIds);
        
        if (!mounted) return;
        setState(() {
          for (final product in response.productDetails) {
            _products[product.id] = product;
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing billing: $e');
    }
  }

  Future<void> _buyConsumable(String productId) async {
    final product = _products[productId];

    if (!_billingAvailable || product == null) {
      // Direct mock purchase dialog if Play Store billing is not available
      final authState = ref.read(authProvider);
      final isAdmin = authState.user?['role'] == 'ADMIN';
      
      if (isAdmin) {
        _showMockPurchaseDialog(productId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cửa hàng hiện tại không khả dụng. Vui lòng thử lại sau.'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể khởi tạo giao dịch: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      final token = purchase.verificationData.serverVerificationData.isNotEmpty
          ? purchase.verificationData.serverVerificationData
          : purchase.purchaseID ?? purchase.productID;

      try {
        if (purchase.status == PurchaseStatus.pending) {
          if (mounted) setState(() => _isLoading = true);
          continue;
        }

        if (purchase.status == PurchaseStatus.error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(purchase.error?.message ?? 'Giao dịch thất bại')),
            );
          }
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          continue;
        }

        if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
          if (_handledTokens.contains(token)) continue;
          _handledTokens.add(token);
          final success = await _verifyTicketPurchase(purchase.productID, token, purchase.purchaseID);
          if (success) {
            if (purchase.pendingCompletePurchase) {
              await _inAppPurchase.completePurchase(purchase);
            }
          } else {
            _handledTokens.remove(token);
          }
        }
      } catch (e) {
        debugPrint('Error handling purchase update: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _verifyTicketPurchase(String productId, String token, String? orderId) async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.verifyConsumablePurchase({
        'productId': productId,
        'purchaseToken': token,
        if (orderId != null) 'orderId': orderId,
      });

      if (!mounted) return false;
      if (res.data['verified'] == true) {
        final added = res.data['ticketsAdded'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Nạp thành công $added vé chấm AI! Cảm ơn bạn đã mua hàng.'),
            backgroundColor: Colors.green,
          ),
        );
        await ref.read(authProvider.notifier).refreshProfile();
        return true;
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xác minh giao dịch với hệ thống: $e')),
        );
      }
      return false;
    }
  }

  void _showMockPurchaseDialog(String productId) {
    final authState = ref.read(authProvider);
    final isAdmin = authState.user?['role'] == 'ADMIN';
    if (!isAdmin) return;

    final package = _ticketPackages.firstWhere((p) => p['id'] == productId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(package['icon'] as IconData, color: package['color'] as Color),
            const SizedBox(width: 10),
            Text(
              'Thanh toán thử nghiệm',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Google Play Billing không khả dụng trên giả lập này. Bạn có muốn mô phỏng mua hàng để nhận ${package['count']} vé chấm điểm AI ngay lập tức?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.outfit(color: Colors.white30)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: package['color'] as Color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final mockToken = 'MOCK_TOKEN_${DateTime.now().millisecondsSinceEpoch}';
                final mockOrderId = 'GPA.MOCK-${DateTime.now().millisecondsSinceEpoch}';
                await _verifyTicketPurchase(productId, mockToken, mockOrderId);
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: Text(
              'Mô Phỏng Thanh Toán',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _watchRewardAd() async {
    final ads = ref.read(adsManagerProvider);
    await ads.showRewardedAdWithLoadingDialog(
      context: context,
      onRewardEarned: () async {
        setState(() => _isLoading = true);
        try {
          final api = ref.read(apiClientProvider);
          final res = await api.claimRewardAdTicket();
          if (res.data['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Nhận thành công 1 vé chấm AI miễn phí!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            await ref.read(authProvider.notifier).refreshProfile();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi nhận vé: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isPremium = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] != 'FREE');
    final currentTickets = user?['aiTicketsBalance'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Background Gradient decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                    blurRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    'Cửa Hàng Vé Chấm AI',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Ticket Info Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFF818CF8).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF818CF8).withValues(alpha: 0.2),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFFA5B4FC),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isPremium ? 'Premium Vô Hạn' : '$currentTickets Vé Chấm AI',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isPremium
                                    ? 'Gói VIP Premium đang kích hoạt. Bạn có thể sử dụng tất cả tính năng AI mà không giới hạn số lượng.'
                                    : 'Sử dụng vé này để chấm bài viết TOPIK (câu 53 & 54) hoặc các bài luận tự do. Nhận sửa lỗi chi tiết, gợi ý từ vựng và chấm điểm từ AI.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFC7D2FE),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Chọn Gói Vé Phù Hợp',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Reward Ad Free Ticket Card
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          color: const Color(0xFF13132B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.video_library,
                                    color: Color(0xFF34D399),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vé Miễn Phí (Xem QC)',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Xem một video quảng cáo ngắn để nhận ngay 1 vé chấm AI miễn phí.',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Miễn Phí',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF34D399),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: _isLoading ? null : _watchRewardAd,
                                      child: Text(
                                        'Xem QC',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        ..._ticketPackages.map((package) {
                          final productId = package['id'] as String;
                          final details = _products[productId];
                          final displayPrice = details?.price ?? package['price'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: const Color(0xFF161624),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: (package['color'] as Color).withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (package['color'] as Color).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      package['icon'] as IconData,
                                      color: package['color'] as Color,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          package['title'] as String,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          package['description'] as String,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        displayPrice,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: package['color'] as Color,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: _isLoading ? null : () => _buyConsumable(productId),
                                        child: Text(
                                          'Mua',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (user?['role'] == 'ADMIN') ...[
                                        const SizedBox(height: 8),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: package['color'] as Color,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(60, 30),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: _isLoading
                                              ? null
                                              : () => _showMockPurchaseDialog(productId),
                                          child: Text(
                                            'Mô phỏng',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            '* Vé chấm điểm AI không thể chuyển đổi thành tiền mặt hoặc hoàn lại tiền sau khi đã sử dụng.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF6366F1)),
                    const SizedBox(height: 16),
                    Text(
                      'Đang xử lý giao dịch...',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
