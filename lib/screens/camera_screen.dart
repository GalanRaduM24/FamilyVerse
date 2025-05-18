import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../models/story.dart';
import '../services/comic_generator_service.dart';
import '../services/story_service.dart';
import 'dart:io';
import 'story_detail_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitialized = false;
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
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameras();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameras();
    }
  }

  Future<void> _initializeCameras() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    // Start with back camera
    await _switchCamera(false);
  }

  Future<void> _disposeCamera() async {
    try {
      if (_cameraController != null) {
        await _cameraController!.stopImageStream();
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }
  }

  Future<void> _switchCamera(bool toFront) async {
    if (toFront == _isFrontCameraActive && _cameraController != null) return;

    // Dispose current camera
    await _disposeCamera();

    if (_cameras == null || _cameras!.isEmpty) return;

    // Get the appropriate camera
    final camera = _cameras!.firstWhere(
      (camera) => toFront 
        ? camera.lensDirection == CameraLensDirection.front
        : camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    // Initialize new camera
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isFrontCameraActive = toFront;
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _handleBeRealCapture() async {
    if (_isCapturing || !_isInitialized || _cameraController == null) return;
    setState(() {
      _isCapturing = true;
      _showBeRealCountdown = true;
      _countdownValue = 3;
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
      // Ensure we start with back camera
      await _switchCamera(false);

      // Capture back camera first
      if (!mounted) return;
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Capturing back camera...';
      });

      final XFile? backImage = await _cameraController!.takePicture();
      if (backImage == null) {
        throw Exception('Failed to capture back camera image');
      }

      // Switch to front camera
      setState(() {
        _processingMessage = 'Switching to front camera...';
      });
      await _switchCamera(true);

      // Wait for front camera to be ready
      await Future.delayed(const Duration(seconds: 2));

      // Update processing message
      if (!mounted) return;
      setState(() {
        _processingMessage = 'Capturing front camera...';
      });

      // Take front camera picture
      final XFile? frontImage = await _cameraController!.takePicture();
      if (frontImage == null) {
        throw Exception('Failed to capture front camera image');
      }

      // Update last picture date and notify widget
      final storyService = Provider.of<StoryService>(context, listen: false);
      await storyService.updateLastPictureDate();

      // Switch back to back camera
      setState(() {
        _isProcessing = false;
        _processingMessage = '';
      });
      await _switchCamera(false);

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
        
        // Dispose camera before navigating
        await _disposeCamera();
        
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _promptController.dispose();
    super.dispose();
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
    if (!_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
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
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          // Style selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ComicStyle>(
                  value: _selectedStyle,
                  dropdownColor: Colors.black.withOpacity(0.8),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  style: const TextStyle(color: Colors.white),
                  items: ComicStyle.values.map((style) {
                    return DropdownMenuItem(
                      value: style,
                      child: Text(
                        style.toString().split('.').last,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStyle = value;
                      });
                    }
                  },
                ),
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
                  onPressed: _isCapturing || !_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized 
                    ? null 
                    : _handleBeRealCapture,
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