package com.sinhalacaptions.sinhala_live_captions

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val voiceChannelName = "com.sinhalacaptions/voice_typing"
    private val speechChannelName = "com.sinhalacaptions/live_speech"
    private val speechEventName = "com.sinhalacaptions/live_speech_events"
    private val networkChannelName = "com.sinhalacaptions/network"
    private val networkEventName = "com.sinhalacaptions/network_events"
    private val sinhalaLocale = "si-LK"

    private var pendingVoice: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var speechEvents: EventChannel.EventSink? = null
    private var networkEvents: EventChannel.EventSink? = null

    private val recognizer by lazy {
        LiveSinhalaRecognizer(this) { event ->
            runOnUiThread { speechEvents?.success(event) }
        }
    }
    private val network by lazy {
        NetworkMonitor(this) { online ->
            runOnUiThread { networkEvents?.success(online) }
        }
    }

    private val voiceTypingLauncher =
        registerForActivityResult(
            androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult(),
        ) { activityResult ->
            val result = pendingVoice
            pendingVoice = null
            if (result == null) {
                return@registerForActivityResult
            }
            if (activityResult.resultCode != Activity.RESULT_OK) {
                result.success(mapOf("status" to "cancelled"))
                return@registerForActivityResult
            }
            val matches =
                activityResult.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            val text = matches?.firstOrNull()?.trim().orEmpty()
            if (text.isEmpty()) {
                result.success(mapOf("status" to "empty"))
            } else {
                result.success(mapOf("status" to "text", "text" to text))
            }
        }

    private val permissionLauncher =
        registerForActivityResult(
            androidx.activity.result.contract.ActivityResultContracts.RequestPermission(),
        ) { granted ->
            val result = pendingPermission
            pendingPermission = null
            result?.success(speechStatus(granted))
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, voiceChannelName).setMethodCallHandler { call, result ->
            if (call.method != "recognize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            launchSinhalaVoiceTyping(result)
        }
        MethodChannel(messenger, speechChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> prepareSpeech(result)
                "start" -> {
                    recognizer.start()
                    result.success(null)
                }
                "stop" -> {
                    recognizer.stop()
                    result.success(null)
                }
                "cancel" -> {
                    recognizer.cancel()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, speechEventName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    speechEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    speechEvents = null
                    recognizer.cancel()
                }
            },
        )
        MethodChannel(messenger, networkChannelName).setMethodCallHandler { call, result ->
            if (call.method == "status") {
                result.success(network.current())
            } else {
                result.notImplemented()
            }
        }
        EventChannel(messenger, networkEventName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    networkEvents = events
                    network.start()
                }

                override fun onCancel(arguments: Any?) {
                    networkEvents = null
                    network.stop()
                }
            },
        )
    }

    override fun onDestroy() {
        recognizer.release()
        network.stop()
        super.onDestroy()
    }

    private fun speechStatus(permission: Boolean): Map<String, Any> {
        return mapOf(
            "permission" to permission,
            "available" to recognizer.isAvailable(),
            "service" to recognizer.servicePackage,
        )
    }

    private fun prepareSpeech(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(speechStatus(true))
            return
        }
        if (pendingPermission != null) {
            result.success(speechStatus(false))
            return
        }
        pendingPermission = result
        permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    private fun launchSinhalaVoiceTyping(result: MethodChannel.Result) {
        if (pendingVoice != null) {
            result.success(mapOf("status" to "busy"))
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(mapOf("status" to "permission"))
            return
        }
        val intent =
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, sinhalaLocale)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, sinhalaLocale)
                putExtra(RecognizerIntent.EXTRA_PROMPT, "සිංහලෙන් කථා කරන්න")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            }
        pendingVoice = result
        try {
            voiceTypingLauncher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            pendingVoice = null
            result.success(mapOf("status" to "unavailable"))
        }
    }
}
