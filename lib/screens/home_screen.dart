import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'editor_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  Box? box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('images');
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 90);
    if (file != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(File(file.path))),
      ).then((_) => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = box!.values.toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Editor'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
            ],
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No saved images yet.'))
                : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: items.length,
              itemBuilder: (_, idx) {
                final entry = items[idx] as Map;
                final path = entry['path'] as String?;
                final title = entry['title'] as String? ?? '';
                return GestureDetector(
                  onTap: () {
                    if (path != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: Text(title.isEmpty ? 'Saved' : title)),
                            body: Center(child: Image.file(File(path))),
                          ),
                        ),
                      );
                    }
                  },
                  child: path != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  )
                      : Container(color: Colors.grey[200]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
