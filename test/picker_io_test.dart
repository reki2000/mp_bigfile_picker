import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_bigfile_picker/mp_bigfile_picker.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mp_bigfile_picker');
  final nativeCalls = <MethodCall>[];
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mp_bigfile_picker_mock');
    nativeCalls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeCalls.add(call);
      return null;
    });
  });

  tearDown(() async {
    debugDirectoryDialog = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test(
    'mock directory access selects, restores and releases local paths',
    () async {
      String? title, initial;
      debugDirectoryDialog = ({dialogTitle, initialDirectory}) async {
        title = dialogTitle;
        initial = initialDirectory;
        return dir.path;
      };
      await File('${dir.path}/fixture.gb').writeAsString('fixture');
      final picked = (await pickDirectory(
        dialogTitle: 'ROM fixtures',
        initialDirectory: dir.path,
      ))!;
      expect(title, 'ROM fixtures');
      expect(initial, dir.path);
      expect(picked.displayPath, dir.path);
      expect(picked.restoreKey, dir.path);

      await File('${dir.path}/fresh.gb').writeAsString('fresh');
      final restored = (await restoreDirectory(
        picked.restoreKey!,
        requestPermission: true,
      ))!;
      expect(restored.identityKey, picked.identityKey);
      expect(restored.restoreKey, picked.restoreKey);
      expect((await restored.walk().toList())..sort(), [
        'fixture.gb',
        'fresh.gb',
      ]);
      final file = restored.open('fresh.gb');
      try {
        expect(await file.read(0, 5), 'fresh'.codeUnits);
      } finally {
        await file.close();
      }
      await releaseDirectory(restored.restoreKey!);
      expect(nativeCalls, isEmpty);
    },
  );

  test('mock restoration returns null for a removed directory', () async {
    debugDirectoryDialog = ({dialogTitle, initialDirectory}) async => dir.path;
    final picked = (await pickDirectory())!;
    await dir.delete(recursive: true);
    expect(await restoreDirectory(picked.restoreKey!), isNull);
    await releaseDirectory(picked.restoreKey!);
    expect(nativeCalls, isEmpty);
  });

  test('mock directory selection can be cancelled', () async {
    debugDirectoryDialog = ({dialogTitle, initialDirectory}) async => null;
    expect(await pickDirectory(), isNull);
    expect(nativeCalls, isEmpty);
  });
}
