import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../api.dart';
import 'darwin_impl.dart';
import 'io_impl.dart';
import 'saf_impl.dart';

bool get _isDarwin => Platform.isIOS || Platform.isMacOS;

/// Replaces native directory access in tests with local paths, or null on
/// cancellation. While set, restoration uses paths and release is a no-op.
@visibleForTesting
Future<String?> Function({String? dialogTitle, String? initialDirectory})?
    debugDirectoryDialog;

/// Selects a directory, returning null on cancellation.
/// [dialogTitle] and [initialDirectory] are hints on supported platforms.
Future<PickedDirectory?> pickDirectory(
    {String? dialogTitle, String? initialDirectory}) async {
  if (debugDirectoryDialog case final dialog?) {
    final path = await dialog(
        dialogTitle: dialogTitle, initialDirectory: initialDirectory);
    return path == null ? null : IoDirectory(path);
  }
  if (Platform.isAndroid) return pickSafDirectory();
  if (_isDarwin) return pickDarwinDirectory(dialogTitle: dialogTitle);

  final path = await FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle, initialDirectory: initialDirectory);
  return path == null ? null : IoDirectory(path);
}

/// Restores a saved [PickedDirectory.restoreKey], or null if unavailable.
/// [requestPermission] is only used by the browser implementation.
Future<PickedDirectory?> restoreDirectory(String restoreKey,
    {bool requestPermission = false}) async {
  if (debugDirectoryDialog == null) {
    if (Platform.isAndroid) return restoreSafDirectory(restoreKey);
    if (_isDarwin) return restoreDarwinDirectory(restoreKey);
  }

  return await Directory(restoreKey).exists() ? IoDirectory(restoreKey) : null;
}

/// Releases saved directory access identified by [restoreKey].
/// Local path restoration has no persistent permission to release.
Future<void> releaseDirectory(String restoreKey) async {
  if (debugDirectoryDialog != null) return;
  if (Platform.isAndroid) return releaseSafDirectory(restoreKey);
  if (_isDarwin) return releaseDarwin(restoreKey);
}

/// Selects files, returning null on cancellation.
/// [extensions] omit dots, for example 'cue'; Android ignores this filter.
/// [multiple] enables multiple selection. Dialog options are platform hints.
Future<List<RandomReadFile>?> pickFiles(
    {List<String>? extensions,
    bool multiple = false,
    String? dialogTitle,
    String? initialDirectory}) async {
  if (Platform.isAndroid) return pickSafFiles(multiple: multiple);
  if (_isDarwin) {
    return pickDarwinFiles(
        extensions: extensions, multiple: multiple, dialogTitle: dialogTitle);
  }

  final type = extensions == null ? FileType.any : FileType.custom;
  final picked = multiple
      ? await FilePicker.pickFiles(
          dialogTitle: dialogTitle,
          initialDirectory: initialDirectory,
          type: type,
          allowedExtensions: extensions)
      : [
          if (await FilePicker.pickFile(
                  dialogTitle: dialogTitle,
                  initialDirectory: initialDirectory,
                  type: type,
                  allowedExtensions: extensions)
              case final file?)
            file
        ];
  if (picked.isEmpty) return null;
  return picked
      .map((f) => f.path)
      .whereType<String>()
      .map((path) => IoReadFile(path, restoreKey: path))
      .toList();
}

/// Restores a saved [RandomReadFile.restoreKey], or null if unavailable.
Future<RandomReadFile?> restoreFile(String restoreKey) async {
  if (Platform.isAndroid) return restoreSafFile(restoreKey);
  if (_isDarwin) return restoreDarwinFile(restoreKey);

  return await File(restoreKey).exists()
      ? IoReadFile(restoreKey, restoreKey: restoreKey)
      : null;
}
