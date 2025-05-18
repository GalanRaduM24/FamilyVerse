import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/animation_service.dart';
import '../models/story.dart';

class AnimationScreen extends StatefulWidget {
  final Story story;

  const AnimationScreen({super.key, required this.story});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  bool _isGenerating = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _generateAnimation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _generateAnimation() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _error = null;
      _progress = 0.0;
    });

    try {
      final animationService = AnimationService();
      final videoUrl = await animationService.generateAnimation(widget.story);

      if (!mounted) return;

      // Initialize video controller
      _controller = VideoPlayerController.network(videoUrl)
        ..addListener(() {
          if (mounted) setState(() {});
        })
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isGenerating = false;
            });
            _controller?.play();
          }
        });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Animation'),
        actions: [
          if (!_isGenerating)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _generateAnimation,
              tooltip: 'Regenerate Animation',
            ),
        ],
      ),
      body: Center(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isGenerating) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Generating animation...\nThis may take a few minutes.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (_progress > 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LinearProgressIndicator(value: _progress),
            ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Error: $_error',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.red,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _generateAnimation,
            child: const Text('Try Again'),
          ),
        ],
      );
    }

    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Text('Failed to load video');
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        const SizedBox(height: 16),
        _buildVideoControls(),
      ],
    );
  }

  Widget _buildVideoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            _controller?.value.isPlaying ?? false
                ? Icons.pause
                : Icons.play_arrow,
          ),
          onPressed: () {
            setState(() {
              if (_controller?.value.isPlaying ?? false) {
                _controller?.pause();
              } else {
                _controller?.play();
              }
            });
          },
        ),
        ValueListenableBuilder(
          valueListenable: _controller!,
          builder: (context, VideoPlayerValue value, child) {
            return Expanded(
              child: Slider(
                value: value.position.inMilliseconds.toDouble(),
                min: 0,
                max: value.duration.inMilliseconds.toDouble(),
                onChanged: (newValue) {
                  _controller?.seekTo(
                    Duration(milliseconds: newValue.toInt()),
                  );
                },
              ),
            );
          },
        ),
        Text(
          '${_formatDuration(_controller?.value.position ?? Duration.zero)} / '
          '${_formatDuration(_controller?.value.duration ?? Duration.zero)}',
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 