import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../models/story.dart';
import '../services/comic_generator_service.dart';
import 'dart:io';
import 'story_detail_screen.dart';
import 'package:flutter/services.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _frontController;
  CameraController? _backController;
  bool _isInitialized = false;
  bool _isFrontCameraInitialized = false;
  bool _isBackCameraInitialized = false;
  bool _isFrontCameraActive = false;
  final _promptController = TextEditingController();
  ComicStyle _selectedStyle = ComicStyle.marvel;
  bool _isExpanded = false;
  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _showBeRealCountdown = false;
  int _countdownValue = 3;
  String _processingMessage = '';
  final _comicGenerator = ComicGeneratorService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameras();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _disposeCameras();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameras();
    }
  }

  Future<void> _initializeCameras() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Initialize front camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _frontController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Initialize back camera
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _backController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _frontController?.initialize();
      if (mounted) {
        setState(() {
          _isFrontCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing front camera: $e');
    }

    try {
      await _backController?.initialize();
      if (mounted) {
        setState(() {
          _isBackCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing back camera: $e');
    }

    if (_isFrontCameraInitialized && _isBackCameraInitialized && mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCameras();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _disposeCameras() async {
    try {
      await _frontController?.dispose();
      await _backController?.dispose();
    } catch (e) {
      debugPrint('Error disposing cameras: $e');
    }
  }

  Future<void> _handleBeRealCapture() async {
    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
      _showBeRealCountdown = true;
      _countdownValue = 3;
      _isFrontCameraActive = false;  // Start with back camera
    });

    // Start countdown
    for (int i = 3; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _countdownValue = i - 1;
      });
    }

    setState(() {
      _showBeRealCountdown = false;
    });

    try {
      // Ensure back camera is ready
      if (!_isBackCameraInitialized || _backController == null) {
        throw Exception('Back camera not initialized');
      }

      // Capture back camera first
      if (!mounted) return;
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Capturing back camera...';
      });

      final XFile? backImage = await _backController!.takePicture();
      if (backImage == null) {
        throw Exception('Failed to capture back camera image');
      }

      // Switch to front camera
      setState(() {
        _processingMessage = 'Switching to front camera...';
        _isFrontCameraActive = true;
      });

      // Wait for front camera to be ready
      if (!_isFrontCameraInitialized || _frontController == null) {
        throw Exception('Front camera not initialized');
      }

      // Wait longer for camera to stabilize
      await Future.delayed(const Duration(seconds: 2));

      // Additional check to ensure front camera is ready
      if (!_frontController!.value.isInitialized) {
        throw Exception('Front camera not ready');
      }

      // Update processing message
      if (!mounted) return;
      setState(() {
        _processingMessage = 'Capturing front camera...';
      });

      // Take front camera picture
      final XFile? frontImage = await _frontController!.takePicture();
      if (frontImage == null) {
        throw Exception('Failed to capture front camera image');
      }

      // Notify widget that pictures were taken
      const platform = MethodChannel('com.example.familyverse/widget');
      await platform.invokeMethod('pictureTaken');

      // Switch back to back camera
      setState(() {
        _isFrontCameraActive = false;
        _isProcessing = false;
        _processingMessage = '';
      });

      // Wait longer for camera to switch back
      await Future.delayed(const Duration(seconds: 1));

      // Show preview dialog with both images
      final bool? proceed = await _showPreviewDialog(frontImage, backImage);
      if (proceed == true && mounted) {
        setState(() {
          _isProcessing = true;
          _processingMessage = 'Generating comic...';
        });

        // Generate comic
        final story = await _comicGenerator.generateComic(
          images: [File(backImage.path), File(frontImage.path)],
          style: _selectedStyle,
          prompt: _promptController.text.isEmpty ? null : _promptController.text,
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(story: story),
          ),
        );
      }

    } catch (e) {
      print('Error during BeReal capture: $e');
      if (!mounted) return;
      setState(() {
        _isFrontCameraActive = false;
        _isProcessing = false;
        _processingMessage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<bool> _showPreviewDialog(XFile frontImage, XFile backImage) async {
    final TextEditingController promptController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Your Comic'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your comic will be generated with:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Front Camera'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(frontImage.path),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Back Camera'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(backImage.path),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Style: ${_selectedStyle.toString().split('.').last}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add your idea for the comic:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: promptController,
                      decoration: InputDecoration(
                        hintText: 'Enter your idea for the comic...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _promptController.text = promptController.text;
              Navigator.of(context).pop(true);
            },
            child: const Text('Generate Comic'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _isFrontCameraActive 
                ? _frontController!.value.aspectRatio 
                : _backController!.value.aspectRatio,
              child: CameraPreview(
                _isFrontCameraActive ? _frontController! : _backController!
              ),
            ),
          ),

          // BeReal countdown overlay
          if (_showBeRealCountdown)
            Container(
              color: Colors.black54,
              child: Center(
                child: Text(
                  _countdownValue.toString(),
                  style: const TextStyle(
                    fontSize: 72,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _processingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Camera controls
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // BeReal button
                FloatingActionButton(
                  onPressed: _isCapturing ? null : _handleBeRealCapture,
                  backgroundColor: _isCapturing ? Colors.grey : Colors.blue,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 