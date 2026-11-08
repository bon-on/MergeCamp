import 'package:flutter/services.dart';

import '../merge_camp_controller.dart';
import 'result_share_stub.dart'
    if (dart.library.js_interop) 'result_share_web.dart'
    as web;
import 'share_status.dart';

export 'share_status.dart';

/// Clipboard, download and Web Share for a finished run. Every method
/// reports failure instead of throwing. Tests inject a fake.
class ResultShare {
  const ResultShare();

  /// "Save card" (download the PNG) is available.
  bool get canSaveImage => web.webCanDownload();

  /// The Web Share API is available and allowed.
  bool get canShare => web.webCanShare();

  Future<bool> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return web.webCopyFallback(text);
    }
  }

  Future<bool> saveImage(Uint8List png, String fileName) =>
      web.webDownload(png, fileName);

  Future<ShareStatus> share({
    required String text,
    Uint8List? png,
    required String fileName,
  }) => web.webShare(text: text, png: png, fileName: fileName);
}

/// The text put on the clipboard and into the share sheet.
String resultShareText({
  required int score,
  required int highestTier,
  required int level,
  required String link,
}) =>
    'I scored $score in MergeCamp! '
    'Top camp: ${MergeCampController.campTierName(highestTier)}, '
    'camp Lv $level. $link';
