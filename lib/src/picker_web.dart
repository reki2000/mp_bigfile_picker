import '../api.dart';
import 'web_access.dart';
import 'web_impl.dart';

/// replaces the directory dialog in tests (not used on the web)
Future<String?> Function({String? dialogTitle, String? initialDirectory})?
    debugDirectoryDialog;

/// Selects a directory from a user action, returning null on cancellation.
/// Uses File System Access when available, otherwise a directory file input.
/// [dialogTitle] and [initialDirectory] are ignored in browsers.
Future<PickedDirectory?> pickDirectory(
        {String? dialogTitle, String? initialDirectory}) =>
    pickAccessDirectory();

/// Restores a saved directory handle, or null if unavailable.
/// Set [requestPermission] from a user action to request renewed read access.
Future<PickedDirectory?> restoreDirectory(String restoreKey,
        {bool requestPermission = false}) =>
    restoreAccessDirectory(restoreKey, requestPermission: requestPermission);

/// Removes the saved directory handle identified by [restoreKey].
/// Browser permission revocation remains under browser control.
Future<void> releaseDirectory(String restoreKey) =>
    releaseAccessDirectory(restoreKey);

/// Selects files from a user action, returning null on cancellation.
/// [extensions] omit dots. [multiple] enables multiple selection.
/// [dialogTitle] and [initialDirectory] are ignored in browsers.
Future<List<RandomReadFile>?> pickFiles(
        {List<String>? extensions,
        bool multiple = false,
        String? dialogTitle,
        String? initialDirectory}) =>
    pickWebFiles(extensions: extensions, multiple: multiple);

/// Returns null: browser file inputs do not support restoration.
Future<RandomReadFile?> restoreFile(String restoreKey) async => null;
