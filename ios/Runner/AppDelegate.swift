import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var tapPlayer: AVAudioPlayer?
  private var mergePlayer: AVAudioPlayer?
  private var warningPlayer: AVAudioPlayer?
  private var effectPlayers: [AVAudioPlayer] = []
  private var musicPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureAudioChannel(pluginRegistry: engineBridge.pluginRegistry)
  }

  private func configureAudioChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "MergeCampAudio") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "merge_camp/audio",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "playTap":
        self.playSound(
          asset: "assets/audio/place.wav",
          player: &self.tapPlayer,
          volume: 0.58
        )
        result(nil)
      case "playMerge":
        self.playSound(
          asset: "assets/audio/merge.wav",
          player: &self.mergePlayer,
          volume: 0.72
        )
        result(nil)
      case "playWarning":
        self.playSound(
          asset: "assets/audio/warning.wav",
          player: &self.warningPlayer,
          volume: 0.68
        )
        result(nil)
      case "play":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          self.playEffect(asset: asset, volume: Float(args?["volume"] as? Double ?? 1.0))
        }
        result(nil)
      case "startLoop":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          self.startLoop(asset: asset, volume: Float(args?["volume"] as? Double ?? 1.0))
        }
        result(nil)
      case "stopLoop":
        self.stopLoop()
        result(nil)
      case "disposeAudio":
        self.disposeAudio()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
    }
  }

  private func playSound(
    asset: String,
    player: inout AVAudioPlayer?,
    volume: Float
  ) {
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      player = try AVAudioPlayer(contentsOf: url)
      player?.volume = volume
      player?.prepareToPlay()
      player?.play()
    } catch {
    }
  }

  // Generic one-shot effects may overlap, so finished players are pruned and
  // the rest are kept alive until they stop.
  private func playEffect(asset: String, volume: Float) {
    configureAudioSession()
    effectPlayers.removeAll { !$0.isPlaying }
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = volume
      player.prepareToPlay()
      player.play()
      effectPlayers.append(player)
    } catch {
    }
  }

  private func startLoop(asset: String, volume: Float) {
    stopLoop()
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = volume
      player.prepareToPlay()
      player.play()
      musicPlayer = player
    } catch {
    }
  }

  private func stopLoop() {
    musicPlayer?.stop()
    musicPlayer = nil
  }

  private func disposeAudio() {
    stopLoop()
    effectPlayers.forEach { $0.stop() }
    effectPlayers.removeAll()
    tapPlayer?.stop()
    mergePlayer?.stop()
    warningPlayer?.stop()
    tapPlayer = nil
    mergePlayer = nil
    warningPlayer = nil
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    // The lookup key is already relative to the app bundle
    // (Frameworks/App.framework/flutter_assets/...).
    let url = Bundle.main.bundleURL.appendingPathComponent(assetKey)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}
