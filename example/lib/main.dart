import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mp_bigfile_picker/mp_bigfile_picker.dart';

void main() => runApp(const MaterialApp(home: BinaryViewer()));

class BinaryViewer extends StatefulWidget {
  final Future<RandomReadFile?> Function()? selectFile;

  const BinaryViewer({super.key, this.selectFile});

  @override
  State<BinaryViewer> createState() => _BinaryViewerState();
}

class _BinaryViewerState extends State<BinaryViewer> {
  static const _pageSize = 256;
  final _offsetInput = TextEditingController(text: '0');
  RandomReadFile? _file;
  Future<Uint8List>? _pendingRead;
  Uint8List _bytes = Uint8List(0);
  int _size = 0;
  int _offset = 0;
  bool _busy = false;
  String? _error;

  Future<void> _select() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    RandomReadFile? selected;
    try {
      selected = widget.selectFile != null
          ? await widget.selectFile!()
          : (await pickFiles())?.firstOrNull;
      if (selected == null) return;
      final size = await selected.length();
      if (!mounted) return;
      await _file?.close();
      if (!mounted) return;
      _file = selected;
      selected = null;
      _size = size;
      _offset = 0;
      _bytes = Uint8List(0);
      _offsetInput.text = '0';
      await _load(0);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      await selected?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load(int offset) async {
    final file = _file;
    if (file == null) return;
    final read = file.read(offset, min(_pageSize, _size - offset));
    _pendingRead = read;
    try {
      final bytes = await read;
      if (!mounted) return;
      setState(() {
        _offset = offset;
        _bytes = bytes;
        _offsetInput.text = '0x${offset.toRadixString(16)}';
      });
    } finally {
      _pendingRead = null;
    }
  }

  Future<void> _go(int offset) async {
    if (_busy || _file == null) return;
    if (offset < 0 || (offset >= _size && !(_size == 0 && offset == 0))) {
      setState(() => _error = 'Offset must be within the file.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _load(offset);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _jump() {
    final text = _offsetInput.text.trim();
    final offset = int.tryParse(text);
    if (offset == null) {
      setState(
          () => _error = 'Enter a decimal offset or hexadecimal 0x offset.');
      return;
    }
    unawaited(_go(offset));
  }

  String _hexView() {
    final lines = <String>[];
    for (int start = 0; start < _bytes.length; start += 16) {
      final row = _bytes.sublist(start, min(start + 16, _bytes.length));
      final address = (_offset + start).toRadixString(16).padLeft(12, '0');
      final hex = row.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final ascii =
          String.fromCharCodes(row.map((b) => b >= 32 && b <= 126 ? b : 46));
      lines.add('$address  ${hex.padRight(47)}  |$ascii|');
    }
    return lines.join('\n');
  }

  @override
  void dispose() {
    _offsetInput.dispose();
    final file = _file;
    final pending = _pendingRead;
    // Wait for an active read before closing its handle.
    unawaited(() async {
      try {
        await pending;
      } catch (_) {
        // Read errors are displayed while the viewer is mounted.
      } finally {
        await file?.close();
      }
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Binary file viewer'),
          actions: [
            TextButton.icon(
              onPressed: _busy ? null : _select,
              icon: const Icon(Icons.file_open),
              label: const Text('Open file'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_file == null
                  ? 'Open a file to inspect byte ranges.'
                  : '${_file!.name} — $_size bytes'),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: !_busy && _file != null && _offset > 0
                        ? () => _go(max(0, _offset - _pageSize))
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _offsetInput,
                      enabled: !_busy && _file != null,
                      decoration: const InputDecoration(
                        labelText: 'Byte offset (decimal or 0x hex)',
                      ),
                      onSubmitted: (_) => _jump(),
                    ),
                  ),
                  TextButton(
                    onPressed: !_busy && _file != null ? _jump : null,
                    child: const Text('Go'),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed:
                        !_busy && _file != null && _offset + _pageSize < _size
                            ? () => _go(_offset + _pageSize)
                            : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Offset $_offset · ${_bytes.length} bytes · '
                  '$_pageSize bytes per page'),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      _hexView(),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
