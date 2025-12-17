import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'controllers/captcha_controller.dart';
import 'pages/captcha_annotator_page.dart';
import 'pages/manual_captcha_tool_page.dart';
import 'pages/captcha_annotator_v2_page.dart';
import 'pages/captcha_dataset_annotator_v2_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Captcha Annotator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DatasetPathInputPage(),
    );
  }
}

class DatasetPathInputPage extends StatefulWidget {
  const DatasetPathInputPage({super.key});

  @override
  State<DatasetPathInputPage> createState() => _DatasetPathInputPageState();
}

class _DatasetPathInputPageState extends State<DatasetPathInputPage> {
  final _controller = TextEditingController(
    text: '请选择路径',
  );

  Future<void> _pickDirectory() async {
    try {
      print('Opening directory picker...');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      print('Selected directory: $selectedDirectory');

      if (selectedDirectory != null) {
        setState(() {
          _controller.text = selectedDirectory;
        });
        Get.snackbar(
          'Success',
          'Directory selected: $selectedDirectory',
          duration: const Duration(seconds: 2),
        );
      } else {
        print('Directory selection cancelled');
      }
    } catch (e) {
      print('Error picking directory: $e');
      Get.snackbar(
        'Error',
        'Failed to open directory picker: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _navigateToAnnotator() async {
    final path = _controller.text.trim();
    if (path.isEmpty) {
      Get.snackbar('Error', 'Please select or enter dataset path');
      return;
    }

    // Check if directory exists
    final dir = Directory(path);
    if (!await dir.exists()) {
      Get.snackbar('Error', 'Directory does not exist: $path');
      return;
    }

    // Check if required subdirectories exist
    final imagesDir = Directory('$path/images');
    final metadataDir = Directory('$path/metadata');

    if (!await imagesDir.exists() || !await metadataDir.exists()) {
      Get.snackbar(
        'Warning',
        'Required subdirectories (images, metadata) not found. They will be created if needed.',
        duration: const Duration(seconds: 3),
      );
    }

    // Initialize the controller with the dataset path
    Get.put(CaptchaController(datasetPath: path));

    // Navigate to annotator page
    Get.to(() => const CaptchaAnnotatorPage());
  }

  Future<void> _navigateToAnnotatorV2() async {
    final path = _controller.text.trim();
    if (path.isEmpty) {
      Get.snackbar('错误', '请选择或输入数据集路径');
      return;
    }

    // Check if directory exists
    final dir = Directory(path);
    if (!await dir.exists()) {
      Get.snackbar('错误', '目录不存在: $path');
      return;
    }

    // Check if required subdirectories exist
    final imagesDir = Directory('$path/images');
    final metadataDir = Directory('$path/metadata');

    if (!await imagesDir.exists() || !await metadataDir.exists()) {
      Get.snackbar(
        '警告',
        '未找到必需的子目录 (images, metadata)。如需要将自动创建。',
        duration: const Duration(seconds: 3),
      );
    }

    // Navigate to V2 annotator page
    Get.to(() => CaptchaDatasetAnnotatorV2Page(datasetPath: path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captcha Annotator'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Welcome to Captcha Annotator',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter the path to your captcha dataset folder:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _controller,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Dataset Path',
                      hintText: '/path/to/captcha_dataset',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.folder),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _controller.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Dataset Folder'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToAnnotator,
                          icon: const Icon(Icons.edit),
                          label: const Text('V1 标注'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToAnnotatorV2,
                          icon: const Icon(Icons.speed),
                          label: const Text('V2 数据集标注'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            textStyle: const TextStyle(fontSize: 16),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Get.to(() => const ManualCaptchaToolPage());
                    },
                    icon: const Icon(Icons.settings_suggest),
                    label: const Text('Manual Captcha Tool'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.to(() => const CaptchaAnnotatorV2Page());
                    },
                    icon: const Icon(Icons.timelapse),
                    label: const Text('V2 双序列采集器'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dataset Structure:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'captcha_dataset/\n'
                            '├── images/\n'
                            '│   ├── {id}_big.png\n'
                            '│   └── {id}_small.png\n'
                            '└── metadata/\n'
                            '    └── {id}.json',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
