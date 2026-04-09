import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import 'auth_provider.dart';

final adFreeStatusProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return false;
  }

  final api = ref.read(apiClientProvider);
  final res = await api.checkPremiumStatus();
  return res.data?['isPremium'] == true;
});
