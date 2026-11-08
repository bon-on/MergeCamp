import 'dart:typed_data';

import 'share_status.dart';

/// Non-web builds: no download or Web Share; copy uses Flutter's clipboard.
bool webCanDownload() => false;

bool webCanShare() => false;

bool webCopyFallback(String text) => false;

Future<bool> webDownload(Uint8List bytes, String fileName) async => false;

Future<ShareStatus> webShare({
  required String text,
  Uint8List? png,
  required String fileName,
}) async => ShareStatus.failed;
