import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../../services/theme_service.dart';
import '../../screens/schedule/location_edit_screen.dart';

/// Reusable location field widget for event forms
/// Handles location selection with map interface and permission management
class LocationField extends StatefulWidget {
  final String? initialAddress;
  final LatLng? initialLatLng;
  final Function(String? address, LatLng? latLng) onLocationChanged;
  final bool isReadOnly;
  final ThemeService themeService;

  const LocationField({
    super.key,
    this.initialAddress,
    this.initialLatLng,
    required this.onLocationChanged,
    this.isReadOnly = false,
    required this.themeService,
  });

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  bool _isLocationLoading = false;
  String? _locationAddress;
  LatLng? _locationLatLng;

  @override
  void initState() {
    super.initState();
    _locationAddress = widget.initialAddress;
    _locationLatLng = widget.initialLatLng;
  }

  @override
  void didUpdateWidget(LocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state if parent provides new values
    if (widget.initialAddress != oldWidget.initialAddress ||
        widget.initialLatLng != oldWidget.initialLatLng) {
      setState(() {
        _locationAddress = widget.initialAddress;
        _locationLatLng = widget.initialLatLng;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: TextStyle(
            color: widget.themeService.textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (widget.isReadOnly || _isLocationLoading)
              ? null
              : () => _openLocationEditScreen(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.themeService.cardColor,
              border: Border.all(color: widget.themeService.borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _locationAddress?.isNotEmpty == true
                        ? _locationAddress!
                        : 'Enter event location',
                    style: TextStyle(
                      color: _locationAddress?.isNotEmpty == true
                          ? widget.themeService.textColor
                          : widget.themeService.inputPlaceholderColor,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _isLocationLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.themeService.textColor,
                        ),
                      )
                    : Icon(
                        _locationAddress?.isNotEmpty == true
                            ? Icons.edit_location_alt
                            : Icons.add_location_alt,
                        color: widget.themeService.textColor,
                      )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Location Handling

  Future<void> _openLocationEditScreen(BuildContext context) async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      // Location services are disabled
      _showLocationPermissionDialog(
        context,
        'Location Services Disabled',
        'Please enable location services in your device settings to use this feature.',
      );
      return;
    }

    // Check location permission
    var status = await Permission.location.status;

    if (status.isDenied) {
      // Request permission
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied && mounted) {
      // Permission permanently denied
      _showLocationPermissionDialog(
        context,
        'Location Permission Required',
        'Location permission is permanently denied. Please enable it in app settings.',
      );
      return;
    }

    if (!status.isGranted) {
      // Permission denied
      if (mounted) {
        _showLocationPermissionDialog(
          context,
          'Location Permission Required',
          'Location permission is required to use this feature.',
        );
      }
      return;
    }

    // Permission granted, get current location
    setState(() {
      _isLocationLoading = true;
    });

    // Get suggested address from current position
    String? suggestAddress;
    LatLng? suggestCoords;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final address = [
            if (place.street != null) place.street,
            if (place.locality != null) place.locality,
            if (place.administrativeArea != null) place.administrativeArea,
            if (place.country != null) place.country,
          ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
          suggestAddress = address;
          suggestCoords = LatLng(position.latitude, position.longitude);
        }
      } catch (e) {
        // Geocoding failed - continue with navigation
      }
    } catch (e) {
      // Location getting failed - continue with navigation anyway
    }

    if (!mounted) return;

    // Navigate to location edit screen (always navigate, even if location fetch failed)
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LocationEditScreen(
            initialLocation: suggestAddress ?? _locationAddress ?? '',
            initialCoords: suggestCoords ?? _locationLatLng,
          ),
        ),
      );

      if (result is Map && result['address'] is String && mounted) {
        setState(() {
          _locationAddress = result['address'] ?? '';
          if (result['lat'] is double && result['lng'] is double) {
            _locationLatLng = LatLng(result['lat'], result['lng']);
          } else {
            _locationLatLng = null;
          }
        });

        // Notify parent
        widget.onLocationChanged(_locationAddress, _locationLatLng);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  void _showLocationPermissionDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
