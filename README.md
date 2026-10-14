# mp_bigfile_picker

Flutter file and directory picker with random-access reads. Supports Android, iOS, macOS, Windows, Linux and the web. Reads requested byte ranges without copying entire files in the package.

Requires Flutter 3.38+ and Dart 3.10+. Intended for disc images, archive parsers and binary viewers. Storage providers may download or stage remote files before access.

## Usage

Call pickers from a user action. Cancellation returns `null`. Directory paths use `/` and are relative to the selected directory.

```dart
import 'package:mp_bigfile_picker/mp_bigfile_picker.dart';

Future<void> readDirectory(void Function(String) log) async {
  final directory = await pickDirectory();
  if (directory == null) return;

  await for (final path in directory.walk()) {
    final file = directory.open(path);
    try {
      final bytes = await file.read(0, 16);
      log('$path: ${bytes.length} bytes');
    } finally {
      await file.close();
    }
  }
}

Future<void> readFiles(void Function(String) log) async {
  final files = await pickFiles(extensions: ['cue', 'bin'], multiple: true);
  if (files == null) return;

  for (final file in files) {
    try {
      final size = await file.length();
      final bytes = await file.read(0, 16);
      log('${file.name}: $size bytes; read ${bytes.length} bytes');
    } finally {
      await file.close();
    }
  }
}
```

The [example](example/lib/main.dart) is a paged binary viewer. Run from `example/`:

```sh
flutter pub get
flutter run -d <device>
```

Open a binary file, enter a decimal or hexadecimal byte offset, or use the page buttons. Each page reads at most 256 bytes and displays hex and ASCII. File contents are not loaded in full. Use the dummy CUE/BIN files in `example/files/` for a small fixture; on mobile, copy them to storage accessible through the system picker.

For directory traversal, restoration and timed random reads, run `flutter run -t lib/diagnostics.dart -d <device>`.

## Platforms

The public library separates web and IO implementations with a conditional export. On IO platforms, `picker_io.dart` initializes one `NativePicker` lazily, and `native_picker.dart` is the only OS selector. Directory and file operations then delegate to the selected SAF, Darwin, or desktop backend.

| Platform | Selection | Reads | Restoration |
|---|---|---|---|
| Android | Storage Access Framework | `pread64` on a document file descriptor | Persisted URI permission |
| iOS | Document picker, copying disabled | `dart:io` within security scope | Bookmark |
| macOS | `NSOpenPanel` | `dart:io` within security scope | Security-scoped bookmark |
| Windows, Linux | `file_picker` | `dart:io` | Path |
| Web | File System Access directory picker or file input | `Blob.slice` | Directory handles in IndexedDB; file inputs are session-only |

- Android documents must be seekable. Some cloud providers return pipes; `length()` throws `UnsupportedError` and reads may fail. Native reads are synchronous on the calling isolate and can delay the UI. `extensions` is ignored; the picker requests all MIME types.
- Android `open(path)` requires a path previously yielded by `walk()`.
- Sandboxed macOS apps require `com.apple.security.files.user-selected.read-only` and `com.apple.security.files.bookmarks.app-scope` entitlements.
- Web directory handles require a supporting browser and a secure context. Permission persistence is browser-controlled. The `webkitdirectory` fallback requires selection again after reload.

## Restoring access

Persist a non-null `restoreKey`. Call `restoreDirectory(key)` or `restoreFile(key)` after restart. A `null` result means access is unavailable. Files may move, permissions may expire, and browser storage may be cleared.

```dart
Future<PickedDirectory?> reopenDirectory(String key) => restoreDirectory(key);

// Call from a browser user action to request renewed permission.
Future<PickedDirectory?> requestDirectoryAccess(String key) =>
    restoreDirectory(key, requestPermission: true);
```

Directory files have no individual restore keys. Restore the directory, walk it again, and open the relative path. Save the returned `restoreKey` again after restoring an Apple bookmark; stale bookmarks may be renewed. `identityKey` identifies the directory independently of bookmark renewal and cannot restore access.

Call `releaseDirectory(key)` to release saved directory access. `close()` only releases the open file handle. Browser file inputs have no restore keys.

## Read contract

- `length()`: byte length. `read(offset, length)`: requested bytes, possibly shorter at EOF.
- Offsets and lengths must be nonnegative. Invalid-argument handling varies by backend.
- Each read allocates memory for its byte range. Use bounded reads for large files.
- Call `close()` in `finally`. The next read can reopen the file.
- Local-file reads are serialized. Avoid concurrent `close()`, `read()` and `length()` lifecycle operations.
- Read errors propagate; exception types vary by backend.
- Local directory traversal skips unreadable subdirectories.

## Storage adapters

- `package:mp_bigfile_picker/io.dart`: local-file reader without Flutter imports. The package still requires the Flutter SDK.
- `package:mp_bigfile_picker/web.dart`: reader for browser `File` objects obtained through other APIs.

## Tests

```sh
flutter test test/io_impl_test.dart
flutter test test/picker_io_test.dart test/darwin_impl_test.dart test/native_picker_test.dart
flutter test --platform chrome test/web_access_test.dart
```

Tests cover local traversal, overlapping reads, EOF, reopening, browser handle storage, restoration, permission requests and cancellation. Browser tests substitute the picker; native dialogs are not exercised. Multi-gigabyte benchmarks and an Android/iOS/macOS device-validation matrix are not yet available.

`debugDirectoryDialog` supplies local directory paths in native tests. While the callback is installed, those directories are restored by path and releasing access is a no-op, without native platform calls. Reset the callback to `null` in teardown. Darwin adapter tests verify bookmark restoration and release through the package's method channel separately.

## Codemagic builds

The repository root is a Flutter plugin. Its `ios/` directory contains plugin sources, not an Xcode application project. Build the host app in `example/`, which contains `ios/Runner.xcodeproj` and the Android application.

The root [codemagic.yaml](codemagic.yaml) defines the **Build mobile example** workflow. In Codemagic, use **Start new build**, select the branch containing this file, and choose that workflow. It runs the package's local and browser tests, runs the example's widget tests, and builds an unsigned iOS release app and a debug Android APK from `example/`. These artifacts are for build verification; the iOS app requires signing before installation on a device. The workflow has no automatic triggers or store publishing.

If using Codemagic's Flutter workflow editor instead, set **App settings > Build > Project path** to `example`. Rescan project paths if it is missing from the dropdown. Leaving the path as `.` causes `Did not find xcodeproj from .../clone/ios`. See the [Codemagic project-path documentation](https://docs.codemagic.io/flutter-configuration/flutter-projects/#multiple-flutter-projects-in-one-repository).

## License

MIT. See [LICENSE](LICENSE).
