package com.sinhalacaptions.sinhala_live_captions

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/// Live Sinhala recognition through Google's speech service when it is installed.
///
/// `speech_to_text` only offers locales the service lists. This phone's list
/// can omit `si` even when Google voice typing accepts `si-LK`. Partial text
/// is delivered in-app. The recognizer is recreated for every listen.
class LiveSinhalaRecognizer(
    private val context: Context,
    private val emit: (Map<String, Any>) -> Unit,
) {
    private val locale = "si-LK"
    private var recognizer: SpeechRecognizer? = null
    var listening: Boolean = false
        private set
    var servicePackage: String = ""
        private set

    fun isAvailable(): Boolean {
        val component = resolveService()
        if (component != null) {
            servicePackage = component.packageName
            return true
        }
        if (SpeechRecognizer.isRecognitionAvailable(context)) {
            servicePackage = "default"
            return true
        }
        return false
    }

    fun start() {
        release()
        val created = createRecognizer()
        if (created == null) {
            emit(
                mapOf(
                    "type" to "error",
                    "message" to "error_client",
                    "permanent" to true,
                ),
            )
            return
        }
        recognizer = created
        listening = true
        created.setRecognitionListener(listener)
        try {
            created.startListening(intent())
        } catch (_: RuntimeException) {
            listening = false
            release()
            emit(
                mapOf(
                    "type" to "error",
                    "message" to "error_client",
                    "permanent" to false,
                ),
            )
            emit(mapOf("type" to "status", "status" to "done"))
        }
    }

    fun stop() {
        listening = false
        recognizer?.stopListening()
    }

    fun cancel() {
        listening = false
        recognizer?.cancel()
        release()
    }

    fun release() {
        val current = recognizer ?: return
        recognizer = null
        listening = false
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            current.destroy()
        }
    }

    private fun intent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                2500,
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                2000,
            )
        }
    }

    private fun createRecognizer(): SpeechRecognizer? {
        val component = resolveService()
        return if (component != null) {
            servicePackage = component.packageName
            SpeechRecognizer.createSpeechRecognizer(context, component)
        } else if (SpeechRecognizer.isRecognitionAvailable(context)) {
            servicePackage = "default"
            SpeechRecognizer.createSpeechRecognizer(context)
        } else {
            null
        }
    }

    private fun resolveService(): ComponentName? {
        val services = context.packageManager.queryIntentServices(
            Intent(RecognitionService.SERVICE_INTERFACE),
            PackageManager.MATCH_ALL,
        )
        val google = services.firstOrNull { info ->
            info.serviceInfo?.packageName == "com.google.android.googlequicksearchbox"
        } ?: services.firstOrNull { info ->
            info.serviceInfo?.packageName?.contains("google") == true
        }
        val service = google?.serviceInfo ?: return null
        return ComponentName(service.packageName, service.name)
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            emit(mapOf("type" to "status", "status" to "listening"))
        }

        override fun onBeginningOfSpeech() {
            emit(mapOf("type" to "status", "status" to "listening"))
        }

        override fun onRmsChanged(rmsdB: Float) = Unit

        override fun onBufferReceived(buffer: ByteArray?) = Unit

        override fun onEndOfSpeech() = Unit

        override fun onError(error: Int) {
            listening = false
            when (error) {
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                    emit(
                        mapOf(
                            "type" to "error",
                            "message" to "error_permission",
                            "permanent" to true,
                        ),
                    )
                }
                12, 13 -> {
                    emit(
                        mapOf(
                            "type" to "error",
                            "message" to "error_language_unavailable",
                            "permanent" to true,
                        ),
                    )
                }
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                -> {
                    emit(mapOf("type" to "status", "status" to "done"))
                }
                else -> {
                    emit(
                        mapOf(
                            "type" to "error",
                            "message" to "error_client_$error",
                            "permanent" to false,
                        ),
                    )
                    emit(mapOf("type" to "status", "status" to "done"))
                }
            }
            release()
        }

        override fun onResults(results: Bundle?) {
            listening = false
            val text = firstText(results)
            if (text.isNotEmpty()) {
                emit(mapOf("type" to "result", "words" to text, "final" to true))
            }
            emit(mapOf("type" to "status", "status" to "done"))
            release()
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = firstText(partialResults)
            if (text.isNotEmpty()) {
                emit(mapOf("type" to "result", "words" to text, "final" to false))
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) = Unit
    }

    private fun firstText(bundle: Bundle?): String {
        val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return matches?.firstOrNull()?.trim().orEmpty()
    }
}
