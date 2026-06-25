import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ImageUrlToBase64Widget extends StatefulWidget {
  final String? initialUrl;
  final String? initialBase64;
  final bool showBase64Text;
  final ValueChanged<String>? onBase64Changed;

  const ImageUrlToBase64Widget({
    super.key,
    this.initialUrl,
    this.initialBase64,
    this.showBase64Text = true,
    this.onBase64Changed,
  });

  @override
  State<ImageUrlToBase64Widget> createState() => _ImageUrlToBase64WidgetState();
}

class _ImageUrlToBase64WidgetState extends State<ImageUrlToBase64Widget> {
  static const double _previewIconSize = 50;
  static const int _outputIconSize = 128;

  final TextEditingController _urlController = TextEditingController();
  final Dio _dio = Dio();

  bool _isLoading = false;
  String? _errorMessage;
  String _base64 = '';
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl ?? '';
    final initialBase64 = widget.initialBase64?.trim() ?? '';
    if (initialBase64.isNotEmpty) {
      try {
        _previewBytes = base64Decode(initialBase64);
        _base64 = initialBase64;
      } catch (_) {
        _previewBytes = null;
        _base64 = '';
      }
    }
  }

  @override
  void didUpdateWidget(covariant ImageUrlToBase64Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialUrl != widget.initialUrl) {
      _urlController.text = widget.initialUrl ?? '';
    }

    if (oldWidget.initialBase64 != widget.initialBase64) {
      final nextBase64 = widget.initialBase64?.trim() ?? '';
      if (nextBase64.isEmpty) {
        setState(() {
          _previewBytes = null;
          _base64 = '';
        });
      } else {
        try {
          final bytes = base64Decode(nextBase64);
          setState(() {
            _previewBytes = bytes;
            _base64 = nextBase64;
          });
        } catch (_) {
          setState(() {
            _previewBytes = null;
            _base64 = '';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _convertFromUrl() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an image URL.';
      });
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      setState(() {
        _errorMessage = 'URL is not valid.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.get<List<int>>(
        rawUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final downloaded = response.data;
      if (downloaded == null || downloaded.isEmpty) {
        throw Exception('Empty image response.');
      }

      final resized = await _resizeToSquarePng(
        Uint8List.fromList(downloaded),
        _outputIconSize,
      );

      final base64Value = base64Encode(resized);

      if (!mounted) {
        return;
      }

      setState(() {
        _previewBytes = resized;
        _base64 = base64Value;
      });

      widget.onBase64Changed?.call(base64Value);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Conversion failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List> _resizeToSquarePng(Uint8List bytes, int size) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw Exception('Unable to encode resized image.');
    }
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF1F1F23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3B3B42)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Image URL to Base64',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Web image URL',
                labelStyle: const TextStyle(color: Color(0xFFB8B8C5)),
                hintText: 'https://example.com/image.png',
                hintStyle: const TextStyle(color: Color(0xFF7E7E8A)),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4A4A55)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF81C7FF)),
                ),
                suffixIcon: IconButton(
                  onPressed: _isLoading ? null : _convertFromUrl,
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Convert',
                ),
              ),
              onSubmitted: (_) {
                if (!_isLoading) {
                  _convertFromUrl();
                }
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isLoading ? null : _convertFromUrl,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: Text(
                    _isLoading ? 'Converting...' : 'Import and convert',
                  ),
                ),
                const SizedBox(width: 12),
                if (_previewBytes != null)
                  Container(
                    width: _previewIconSize,
                    height: _previewIconSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4A4A55)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(
                      _previewBytes!,
                      fit: BoxFit.cover,
                      width: _previewIconSize,
                      height: _previewIconSize,
                    ),
                  ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            if (widget.showBase64Text && _base64.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Base64 result',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _base64,
                style: const TextStyle(
                  color: Color(0xFFD9D9E8),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
