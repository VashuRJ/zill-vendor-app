import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';

/// Zomato-style pin-drop location picker using OpenStreetMap (free).
/// Returns [LatLng] via Navigator.pop when user confirms.
class LocationPickerScreen extends StatefulWidget {
  /// Initial position — uses existing restaurant coordinates or a default.
  final LatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static final _defaultPosition = LatLng(28.6139, 77.2090); // New Delhi
  late LatLng _center;
  final MapController _mapController = MapController();
  bool _loadingLocation = false;
  String _addressHint = 'Move the map to set location';

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition ?? _defaultPosition;
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _loadingLocation = true);

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showSnack('Location services are disabled. Please enable GPS.');
        setState(() => _loadingLocation = false);
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _showSnack('Location permission denied. You can still drag the map.');
          setState(() => _loadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnack('Location permission permanently denied. Enable in Settings.');
        }
        setState(() => _loadingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() => _center = newCenter);

      _mapController.move(newCenter, 17);
    } catch (e) {
      if (mounted) _showSnack('Could not get location. Drag the map manually.');
    }

    if (mounted) setState(() => _loadingLocation = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (position.center != null) {
      _center = position.center!;
    }
  }

  void _onMapEvent(MapEvent event) {
    // Update coordinate display when map stops moving
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      setState(() {
        _addressHint =
            '${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Restaurant Location'),
      ),
      body: Stack(
        children: [
          // ── OpenStreetMap ──────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initialPosition != null ? 17 : 12,
              onPositionChanged: _onPositionChanged,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.zill.vendor_app',
              ),
            ],
          ),

          // ── Center Pin (fixed, Zomato style) ────────────────────
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_on,
                size: 48,
                color: AppColors.error,
              ),
            ),
          ),

          // ── Pin shadow dot ──────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Top instruction ─────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _addressHint,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Current Location FAB ────────────────────────────────
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'currentLocation',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _loadingLocation ? null : _goToCurrentLocation,
              child: _loadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 22,
                    ),
            ),
          ),

          // ── Confirm Button ──────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _center),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'Confirm Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
