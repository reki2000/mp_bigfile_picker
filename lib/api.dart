/// Platform-independent file and directory interfaces.
library;

import 'dart:typed_data';

/// A file supporting reads at absolute byte offsets.
abstract class RandomReadFile {
  /// File name without the directory path.
  String get name;

  /// Key for `restoreFile`, or null when restoration is unavailable.
  /// Files in a [PickedDirectory] have no individual key; restore the directory.
  String? get restoreKey => null;

  /// Returns the file's byte length.
  Future<int> length();

  /// Reads up to [length] bytes at [offset], returning fewer bytes at EOF.
  /// Offsets and lengths must be nonnegative. Read errors propagate.
  /// Backend exception types and invalid-argument handling vary.
  Future<Uint8List> read(int offset, int length);

  /// Releases the open file handle. The next [read] can reopen the file.
  /// Avoid overlapping close with reads or length queries.
  Future<void> close();
}

/// A user-selected directory with relative-path file access.
abstract class PickedDirectory {
  /// Directory name without its parent path.
  String get name;

  /// Display path, or [name] when a full path is unavailable.
  String get displayPath => name;

  /// Key for `restoreDirectory`, or null when restoration is unavailable.
  /// Saved keys do not guarantee continued access after permission changes.
  String? get restoreKey;

  /// Stable directory identity, independent of a renewed permission token.
  /// Use [restoreKey], rather than this identity, to restore access.
  String? get identityKey => restoreKey;

  /// Recursively lists relative file paths separated by '/'.
  /// Local-file traversal skips unreadable subdirectories.
  Stream<String> walk();

  /// Returns a file at a path yielded by [walk], opened lazily on access.
  /// Android requires a prior walk to resolve the path to a document URI.
  RandomReadFile open(String path);
}
