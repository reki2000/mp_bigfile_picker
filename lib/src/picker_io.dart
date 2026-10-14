import 'dart:io';

import 'package:flutter/foundation.dart';

import '../api.dart';
import 'io_impl.dart';
import 'native_picker.dart';

// Top-level final fields are initialized lazily, once on first native access.
final NativePicker _picker = createNativePicker();

/// Replaces native directory access in tests with local paths, or null on
/// cancellation. While set, restoration uses paths and release is a no-op.
@visibleForTesting
Future<String?> Function({String? dialogTitle, String? initialDirectory})?
debugDirectoryDialog;

/// Selects a directory, returning null on cancellation.
/// [dialogTitle] and [initialDirectory] are hints on supported platforms.
Future<PickedDirectory?> pickDirectory({
  String? dialogTitle,
  String? initialDirectory,
}) async {
  if (debugDirectoryDialog case final dialog?) {
    final path = await dialog(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
    return path == null ? null : IoDirectory(path);
  }
  return _picker.pickDirectory(
    dialogTitle: dialogTitle,
    initialDirectory: initialDirectory,
  );
}

/// Restores a saved [PickedDirectory.restoreKey], or null if unavailable.
/// [requestPermission] is only used by the browser implementation.
Future<PickedDirectory?> restoreDirectory(
  String restoreKey, {
  bool requestPermission = false,
}) async {
  if (debugDirectoryDialog != null) {
    return await Directory(restoreKey).exists()
        ? IoDirectory(restoreKey)
        : null;
  }
  return _picker.restoreDirectory(
    restoreKey,
    requestPermission: requestPermission,
  );
}

/// Releases saved directory access identified by [restoreKey].
/// Local path restoration has no persistent permission to release.
Future<void> releaseDirectory(String restoreKey) async {
  if (debugDirectoryDialog != null) return;
  return _picker.releaseDirectory(restoreKey);
}

/// Selects files, returning null on cancellation.
/// [extensions] omit dots, for example 'cue'; Android ignores this filter.
/// [multiple] enables multiple selection. Dialog options are platform hints.
Future<List<RandomReadFile>?> pickFiles({
  List<String>? extensions,
  bool multiple = false,
  String? dialogTitle,
  String? initialDirectory,
}) async {
  return _picker.pickFiles(
    extensions: extensions,
    multiple: multiple,
    dialogTitle: dialogTitle,
    initialDirectory: initialDirectory,
  );
}

/// Restores a saved [RandomReadFile.restoreKey], or null if unavailable.
Future<RandomReadFile?> restoreFile(String restoreKey) async {
  return _picker.restoreFile(restoreKey);
}
