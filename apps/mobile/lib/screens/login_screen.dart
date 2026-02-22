import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import '../core/biometric_auth.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  final _nameCtrl = TextEditingController();

  bool _isBiometricLoading = false;
  bool _savedBiometricCreds = false;
  bool _autoBiometricTried = false;
  bool _needsPasswordNavigated = false;

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
    _loadBiometricCredsStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoBiometricLogin();
    });
  }

  Future<void> _maybeAutoBiometricLogin() async {
    if (!mounted) return;
    if (_autoBiometricTried) return;
    if (!_isLogin) return;
    if (_isBiometricLoading) return;
    if (ref.read(authProvider).isLoading) return;

    final settings = ref.read(appSettingsProvider);
    if (!settings.biometricLoginEnabled) return;

    final creds = await BiometricAuth.readCredentials();
    if (!mounted) return;
    if (creds == null) return;

    _autoBiometricTried = true;
    await _handleBiometricLogin();
  }

  Future<void> _loadLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('last_login_email');
    final password = prefs.getString('last_login_password');
    if (!mounted) return;
    setState(() {
      _emailCtrl.text = email ?? '';
      _passwordCtrl.text = password ?? '';
    });
  }

  Future<void> _loadBiometricCredsStatus() async {
    final creds = await BiometricAuth.readCredentials();
    if (!mounted) return;
    setState(() {
      _savedBiometricCreds = creds != null;
    });
  }

  Future<void> _handleBiometricLogin() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.biometricLoginEnabled) return;

    setState(() => _isBiometricLoading = true);
    try {
      final canBio = await BiometricAuth.canCheckBiometrics();
      if (!canBio) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thiết bị chưa hỗ trợ hoặc chưa thiết lập sinh trắc học (vân tay/FaceID).',
            ),
          ),
        );
        return;
      }

      final creds = await BiometricAuth.readCredentials();
      if (creds == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Chưa có thông tin đăng nhập sinh trắc học. Hãy đăng nhập 1 lần trước.'),
          ),
        );
        return;
      }

      final ok = await BiometricAuth.authenticate();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Xác thực sinh trắc học thất bại hoặc bị huỷ.')),
        );
        return;
      }

      await ref.read(authProvider.notifier).login(creds.email, creds.password);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi sinh trắc học: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBiometricLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final settings = ref.watch(appSettingsProvider);
    final theme = AppSettingsNotifier.themeById(settings.themeId);

    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasAuthed = prev?.isAuthenticated == true;
      final isAuthed = next.isAuthenticated;

      if (!wasAuthed && isAuthed) {
        _needsPasswordNavigated = false;
      }

      if (!isAuthed) return;
      if (next.needsPassword != true) return;
      if (_needsPasswordNavigated) return;

      _needsPasswordNavigated = true;
      context.push('/set-password');
    });

    ref.listen<AuthState>(authProvider, (prev, next) async {
      final wasAuthed = prev?.isAuthenticated == true;
      final isAuthed = next.isAuthenticated;
      if (wasAuthed || !isAuthed) return;

      if (!settings.biometricLoginEnabled) return;
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (email.isEmpty || password.isEmpty) return;

      await BiometricAuth.saveCredentials(email: email, password: password);
      await _loadBiometricCredsStatus();
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.gradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🇰🇷', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text(
                    'Tiếng Hàn FDI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Đăng nhập để tiếp tục' : 'Tạo tài khoản mới',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                          obscureText: true,
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            auth.error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () {
                                    if (_isLogin) {
                                      ref.read(authProvider.notifier).login(
                                            _emailCtrl.text,
                                            _passwordCtrl.text,
                                          );
                                    } else {
                                      ref.read(authProvider.notifier).register(
                                            _emailCtrl.text,
                                            _passwordCtrl.text,
                                            _nameCtrl.text,
                                          );
                                    }
                                  },
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_isLogin ? 'Đăng nhập' : 'Đăng ký'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    try {
                                      final google = GoogleSignIn(
                                        scopes: const ['email', 'profile'],
                                      );
                                      final acct = await google.signIn();
                                      if (acct == null) return;
                                      final gAuth = await acct.authentication;
                                      final idToken = gAuth.idToken;
                                      if (idToken == null || idToken.isEmpty) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Không lấy được Google token.'),
                                          ),
                                        );
                                        return;
                                      }
                                      await ref
                                          .read(authProvider.notifier)
                                          .loginWithGoogle(idToken);
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Google login lỗi: ${e.toString()}'),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.g_mobiledata),
                            label: const Text('Đăng nhập bằng Google'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: auth.isLoading
                                ? null
                                : () => context.push('/phone-login'),
                            icon: const Icon(Icons.phone_outlined),
                            label: const Text('Đăng nhập bằng SĐT (OTP)'),
                          ),
                        ),
                        if (_isLogin) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: (!settings.biometricLoginEnabled ||
                                      auth.isLoading ||
                                      _isBiometricLoading)
                                  ? null
                                  : _handleBiometricLogin,
                              icon: _isBiometricLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.fingerprint),
                              label: Text(
                                _savedBiometricCreds
                                    ? 'Đăng nhập bằng sinh trắc học'
                                    : 'Sinh trắc học (chưa thiết lập)',
                              ),
                            ),
                          ),
                        ],
                        if (_isLogin) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => context.push('/forgot-password'),
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _isLogin = !_isLogin;
                            _autoBiometricTried = false;
                            _needsPasswordNavigated = false;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _maybeAutoBiometricLogin();
                            });
                          }),
                          child: Text(
                            _isLogin
                                ? 'Chưa có tài khoản? Đăng ký'
                                : 'Đã có tài khoản? Đăng nhập',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
