package com.hnp.korean_learning_app

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val channelName = "korean_learning_app/tts_settings"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openTtsSettings" -> {
						try {
							startActivity(Intent("android.settings.TTS_SETTINGS"))
							result.success(true)
						} catch (_: Exception) {
							result.success(false)
						}
					}

					else -> result.notImplemented()
				}
			}
	}
}
