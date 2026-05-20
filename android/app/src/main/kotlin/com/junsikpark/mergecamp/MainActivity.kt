package com.junsikpark.mergecamp

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var tapPlayer: MediaPlayer? = null
    private var mergePlayer: MediaPlayer? = null
    private var warningPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "merge_camp/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playTap" -> {
                    playSound("assets/audio/place.wav") { tapPlayer = it }
                    result.success(null)
                }
                "playMerge" -> {
                    playSound("assets/audio/merge.wav") { mergePlayer = it }
                    result.success(null)
                }
                "playWarning" -> {
                    playSound("assets/audio/warning.wav") { warningPlayer = it }
                    result.success(null)
                }
                "disposeAudio" -> {
                    disposeAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        disposeAudio()
        super.onDestroy()
    }

    private fun playSound(asset: String, assignPlayer: (MediaPlayer?) -> Unit) {
        runCatching {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
            val descriptor = assets.openFd("flutter_assets/$key")
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build(),
            )
            player.setDataSource(
                descriptor.fileDescriptor,
                descriptor.startOffset,
                descriptor.length,
            )
            descriptor.close()
            player.prepare()
            player.setOnCompletionListener {
                it.release()
                assignPlayer(null)
            }
            assignPlayer(player)
            player.start()
        }.onFailure {
            assignPlayer(null)
        }
    }

    private fun disposeAudio() {
        tapPlayer?.release()
        mergePlayer?.release()
        warningPlayer?.release()
        tapPlayer = null
        mergePlayer = null
        warningPlayer = null
    }
}
