import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final Map<String, dynamic>? user;
  final String? error;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(AuthState()) {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _api.setToken(token);
      try {
        final res = await _api.getProfile();
        state = AuthState(isAuthenticated: true, user: res.data);
      } catch (_) {
        await prefs.remove('auth_token');
        _api.setToken(null);
        state = AuthState();
      }
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final res = await _api.login(email, password);
      final token = res.data['accessToken'] as String;
      _api.setToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('last_login_email', email);
      await prefs.setString('last_login_password', password);

      state = AuthState(isAuthenticated: true, user: res.data['user']);
    } catch (e) {
      state = AuthState(error: 'Invalid credentials');
    }
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = AuthState(isLoading: true);
    try {
      final res = await _api.register(email, password, displayName);
      final token = res.data['accessToken'] as String;
      _api.setToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('last_login_email', email);
      await prefs.setString('last_login_password', password);

      state = AuthState(isAuthenticated: true, user: res.data['user']);
    } catch (e) {
      state = AuthState(error: 'Registration failed');
    }
  }

  Future<void> logout() async {
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    state = AuthState();
  }

  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;
    final res = await _api.getProfile();
    state = AuthState(
      isAuthenticated: true,
      user: res.data,
      isLoading: false,
      error: null,
    );
  }

  Future<void> updateAvatarUrl(String avatarUrl) async {
    if (!state.isAuthenticated) return;

    final currentUser = state.user;
    if (currentUser != null) {
      state = AuthState(
        isAuthenticated: true,
        user: {
          ...currentUser,
          'avatarUrl': avatarUrl,
        },
        isLoading: false,
        error: null,
      );
    }

    await _api.updateMyProfile(avatarUrl: avatarUrl);

    try {
      await refreshProfile();
    } catch (_) {
      // Keep optimistic avatar if refresh fails
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
