import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum FilterType {
  none,
  grayscale,
  sepia,
  invert,
  sharpen,
  blur,
  emboss,
  sobel,
  contrastBoost,
  contrastReduce,
  bright,
  dark,
  monoMood,
  vintage,
  coolTone
}

enum FlipType { none, horizontal, vertical }

class Sticker {
  String assetPath;
  Offset position;
  double scale;
  double rotation;

  Sticker({
    required this.assetPath,
    this.position = const Offset(100, 100),
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class EditorScreen extends StatefulWidget {
  final File originalFile;
  const EditorScreen(this.originalFile, {Key? key}) : super(key: key);

  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late File _currentFile;
  double _brightness = 0.0;
  FilterType _filter = FilterType.none;
  bool _isProcessing = false;
  Uint8List _imageBytes = Uint8List(0);
  final Box box = Hive.box('images');

  int _rotation = 0;
  FlipType _flip = FlipType.none;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.originalFile;
    _updatePreview();
  }

  img.Image _decodeImage(File file) {
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      throw Exception('Unable to decode image or invalid size.');
    }
    return decoded;
  }

  img.Image _sharpen(img.Image src) {
    final kernel = [0, -1, 0, -1, 5, -1, 0, -1, 0];
    return img.convolution(src, filter: kernel, div: 1);
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
      case FilterType.invert:
        out = img.invert(out);
        break;
      case FilterType.sharpen:
        out = _sharpen(out);
        break;
      case FilterType.blur:
        out = img.gaussianBlur(out,radius: 5);
        break;
      case FilterType.emboss:
        out = img.emboss(out);
        break;
      case FilterType.sobel:
        out = img.sobel(out);
        break;
      case FilterType.contrastBoost:
        out = img.adjustColor(out, contrast: 30);
        break;
      case FilterType.contrastReduce:
        out = img.adjustColor(out, contrast: -30);
        break;
      case FilterType.bright:
        out = img.adjustColor(out, brightness: 50);
        break;
      case FilterType.dark:
        out = img.adjustColor(out, brightness: -50);
        break;
      case FilterType.monoMood:
        out = img.grayscale(out);
        out = img.adjustColor(out, contrast: 20);
        break;
      case FilterType.vintage:
        out = img.sepia(out);
        out = img.adjustColor(out, contrast: 15, saturation: -10);
        break;
      case FilterType.coolTone:
        out = img.adjustColor(out, gamma: 1.2, saturation: -20);
        break;
      case FilterType.none:
        break;
    }

    // Flip
    if (_flip == FlipType.horizontal) out = img.flipHorizontal(out);
    if (_flip == FlipType.vertical) out = img.flipVertical(out);

    // Rotation
    if (_rotation != 0) out = img.copyRotate(out, angle: _rotation);

    return out;
  }

  void _updatePreview() {
    final src = _decodeImage(_currentFile);
    final processed = _applyFilterAndBrightness(src);
    setState(() {
      _imageBytes = Uint8List.fromList(img.encodePng(processed));
    });
  }

  Future<File> _renderFinalImage() async {
    setState(() => _isProcessing = true);
    try {
      final src = _decodeImage(_currentFile);
      final processed = _applyFilterAndBrightness(src);
      final bytes = img.encodePng(processed);
      final dir = await getApplicationDocumentsDirectory();
      final outFile = File('${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png');
      await outFile.writeAsBytes(bytes);
      return outFile;
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveFinal() async {
    try {
      final file = await _renderFinalImage();
      box.add({
        'path': file.path,
        'created': DateTime.now().toIso8601String()
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("❌ Save failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save image: $e"))
      );
    }
  }

  void _deleteImage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              try { if (_currentFile.existsSync()) _currentFile.deleteSync(); } catch (_) {}
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final filterNames = {
      FilterType.none: 'None',
      FilterType.grayscale: 'Grayscale',
      FilterType.sepia: 'Sepia',
      FilterType.invert: 'Invert',
      FilterType.sharpen: 'Sharpen',
      FilterType.blur: 'Blur',
      FilterType.emboss: 'Emboss',
      FilterType.sobel: 'Sobel',
      FilterType.contrastBoost: 'Contrast +',
      FilterType.contrastReduce: 'Contrast -',
      FilterType.bright: 'Bright',
      FilterType.dark: 'Dark',
      FilterType.monoMood: 'Mono Mood',
      FilterType.vintage: 'Vintage',
      FilterType.coolTone: 'Cool Tone'
    };

    return Column(
      children: [
        // Filter buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: FilterType.values.map((f) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: () { setState(() { _filter = f; _updatePreview(); }); },
                  child: Text(filterNames[f] ?? ''),
                ),
              );
            }).toList(),
          ),
        ),

        // Brightness slider
        Row(
          children: [
            const Text('Brightness'),
            Expanded(
              child: Slider(
                  value: _brightness,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (v) { setState(() => _brightness = v); _updatePreview(); }
              ),
            ),
          ],
        ),

        // Rotate & Flip icons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.rotate_left, size: 30),
              tooltip: 'Rotate Left',
              onPressed: () {
                setState(() {
                  _rotation = (_rotation - 90) % 360;
                  _updatePreview();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.rotate_right, size: 30),
              tooltip: 'Rotate Right',
              onPressed: () {
                setState(() {
                  _rotation = (_rotation + 90) % 360;
                  _updatePreview();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.flip, size: 30),
              tooltip: 'Flip Horizontal',
              onPressed: () {
                setState(() {
                  _flip = FlipType.horizontal;
                  _updatePreview();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_android, size: 30),
              tooltip: 'Flip Vertical',
              onPressed: () {
                setState(() {
                  _flip = FlipType.vertical;
                  _updatePreview();
                });
              },
            ),
          ],
        ),

        // Save button
        ElevatedButton(
          onPressed: _isProcessing ? null : _saveFinal,
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _imageBytes.isNotEmpty
        ? Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 4)),
      child: Image.memory(_imageBytes),
    )
        : Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 4)),
      child: Image.file(_currentFile),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete Image', onPressed: _deleteImage),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: Center(child: imageWidget)),
          _buildControls(),
        ],
      ),
    );
  }
}
