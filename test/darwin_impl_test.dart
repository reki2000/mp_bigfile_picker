import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_bigfile_picker/src/darwin_impl.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mp_bigfile_picker');

  tearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );

  test(
    'Darwin restoration sends the bookmark and preserves its renewal',
    () async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return {'path': '/fixtures', 'key': 'renewed-bookmark'};
      });
      final folder = (await restoreDarwinDirectory('old-bookmark'))!;
      expect(calls.single.method, 'restore');
      expect(calls.single.arguments, 'old-bookmark');
      expect(folder.displayPath, '/fixtures');
      expect(folder.identityKey, '/fixtures');
      expect(folder.restoreKey, 'renewed-bookmark');
    },
  );

  test('Darwin restoration returns null when access is unavailable', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => null,
    );
    expect(await restoreDarwinDirectory('missing-bookmark'), isNull);
  });

  test(
    'Darwin restoration returns null after a native platform error',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'access_denied'),
      );
      expect(await restoreDarwinDirectory('denied-bookmark'), isNull);
    },
  );

  test(
    'Darwin release sends the saved bookmark to the native channel',
    () async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      await releaseDarwin('saved-bookmark');
      expect(calls.single.method, 'release');
      expect(calls.single.arguments, 'saved-bookmark');
    },
  );
}
