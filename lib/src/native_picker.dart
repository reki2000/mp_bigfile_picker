import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../api.dart';
import 'darwin_impl.dart';
import 'io_impl.dart';
import 'saf_impl.dart';

/// The native picker operations selected together for one operating system.
abstract interface class NativePicker {
  Future<PickedDirectory?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
  });

  Future<PickedDirectory?> restoreDirectory(
    String restoreKey, {
    bool requestPermission = false,
  });

  Future<void> releaseDirectory(String restoreKey);

  Future<List<RandomReadFile>?> pickFiles({
    List<String>? extensions,
    bool multiple = false,
    String? dialogTitle,
    String? initialDirectory,
  });

  Future<RandomReadFile?> restoreFile(String restoreKey);
}

/// The only native OS selector. Tests can select a backend on any host.
NativePicker createNativePicker({String? operatingSystem}) =>
    switch (operatingSystem ?? Platform.operatingSystem) {
      'android' => const _SafPicker(),
      'ios' || 'macos' => const _DarwinPicker(),
      _ => const _DesktopPicker(),
    };

class _SafPicker implements NativePicker {
  const _SafPicker();

  @override
  Future<PickedDirectory?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
  }) => pickSafDirectory();

  @override
  Future<PickedDirectory?> restoreDirectory(
    String restoreKey, {
    bool requestPermission = false,
  }) => restoreSafDirectory(restoreKey);

  @override
  Future<void> releaseDirectory(String restoreKey) =>
      releaseSafDirectory(restoreKey);

  @override
  Future<List<RandomReadFile>?> pickFiles({
    List<String>? extensions,
    bool multiple = false,
    String? dialogTitle,
    String? initialDirectory,
  }) => pickSafFiles(multiple: multiple);

  @override
  Future<RandomReadFile?> restoreFile(String restoreKey) =>
      restoreSafFile(restoreKey);
}

class _DarwinPicker implements NativePicker {
  const _DarwinPicker();

  @override
  Future<PickedDirectory?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
  }) => pickDarwinDirectory(dialogTitle: dialogTitle);

  @override
  Future<PickedDirectory?> restoreDirectory(
    String restoreKey, {
    bool requestPermission = false,
  }) => restoreDarwinDirectory(restoreKey);

  @override
  Future<void> releaseDirectory(String restoreKey) => releaseDarwin(restoreKey);

  @override
  Future<List<RandomReadFile>?> pickFiles({
    List<String>? extensions,
    bool multiple = false,
    String? dialogTitle,
    String? initialDirectory,
  }) => pickDarwinFiles(
    extensions: extensions,
    multiple: multiple,
    dialogTitle: dialogTitle,
  );

  @override
  Future<RandomReadFile?> restoreFile(String restoreKey) =>
      restoreDarwinFile(restoreKey);
}

class _DesktopPicker implements NativePicker {
  const _DesktopPicker();

  @override
  Future<PickedDirectory?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
    return path == null ? null : IoDirectory(path);
  }

  @override
  Future<PickedDirectory?> restoreDirectory(
    String restoreKey, {
    bool requestPermission = false,
  }) async =>
      await Directory(restoreKey).exists() ? IoDirectory(restoreKey) : null;

  @override
  Future<void> releaseDirectory(String restoreKey) async {}

  @override
  Future<List<RandomReadFile>?> pickFiles({
    List<String>? extensions,
    bool multiple = false,
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    final type = extensions == null ? FileType.any : FileType.custom;
    final picked = multiple
        ? await FilePicker.pickFiles(
            dialogTitle: dialogTitle,
            initialDirectory: initialDirectory,
            type: type,
            allowedExtensions: extensions,
          )
        : [
            if (await FilePicker.pickFile(
                  dialogTitle: dialogTitle,
                  initialDirectory: initialDirectory,
                  type: type,
                  allowedExtensions: extensions,
                )
                case final file?)
              file,
          ];
    if (picked.isEmpty) return null;
    return picked
        .map((f) => f.path)
        .whereType<String>()
        .map((path) => IoReadFile(path, restoreKey: path))
        .toList();
  }

  @override
  Future<RandomReadFile?> restoreFile(String restoreKey) async =>
      await File(restoreKey).exists()
      ? IoReadFile(restoreKey, restoreKey: restoreKey)
      : null;
}
