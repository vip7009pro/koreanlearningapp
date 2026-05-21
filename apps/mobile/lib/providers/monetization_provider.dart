import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import 'auth_provider.dart';

final adFreeStatusProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return false;
  }

  // 1-day free trial for new users
  final createdAtStr = auth.user?['createdAt'] as String?;
  if (createdAtStr != null) {
    final createdAt = DateTime.tryParse(createdAtStr);
    if (createdAt != null) {
      final difference = DateTime.now().difference(createdAt).inSeconds.abs();
      if (difference < 24 * 3600) {
        return true;
      }
    }
  }

  final api = ref.read(apiClientProvider);
  final res = await api.checkPremiumStatus();
  return res.data?['isPremium'] == true;
});
