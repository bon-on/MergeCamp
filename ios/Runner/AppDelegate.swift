import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var tapPlayer: AVAudioPlayer?
  private var mergePlayer: AVAudioPlayer?
  private var warningPlayer: AVAudioPlayer?

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

  private func disposeAudio() {
    tapPlayer?.stop()
    mergePlayer?.stop()
    warningPlayer?.stop()
    tapPlayer = nil
    mergePlayer = nil
    warningPlayer = nil
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    let appFrameworkURL = Bundle.main.bundleURL
      .appendingPathComponent("Frameworks/App.framework/flutter_assets", isDirectory: true)
      .appendingPathComponent(assetKey)

    if FileManager.default.fileExists(atPath: appFrameworkURL.path) {
      return appFrameworkURL
    }

    return Bundle.main.resourceURL?.appendingPathComponent(assetKey)
  }
}
