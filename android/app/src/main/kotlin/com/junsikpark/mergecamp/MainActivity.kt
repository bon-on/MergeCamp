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
    private val effectPlayers = mutableSetOf<MediaPlayer>()
    private var musicPlayer: MediaPlayer? = null

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
                "play" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume") ?: 1.0
                    if (asset != null) {
                        playEffect(asset, volume.toFloat())
                    }
                    result.success(null)
                }
                "startLoop" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume") ?: 1.0
                    if (asset != null) {
                        startLoop(asset, volume.toFloat())
                    }
                    result.success(null)
                }
                "stopLoop" -> {
                    stopLoop()
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
            val descriptor = assets.openFd(key)
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

    private fun openPlayer(asset: String, usage: Int): MediaPlayer {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val descriptor = assets.openFd(key)
        val player = MediaPlayer()
        player.setAudioAttributes(
            AudioAttributes.Builder()
                .setContentType(usage)
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
        return player
    }

    // Generic one-shot effects may overlap; each player releases itself.
    private fun playEffect(asset: String, volume: Float) {
        runCatching {
            val player = openPlayer(asset, AudioAttributes.CONTENT_TYPE_SONIFICATION)
            player.setVolume(volume, volume)
            player.setOnCompletionListener {
                it.release()
                effectPlayers.remove(it)
            }
            effectPlayers.add(player)
            player.start()
        }
    }

    private fun startLoop(asset: String, volume: Float) {
        stopLoop()
        runCatching {
            val player = openPlayer(asset, AudioAttributes.CONTENT_TYPE_MUSIC)
            player.isLooping = true
            player.setVolume(volume, volume)
            musicPlayer = player
            player.start()
        }.onFailure {
            musicPlayer = null
        }
    }

    private fun stopLoop() {
        runCatching { musicPlayer?.stop() }
        musicPlayer?.release()
        musicPlayer = null
    }

    private fun disposeAudio() {
        stopLoop()
        effectPlayers.forEach { it.release() }
        effectPlayers.clear()
        tapPlayer?.release()
        mergePlayer?.release()
        warningPlayer?.release()
        tapPlayer = null
        mergePlayer = null
        warningPlayer = null
    }
}
