import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = false;
  List<dynamic> _plans = [];
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getPlans();
      // Assume get premium status too
      final resStatus = await api.checkPremiumStatus();
      if (mounted) {
        setState(() {
          _plans = res.data ?? [];
          _isPremium = resStatus.data['isPremium'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _subscribe(String planType) async {
    setState(() => _isLoading = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.subscribe(planType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Thanh toán thành công! Bạn đã là Premium.')),
        );
        setState(() => _isPremium = true);

        // Refresh global auth/user state (if backend stores premium on user)
        try {
          await ref.read(authProvider.notifier).refreshProfile();
        } catch (_) {}

        // Ensure local premium status is also up-to-date
        try {
          final resStatus = await api.checkPremiumStatus();
          if (mounted) {
            setState(() {
              _isPremium = resStatus.data['isPremium'] ?? true;
            });
          }
        } catch (_) {}

        // Notify previous screen purchase succeeded
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gói Premium ✨')),
      body: _plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Nâng tầm học Tiếng Hàn',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mở khóa toàn bộ bài học, luyện viết AI, và ưu tiên ôn tập không giới hạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (_isPremium)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bạn đang sử dụng gói Premium. Cảm ơn bạn đã đồng hành!',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  ..._plans.where((p) => p['type'] != 'FREE').map((plan) {
                    final isLifetime = plan['type'] == 'LIFETIME';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color:
                              isLifetime ? Colors.amber : Colors.blue.shade200,
                          width: isLifetime ? 2 : 1,
                        ),
                      ),
                      elevation: isLifetime ? 4 : 1,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  plan['type'] == 'PREMIUM'
                                      ? 'Theo Tháng'
                                      : 'Vĩnh Viễn',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isLifetime
                                        ? Colors.amber.shade700
                                        : Colors.blue.shade700,
                                  ),
                                ),
                                if (isLifetime)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('PHỔ BIẾN',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${plan['price']} ${plan['currency']}',
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              plan['duration'] ?? '',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const Divider(height: 32),
                            ...(plan['features'] as List).map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check,
                                          color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(f)),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isLifetime ? Colors.amber : Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _isLoading || _isPremium
                                    ? null
                                    : () => _subscribe(plan['type']),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text(
                                        'Chọn gói ${isLifetime ? 'Vĩnh Viễn' : 'Tháng'}'),
                              ),
                            )
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
