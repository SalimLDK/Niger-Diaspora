package com.diasponiger.diasponiger

import android.app.Activity
import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class PlayIntegrityPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    companion object {
        private const val CHANNEL_NAME = "com.diasponiger.play_integrity"

        // Cloud project number from Google Cloud Console
        // This should match the project linked to your Play Console app
        private const val CLOUD_PROJECT_NUMBER = 539228418594L
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestIntegrityToken" -> {
                val nonce = call.argument<String>("nonce")
                if (nonce == null) {
                    result.error("INVALID_ARGUMENT", "Nonce is required", null)
                    return
                }
                requestIntegrityToken(nonce, result)
            }
            "isAvailable" -> {
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun requestIntegrityToken(nonce: String, result: Result) {
        try {
            val integrityManager = IntegrityManagerFactory.create(context)

            val requestBuilder = IntegrityTokenRequest.builder()
                .setNonce(nonce)

            // Only set cloud project number if configured
            if (CLOUD_PROJECT_NUMBER > 0) {
                requestBuilder.setCloudProjectNumber(CLOUD_PROJECT_NUMBER)
            }

            val integrityTokenRequest = requestBuilder.build()

            integrityManager.requestIntegrityToken(integrityTokenRequest)
                .addOnSuccessListener { response ->
                    val token = response.token()
                    result.success(token)
                }
                .addOnFailureListener { exception ->
                    val errorCode = getErrorCode(exception)
                    result.error(
                        errorCode,
                        exception.message ?: "Unknown error requesting integrity token",
                        exception.stackTraceToString()
                    )
                }
        } catch (e: Exception) {
            result.error(
                "INTEGRITY_ERROR",
                e.message ?: "Failed to initialize integrity manager",
                e.stackTraceToString()
            )
        }
    }

    private fun getErrorCode(exception: Exception): String {
        val message = exception.message ?: ""
        return when {
            message.contains("API_NOT_AVAILABLE") -> "API_NOT_AVAILABLE"
            message.contains("PLAY_STORE_NOT_FOUND") -> "PLAY_STORE_NOT_FOUND"
            message.contains("NETWORK_ERROR") -> "NETWORK_ERROR"
            message.contains("PLAY_STORE_ACCOUNT_NOT_FOUND") -> "PLAY_STORE_ACCOUNT_NOT_FOUND"
            message.contains("APP_NOT_INSTALLED") -> "APP_NOT_INSTALLED"
            message.contains("PLAY_SERVICES_NOT_FOUND") -> "PLAY_SERVICES_NOT_FOUND"
            message.contains("APP_UID_MISMATCH") -> "APP_UID_MISMATCH"
            message.contains("TOO_MANY_REQUESTS") -> "TOO_MANY_REQUESTS"
            message.contains("CANNOT_BIND_TO_SERVICE") -> "CANNOT_BIND_TO_SERVICE"
            message.contains("NONCE_TOO_SHORT") -> "NONCE_TOO_SHORT"
            message.contains("NONCE_TOO_LONG") -> "NONCE_TOO_LONG"
            message.contains("GOOGLE_SERVER_UNAVAILABLE") -> "GOOGLE_SERVER_UNAVAILABLE"
            message.contains("NONCE_IS_NOT_BASE64") -> "NONCE_IS_NOT_BASE64"
            message.contains("CLOUD_PROJECT_NUMBER_IS_INVALID") -> "CLOUD_PROJECT_NUMBER_IS_INVALID"
            else -> "UNKNOWN_ERROR"
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
