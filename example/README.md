# mp_bigfile_picker examples

Run from this directory:

```sh
flutter pub get
flutter run -d <device>
```

The binary viewer opens one file and displays hex and ASCII. Each page reads at most 256 bytes. Enter a decimal offset or a hexadecimal offset prefixed with `0x`, or use the previous/next page buttons. Offset navigation supports files larger than 2 GiB without loading their contents in full.

Use the CUE/BIN files in `files/` for a small fixture. On mobile, copy them to storage accessible through the system picker. `track.bin` contains two zero-filled 2048-byte Mode 1 payloads; the fixture contains no ISO 9660 filesystem.

For directory traversal, restoration and timed random reads:

```sh
flutter run -t lib/diagnostics.dart -d <device>
```

The diagnostic app lists selected files, reads their head and tail, and measures 256 random reads of up to 2352 bytes. It saves restore keys with `shared_preferences` and restores access on startup where supported. Browser permission renewal may require selecting the directory again.

Viewer tests use a virtual 5 GiB file that generates only the requested bytes. No multi-gigabyte fixture is allocated or written to disk. The bundled BIN fixture is 4 KiB.
