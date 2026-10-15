// Exercises native filesystem adapters and mocked platform channels.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_bigfile_picker/src/native_picker.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mp_bigfile_picker');
  late Directory dir;
  late File fixture;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mp_bigfile_picker_backend');
    fixture = await File('${dir.path}/fixture.gb').writeAsString('rom');
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await dir.delete(recursive: true);
  });

  for (final os in ['ios', 'macos']) {
    test(
      '$os uses Darwin bookmarks for directory and file operations',
      () async {
        final calls = <MethodCall>[];
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          calls.add(call);
          return switch (call.method) {
            'pickDirectory' => {'path': dir.path, 'key': 'directory-key'},
            'pickFiles' => [
              {'path': fixture.path, 'key': 'file-key'},
            ],
            'restore' => {
              'path': call.arguments == 'directory-key'
                  ? dir.path
                  : fixture.path,
              'key': 'renewed-${call.arguments}',
            },
            'release' => null,
            _ => throw MissingPluginException(call.method),
          };
        });
        final picker = createNativePicker(operatingSystem: os);
        final folder = (await picker.pickDirectory(
          dialogTitle: 'ROM directory',
          initialDirectory: '/hint',
        ))!;
        expect(folder.identityKey, dir.path);
        expect(folder.restoreKey, 'directory-key');
        final files = (await picker.pickFiles(
          extensions: ['gb'],
          multiple: true,
          dialogTitle: 'ROM files',
          initialDirectory: '/hint',
        ))!;
        expect(files.single.name, 'fixture.gb');
        expect(files.single.restoreKey, 'file-key');

        final restoredFolder = (await picker.restoreDirectory(
          folder.restoreKey!,
          requestPermission: true,
        ))!;
        expect(restoredFolder.identityKey, folder.identityKey);
        expect(restoredFolder.restoreKey, 'renewed-directory-key');
        final restoredFile = (await picker.restoreFile(
          files.single.restoreKey!,
        ))!;
        expect(restoredFile.restoreKey, 'renewed-file-key');
        try {
          expect(await restoredFile.read(0, 3), 'rom'.codeUnits);
        } finally {
          await restoredFile.close();
        }
        await picker.releaseDirectory(folder.restoreKey!);

        expect(calls.map((call) => call.method), [
          'pickDirectory',
          'pickFiles',
          'restore',
          'restore',
          'release',
        ]);
        expect(calls[0].arguments, {'title': 'ROM directory'});
        expect(calls[1].arguments, {
          'extensions': ['gb'],
          'multiple': true,
          'title': 'ROM files',
        });
        expect(calls[2].arguments, 'directory-key');
        expect(calls[3].arguments, 'file-key');
        expect(calls[4].arguments, 'directory-key');
      },
    );
  }

  test('Android uses SAF URIs for directory and file operations', () async {
    const treeUri = 'content://fixtures/tree/roms';
    const fileUri = 'content://fixtures/document/fixture.gb';
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'pickDirectory' => {'uri': treeUri, 'name': 'roms'},
        'pickFiles' => [
          {'uri': fileUri, 'name': 'fixture.gb'},
        ],
        'restoreDirectory' => 'roms',
        'restoreFile' => 'fixture.gb',
        'releaseDirectory' => null,
        _ => throw MissingPluginException(call.method),
      };
    });
    final picker = createNativePicker(operatingSystem: 'android');
    final folder = (await picker.pickDirectory(
      dialogTitle: 'ROM directory',
      initialDirectory: '/hint',
    ))!;
    expect(folder.name, 'roms');
    expect(folder.restoreKey, treeUri);
    final files = (await picker.pickFiles(
      extensions: ['gb'],
      multiple: true,
      dialogTitle: 'ROM files',
    ))!;
    expect(files.single.name, 'fixture.gb');
    expect(files.single.restoreKey, fileUri);
    final restoredFolder = (await picker.restoreDirectory(
      treeUri,
      requestPermission: true,
    ))!;
    expect(restoredFolder.restoreKey, treeUri);
    final restoredFile = (await picker.restoreFile(fileUri))!;
    expect(restoredFile.name, 'fixture.gb');
    expect(restoredFile.restoreKey, fileUri);
    await picker.releaseDirectory(treeUri);
    expect(calls.map((call) => call.method), [
      'pickDirectory',
      'pickFiles',
      'restoreDirectory',
      'restoreFile',
      'releaseDirectory',
    ]);
    expect(calls[0].arguments, isNull);
    expect(calls[1].arguments, {'multiple': true});
    expect(calls[2].arguments, treeUri);
    expect(calls[3].arguments, fileUri);
    expect(calls[4].arguments, treeUri);
  });

  for (final os in ['linux', 'windows', 'fuchsia']) {
    test('$os restores local paths without native permission calls', () async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      final picker = createNativePicker(operatingSystem: os);
      final folder = (await picker.restoreDirectory(
        dir.path,
        requestPermission: true,
      ))!;
      expect(folder.displayPath, dir.path);
      expect(folder.restoreKey, dir.path);
      final file = (await picker.restoreFile(fixture.path))!;
      try {
        expect(await file.read(0, 3), 'rom'.codeUnits);
      } finally {
        await file.close();
      }
      expect(await picker.restoreDirectory('${dir.path}/missing'), isNull);
      expect(await picker.restoreFile('${dir.path}/missing.gb'), isNull);
      await picker.releaseDirectory(folder.restoreKey!);
      expect(calls, isEmpty);
    });
  }
}
