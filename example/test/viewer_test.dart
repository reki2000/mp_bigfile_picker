import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_bigfile_picker/mp_bigfile_picker.dart';
import 'package:mp_bigfile_picker_example/main.dart';

/// Reports a file size without backing storage; generates only requested bytes.
class _VirtualFile extends RandomReadFile {
  final int size;
  final reads = <(int, int)>[];
  bool closed = false;

  _VirtualFile(this.size);

  @override
  String get name => 'large.bin';

  @override
  Future<int> length() async => size;

  @override
  Future<Uint8List> read(int offset, int length) async {
    reads.add((offset, length));
    return Uint8List.fromList([
      for (int i = 0; i < min(length, size - offset); i++) (offset + i) & 0xff,
    ]);
  }

  @override
  Future<void> close() async => closed = true;
}

void main() {
  testWidgets('pages and seeks beyond 2 GiB with bounded reads',
      (tester) async {
    final file = _VirtualFile(5 * 1024 * 1024 * 1024);
    await tester.pumpWidget(
        MaterialApp(home: BinaryViewer(selectFile: () async => file)));
    await tester.tap(find.text('Open file'));
    await tester.pumpAndSettle();
    expect(file.reads, [(0, 256)]);
    expect(find.textContaining('00 01 02 03'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(file.reads.last, (256, 256));
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(file.reads.last, (0, 256));

    await tester.enterText(find.byType(TextField), '0x80000010');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(file.reads.last, (0x80000010, 256));
    expect(find.textContaining('000080000010'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '${file.size - 5}');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(file.reads.last, (file.size - 5, 5));
    expect(find.byTooltip('Next page'), findsOneWidget);
    final readCount = file.reads.length;
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(file.reads.length, readCount);

    await tester.enterText(find.byType(TextField), '-1');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('Offset must be within the file.'), findsOneWidget);
    expect(file.reads.length, readCount);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(file.closed, isTrue);
  });

  testWidgets('empty files and cancellation', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: BinaryViewer(selectFile: () async => null)));
    await tester.tap(find.text('Open file'));
    await tester.pumpAndSettle();
    expect(find.text('Open a file to inspect byte ranges.'), findsOneWidget);

    final file = _VirtualFile(0);
    await tester.pumpWidget(MaterialApp(
        home: BinaryViewer(
            key: const ValueKey('empty'), selectFile: () async => file)));
    await tester.tap(find.text('Open file'));
    await tester.pumpAndSettle();
    expect(file.reads, [(0, 0)]);
    expect(find.textContaining('large.bin — 0 bytes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(file.closed, isTrue);
  });
}
