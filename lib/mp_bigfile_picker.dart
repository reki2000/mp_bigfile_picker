/// Flutter file and directory selection with random-access byte reads.
///
/// Android uses SAF file descriptors; iOS and macOS use security-scoped access.
/// Desktop files use dart:io, and browser files use Blob.slice.
/// The package reads requested ranges without making full-file copies.
library;

export 'api.dart';
export 'src/picker_io.dart' if (dart.library.js_interop) 'src/picker_web.dart';
