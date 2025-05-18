import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../services/animation_service.dart';
import '../models/story.dart';
import 'dart:io';

class AnimationScreen extends StatefulWidget {
  final Story story;

  const AnimationScreen({super.key, required this.story});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> {
  VideoPlayerController? _controller;
  AudioPlayer? _audioPlayer;
  bool _isLoading = true;
  String? _error;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _generateAnimation();
  }

  Future<void> _generateAnimation() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _isInitialized = false;
      });

      final animationService = AnimationService();
      final result = await animationService.generateAnimation(widget.story);
      
      // Initialize video player
      _controller = VideoPlayerController.file(File(result['video']!));
      
      // Initialize audio player
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setFilePath(result['audio']!);
      
      // Wait for video to initialize
      await _controller!.initialize();
      
      // Add listener to sync audio with video
      _controller!.addListener(_syncAudioWithVideo);
      
      // Start both video and audio together
      await Future.wait([
        _controller!.play(),
        _audioPlayer!.play(),
      ]);

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _syncAudioWithVideo() {
    if (_controller == null || _audioPlayer == null) return;
    
    // Sync audio position with video
    final videoPosition = _controller!.value.position;
    final audioPosition = _audioPlayer!.position;
    
    // If difference is more than 100ms, sync them
    if ((videoPosition - audioPosition).abs() > const Duration(milliseconds: 100)) {
      _audioPlayer!.seek(videoPosition);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncAudioWithVideo);
    _controller?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animation Preview'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Text('Error: $_error')
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () async {
                              setState(() {});
                              if (_controller!.value.isPlaying) {
                                await Future.wait([
                                  _controller!.pause(),
                                  _audioPlayer!.pause(),
                                ]);
                              } else {
                                await Future.wait([
                                  _controller!.play(),
                                  _audioPlayer!.play(),
                                ]);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.replay),
                            onPressed: () async {
                              await Future.wait([
                                _controller!.seekTo(Duration.zero),
                                _audioPlayer!.seek(Duration.zero),
                              ]);
                              await Future.wait([
                                _controller!.play(),
                                _audioPlayer!.play(),
                              ]);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
} 