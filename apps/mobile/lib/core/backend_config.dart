import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class BackendConfig {
  static const String _defaultUrl = 'http://14.160.33.94:3000/api';
  static const String _prefKey = 'cached_backend_url';

  static const String _remoteUrlConfig = String.fromEnvironment(
    'BACKEND_CONFIG_URL',
    defaultValue:
        'https://raw.githubusercontent.com/vip7009pro/practice1/refs/heads/master/base_url.txt',
  );

  static String _currentUrl = _defaultUrl;

  static String get currentUrl => _currentUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUrl = prefs.getString(_prefKey) ?? _defaultUrl;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      
      // Append cache buster parameter to bypass GitHub/CDN cache (max-age=300)
      final uri = Uri.parse(_remoteUrlConfig);
      final cacheBusterUri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      final request = await client.getUrl(cacheBusterUri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final url = content.trim();
        if (url.isNotEmpty &&
            (url.startsWith('http://') || url.startsWith('https://'))) {
          // Standardize /api suffix
          String formattedUrl = url;
          if (!formattedUrl.endsWith('/api')) {
            if (formattedUrl.endsWith('/')) {
              formattedUrl = '${formattedUrl}api';
            } else {
              formattedUrl = '$formattedUrl/api';
            }
          }

          _currentUrl = formattedUrl;
          await prefs.setString(_prefKey, formattedUrl);
        }
      }
    } catch (_) {
      // Keep using cachedUrl or defaultUrl
    }
  }

  static Future<void> setManualUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    String formattedUrl = url.trim();
    if (formattedUrl.isNotEmpty) {
      if (!formattedUrl.endsWith('/api')) {
        if (formattedUrl.endsWith('/')) {
          formattedUrl = '${formattedUrl}api';
        } else {
          formattedUrl = '$formattedUrl/api';
        }
      }
      _currentUrl = formattedUrl;
      await prefs.setString(_prefKey, formattedUrl);
    }
  }
}
