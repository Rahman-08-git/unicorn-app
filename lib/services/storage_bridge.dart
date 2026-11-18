/// Bridge to Android's Storage Access Framework so operators can pick any
/// folder (Downloads, Documents, USB drive, Google Drive…) and save exports there.
///
/// Implemented natively in android/app/src/main/kotlin/.../MainActivity.kt.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PickedFolder {
  const PickedFolder({required this.uri, required this.label});

  /// Persistable content:// tree URI returned by the system folder picker.
  final String uri;

  /// Human-readable location, e.g. "Internal storage/Download/Campaign".
  final String label;
}

class StorageBridge {
  const StorageBridge();

  static const MethodChannel _channel = MethodChannel('ull/storage');

  /// Folder picking is available on Android only.
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Opens the system file explorer so the operator can choose a folder.
  /// Returns null if they cancel.
  Future<PickedFolder?> pickFolder() async {
    final res = await _channel.invokeMapMethod<String, dynamic>('pickDirectory');
    if (res == null) return null;
    return PickedFolder(uri: res['uri'] as String, label: res['label'] as String? ?? 'Selected folder');
  }

  /// Human-readable label for a previously picked folder URI.
  Future<String> labelFor(String uri) async {
    try {
      return await _channel.invokeMethod<String>('labelFor', {'uri': uri}) ?? 'Selected folder';
    } catch (_) {
      return 'Selected folder';
    }
  }

  /// Whether the app still has permission to write into this folder.
  Future<bool> hasAccess(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess', {'uri': uri}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Writes text files into the picked folder. Returns the names actually created
  /// (Android may append " (1)" if a file with the same name already exists).
  Future<List<String>> writeTextFiles({
    required String folderUri,
    required Map<String, String> files,
    String mimeType = 'text/csv',
  }) async {
    final res = await _channel.invokeListMethod<String>('writeFiles', {
      'uri': folderUri,
      'mimeType': mimeType,
      'files': files.entries.map((e) => {'name': e.key, 'content': e.value}).toList(),
    });
    return res ?? const [];
  }

  /// Opens the folder in the device's file manager. Returns false if no app could open it.
  Future<bool> openFolder(String folderUri) async {
    try {
      return await _channel.invokeMethod<bool>('openDirectory', {'uri': folderUri}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
