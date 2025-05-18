import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import '../models/story.dart';

class SharedMap extends StatefulWidget {
  final bool isWidget;
  final Function(Story)? onStoryTap;
  final double initialZoom;
  final bool showControls;
  final List<Story> stories;

  const SharedMap({
    super.key,
    this.isWidget = false,
    this.onStoryTap,
    this.initialZoom = 15.0,
    this.showControls = true,
    required this.stories,
  });

  @override
  State<SharedMap> createState() => _SharedMapState();
}

class _SharedMapState extends State<SharedMap> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  LatLng? _currentPosition;
  static const platform = MethodChannel('com.example.familyverse/widget');

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _updateMarkers();
  }

  @override
  void didUpdateWidget(SharedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stories != widget.stories) {
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers = widget.stories.where((story) => story.latitude != null && story.longitude != null).map((story) {
        return Marker(
          point: LatLng(story.latitude!, story.longitude!),
          width: widget.isWidget ? 20 : 40,
          height: widget.isWidget ? 20 : 40,
          child: GestureDetector(
            onTap: () {
              if (widget.onStoryTap != null) {
                widget.onStoryTap!(story);
              }
            },
            child: Icon(
              Icons.location_pin,
              color: Colors.red,
              size: widget.isWidget ? 20 : 40,
            ),
          ),
        );
      }).toList();

      // Update nearby stories count in widget
      if (_currentPosition != null) {
        final nearbyStories = widget.stories.where((story) {
          if (story.latitude == null || story.longitude == null) return false;
          final storyLocation = LatLng(story.latitude!, story.longitude!);
          final distance = const Distance().distance(_currentPosition!, storyLocation);
          return distance <= 1000; // Within 1km
        }).length;

        platform.invokeMethod('updateNearbyStories', {'count': nearbyStories});
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Center map on current position
      _mapController.move(_currentPosition!, widget.initialZoom);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition!,
            initialZoom: widget.initialZoom,
            interactionOptions: InteractionOptions(
              enableScrollWheel: !widget.isWidget,
              enableMultiFingerGestureRace: !widget.isWidget,
              flags: widget.isWidget ? InteractiveFlag.none : InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.familyverse.app',
            ),
            MarkerLayer(markers: _markers),
          ],
        ),
        if (widget.showControls)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
      ],
    );
  }
} 