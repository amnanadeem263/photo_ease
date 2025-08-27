import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ai_service.dart';

class EditorScreen extends StatefulWidget {
  final File originalFile;
  const EditorScreen(this.originalFile, {Key? key}) : super(key: key);

  @override
  _EditorScreenState createState() => _EditorScreenState();
}

enum FilterType { none, grayscale, sepia }

class _EditorScreenState extends State<EditorScreen> {
  late File _currentFile;
  double _brightness = 0.0;
  FilterType _filter = FilterType.none;
  String _overlayText = '';
  int _selectedTextStyle = 0;
  bool _isProcessing = false;
  final Box box = Hive.box('images');

  final List<TextStyle> _textPresets = [
    const TextStyle(
      fontSize: 28,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontFamily: "Roboto",
      shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
    ),
    const TextStyle(
      fontSize: 24,
      color: Colors.black,
      fontStyle: FontStyle.italic,
      fontFamily: "Roboto",
    ),
    const TextStyle(
      fontSize: 30,
      color: Colors.yellow,
      fontWeight: FontWeight.w700,
      fontFamily: "Roboto",
      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
    ),
    const TextStyle(
      fontSize: 22,
      color: Colors.red,
      fontWeight: FontWeight.bold,
      fontFamily: "Roboto",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentFile = widget.originalFile;
  }

  Future<void> _crop() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: _currentFile.path,
    );
    if (cropped != null) {
      setState(() => _currentFile = File(cropped.path));
    }
  }

  img.Image _decodeImage(File file) {
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      throw Exception('Unable to decode image or invalid size.');
    }
    return decoded;
  }

  img.Image _applyFilterAndBrightness(img.Image src) {
    img.Image out = src.clone();

    if (_brightness.abs() > 0.001) {
      out = img.adjustColor(out, brightness: (_brightness * 100).toInt());
    }

    switch (_filter) {
      case FilterType.grayscale:
        out = img.grayscale(out);
        break;
      case FilterType.sepia:
        out = img.sepia(out);
        break;
      case FilterType.none:
        break;
    }

    return out;
  }

  Future<File> _renderFinalImage() async {
    setState(() => _isProcessing = true);
    try {
      final src = _decodeImage(_currentFile);
      final processed = _applyFilterAndBrightness(src);

      final bytes = img.encodePng(processed);
      final dir = await getApplicationDocumentsDirectory();
      final outFile = File(
          '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png');
      await outFile.writeAsBytes(bytes);

      return outFile;
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveFinal({String title = ''}) async {
    try {
      final file = await _renderFinalImage();
      box.add({
        'path': file.path,
        'title': title,
        'created': DateTime.now().toIso8601String()
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("❌ Save failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save image: $e")),
      );
    }
  }

  Future<void> _askGptForCaption() async {
    final descriptionController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Describe image (optional)'),
        content: TextField(controller: descriptionController),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, descriptionController.text.trim()),
              child: const Text('Generate')),
        ],
      ),
    );
    if (result == null) return;

    final svc = AiService(
        apiKey:
        "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"); // ⚠️ Replace with backend key, don’t keep in code
    final caption = await svc.generateCaption(result);
    setState(() => _overlayText = caption);
  }

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.crop), onPressed: _crop),
            IconButton(
                icon: const Icon(Icons.filter_none),
                onPressed: () => setState(() => _filter = FilterType.none)),
            IconButton(
                icon: const Icon(Icons.photo_filter),
                onPressed: () => setState(() => _filter = FilterType.grayscale)),
            IconButton(
                icon: const Icon(Icons.tonality),
                onPressed: () => setState(() => _filter = FilterType.sepia)),
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: () async {
                final txt = await _showTextInput();
                if (txt != null) setState(() => _overlayText = txt);
              },
            ),
            IconButton(
                icon: const Icon(Icons.smart_toy), onPressed: _askGptForCaption),
          ],
        ),
        Row(
          children: [
            const Text('Brightness'),
            Expanded(
              child: Slider(
                value: _brightness,
                min: -1.0,
                max: 1.0,
                onChanged: (v) => setState(() => _brightness = v),
              ),
            ),
            ElevatedButton(
              onPressed:
              _isProcessing ? null : () => _saveFinal(title: _overlayText),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Future<String?> _showTextInput() async {
    final ctrl = TextEditingController(text: _overlayText);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overlay text'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = Image.file(_currentFile);
    return Scaffold(
      appBar: AppBar(title: const Text('Editor')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(child: imageWidget),
                if (_overlayText.isNotEmpty)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: Text(
                        _overlayText,
                        style: _textPresets[_selectedTextStyle],
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }
}
