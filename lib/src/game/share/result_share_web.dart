import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'share_status.dart';

// Browser helpers for sharing a result (feature-next-goal-share). Every
// function catches its own errors: sharing must never break the game.

JSObject? get _navigator =>
    globalContext.getProperty<JSObject?>('navigator'.toJS);

JSObject? get _document =>
    globalContext.getProperty<JSObject?>('document'.toJS);

bool webCanDownload() {
  try {
    final url = globalContext.getProperty<JSObject?>('URL'.toJS);
    return _document != null &&
        url != null &&
        url.has('createObjectURL') &&
        globalContext.has('Blob');
  } catch (_) {
    return false;
  }
}

/// Web Share exists and the page (or the portal iframe) allows it.
bool webCanShare() {
  try {
    final navigator = _navigator;
    if (navigator == null || !navigator.has('share')) return false;
    final document = _document;
    final policy =
        document?.getProperty<JSObject?>('permissionsPolicy'.toJS) ??
        document?.getProperty<JSObject?>('featurePolicy'.toJS);
    if (policy != null && policy.has('allowsFeature')) {
      final allowed = policy.callMethod<JSAny?>(
        'allowsFeature'.toJS,
        'web-share'.toJS,
      );
      if (allowed.dartify() == false) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Copies through a hidden textarea and `execCommand('copy')`, for frames
/// where the async clipboard API is blocked.
bool webCopyFallback(String text) {
  try {
    final document = _document;
    final body = document?.getProperty<JSObject?>('body'.toJS);
    if (document == null || body == null) return false;
    final area = document.callMethod<JSObject>(
      'createElement'.toJS,
      'textarea'.toJS,
    );
    area.setProperty('value'.toJS, text.toJS);
    area.callMethod<JSAny?>('setAttribute'.toJS, 'readonly'.toJS, ''.toJS);
    final style = area.getProperty<JSObject>('style'.toJS);
    style.setProperty('position'.toJS, 'fixed'.toJS);
    style.setProperty('left'.toJS, '-9999px'.toJS);
    style.setProperty('opacity'.toJS, '0'.toJS);
    body.callMethod<JSAny?>('appendChild'.toJS, area);
    try {
      area.callMethod<JSAny?>('select'.toJS);
      final ok = document.callMethod<JSAny?>('execCommand'.toJS, 'copy'.toJS);
      return ok.dartify() == true;
    } finally {
      area.callMethod<JSAny?>('remove'.toJS);
    }
  } catch (_) {
    return false;
  }
}

JSObject _blobOptions() =>
    JSObject()..setProperty('type'.toJS, 'image/png'.toJS);

/// Downloads [bytes] as [fileName] with a Blob URL and an `<a download>`.
Future<bool> webDownload(Uint8List bytes, String fileName) async {
  try {
    final document = _document;
    final body = document?.getProperty<JSObject?>('body'.toJS);
    final urlApi = globalContext.getProperty<JSObject?>('URL'.toJS);
    if (document == null || body == null || urlApi == null) return false;
    final blob = _Blob(<JSAny>[bytes.toJS].toJS, _blobOptions());
    final url = urlApi.callMethod<JSString>('createObjectURL'.toJS, blob);
    final anchor = document.callMethod<JSObject>(
      'createElement'.toJS,
      'a'.toJS,
    );
    anchor.setProperty('href'.toJS, url);
    anchor.setProperty('download'.toJS, fileName.toJS);
    anchor
        .getProperty<JSObject>('style'.toJS)
        .setProperty('display'.toJS, 'none'.toJS);
    body.callMethod<JSAny?>('appendChild'.toJS, anchor);
    anchor.callMethod<JSAny?>('click'.toJS);
    anchor.callMethod<JSAny?>('remove'.toJS);
    // Revoke later: the download starts asynchronously.
    Timer(const Duration(seconds: 30), () {
      try {
        urlApi.callMethod<JSAny?>('revokeObjectURL'.toJS, url);
      } catch (_) {}
    });
    return true;
  } catch (_) {
    return false;
  }
}

/// Opens the Web Share sheet with [text] and, when the browser can share
/// files, the [png] card.
Future<ShareStatus> webShare({
  required String text,
  Uint8List? png,
  required String fileName,
}) async {
  try {
    final navigator = _navigator;
    if (navigator == null || !navigator.has('share')) {
      return ShareStatus.failed;
    }
    final data = JSObject()
      ..setProperty('title'.toJS, 'MergeCamp'.toJS)
      ..setProperty('text'.toJS, text.toJS);
    if (png != null && navigator.has('canShare') && globalContext.has('File')) {
      final files = <JSAny>[
        _File(<JSAny>[png.toJS].toJS, fileName, _blobOptions()),
      ].toJS;
      final probe = JSObject()..setProperty('files'.toJS, files);
      final ok = navigator.callMethod<JSAny?>('canShare'.toJS, probe);
      if (ok.dartify() == true) data.setProperty('files'.toJS, files);
    }
    await navigator.callMethod<JSPromise<JSAny?>>('share'.toJS, data).toDart;
    return ShareStatus.done;
  } catch (error) {
    return '$error'.contains('AbortError')
        ? ShareStatus.cancelled
        : ShareStatus.failed;
  }
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, JSObject options);
}

@JS('File')
extension type _File._(JSObject _) implements JSObject {
  external factory _File(JSArray<JSAny> parts, String name, JSObject options);
}
