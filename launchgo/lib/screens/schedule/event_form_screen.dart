import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/api_service_retrofit.dart';
import '../../services/theme_service.dart';
import '../../models/event_model.dart';
import '../../widgets/cupertino_dropdown.dart';
import '../../utils/time_utils.dart';
import 'location_edit_screen.dart'; // Added import for LocationEditScreen
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class EventFormScreen extends StatefulWidget {
  final Event? event;
  final bool isReadOnly;

  const EventFormScreen({
    super.key,
    this.event,
    this.isReadOnly = false,
  });

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  late String _selectedType;
  bool _isLoading = false;
  bool _isLocationLoading = false;

  String? _locationAddress;
  LatLng? _locationLatLng;

  final List<String> _eventTypes = [
    'lg_session',
    'goal',
    'work',
    'social',
    'class',
    'homework',
    'study',
    'extracurricular',
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.event != null) {
      // Edit mode - initialize with existing event data
      _nameController = TextEditingController(text: widget.event!.name);
      _descriptionController = TextEditingController(text: widget.event!.description ?? '');
      _locationController = TextEditingController(text: widget.event!.addressLocation ?? '');
      
      // Extract date and time components from the local DateTime
      final localStartAt = widget.event!.startAt; // Already converted to local in Event.fromJson
      final localEndAt = widget.event!.endAt;     // Already converted to local in Event.fromJson
      
      _startDate = DateTime(localStartAt.year, localStartAt.month, localStartAt.day);
      _startTime = TimeOfDay.fromDateTime(localStartAt);
      _endDate = DateTime(localEndAt.year, localEndAt.month, localEndAt.day);
      _endTime = TimeOfDay.fromDateTime(localEndAt);
      
      _selectedType = widget.event!.type;
      _locationAddress = widget.event!.addressLocation ?? '';
      _locationLatLng = null;
    } else {
      // Add mode - initialize with defaults
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      
      _startDate = DateTime.now();
      _startTime = const TimeOfDay(hour: 12, minute: 0); // 12:00 PM
      _endDate = DateTime.now();
      _endTime = const TimeOfDay(hour: 12, minute: 0); // 12:00 PM
      
      _selectedType = 'lg_session';
      _locationAddress = '';
      _locationLatLng = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get isEditMode => widget.event != null;

  DateTime get _startDateTime {
    return DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
  }

  DateTime get _endDateTime {
    return DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
  }

  String _formatEventType(String type) {
    if (type == 'lg_session') {
      return 'LG Session';
    }
    return type[0].toUpperCase() + type.substring(1);
  }


  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: isEditMode 
          ? _startDate.isBefore(DateTime.now()) 
              ? _startDate 
              : DateTime.now()
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2332),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }



  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDateTime.isBefore(_startDateTime) || _endDateTime.isAtSameMomentAs(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = context.read<ApiServiceRetrofit>();
      
      if (isEditMode) {
        // Update existing event
        final eventData = <String, dynamic>{};
        
        if (_nameController.text.trim() != widget.event!.name) {
          eventData['name'] = _nameController.text.trim();
        }
        
        if (_descriptionController.text.trim() != (widget.event!.description ?? '')) {
          eventData['description'] = _descriptionController.text.trim();
        }
        
        if (_locationAddress != (widget.event!.addressLocation ?? '')) {
          eventData['addressLocation'] = _locationAddress;
        }
        eventData['latLocation'] = _locationLatLng != null ? _locationLatLng!.latitude.toString() : '';
        eventData['longLocation'] = _locationLatLng != null ? _locationLatLng!.longitude.toString() : '';
        
        if (_selectedType != widget.event!.type) {
          eventData['type'] = _selectedType;
        }
        
        if (!_startDateTime.isAtSameMomentAs(widget.event!.startAt)) {
          eventData['startAt'] = _startDateTime.toUtc().toIso8601String();
        }
        
        if (!_endDateTime.isAtSameMomentAs(widget.event!.endAt)) {
          eventData['endAt'] = _endDateTime.toUtc().toIso8601String();
        }

        if (eventData.isEmpty) {
          Navigator.of(context).pop(false);
          return;
        }

        final result = await apiService.updateEvent(widget.event!.id, eventData);
        
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Create new event
        final eventData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'addressLocation': _locationAddress ?? '',
          'latLocation': _locationLatLng != null ? _locationLatLng!.latitude.toString() : '',
          'longLocation': _locationLatLng != null ? _locationLatLng!.longitude.toString() : '',
          'type': _selectedType,
          'startAt': _startDateTime.toUtc().toIso8601String(),
          'endAt': _endDateTime.toUtc().toIso8601String(),
        };

        final result = await apiService.createEvent(eventData);
        
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isEditMode ? 'update' : 'create'} event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeService.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isReadOnly ? 'Event Details' : (isEditMode ? 'Edit Event' : 'Add Event'),
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: themeService.textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Event Name',
                      hint: 'Enter event name',
                      isRequired: true,
                      themeService: themeService,
                      readOnly: widget.isReadOnly,
                    ),
                    const SizedBox(height: 20),
                    _buildDateSection(themeService),
                    const SizedBox(height: 20),
                    _buildTimeSection(themeService),
                    const SizedBox(height: 20),
                    _buildTypeDropdown(),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: TextStyle(
                            color: themeService.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: (widget.isReadOnly || _isLocationLoading) ? null : () => _openLocationEditScreen(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: themeService.cardColor,
                              border: Border.all(color: themeService.borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _locationAddress?.isNotEmpty == true ? _locationAddress! : 'Enter event location',
                                    style: TextStyle(
                                      color: _locationAddress?.isNotEmpty == true ? themeService.textColor : themeService.inputPlaceholderColor,
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
                                        color: themeService.textColor,
                                      ),
                                    )
                                  : Icon(
                                      _locationAddress?.isNotEmpty == true ? Icons.edit_location_alt : Icons.add_location_alt,
                                      color: themeService.textColor,
                                    )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Enter event description',
                      maxLines: 3,
                      themeService: themeService,
                      readOnly: widget.isReadOnly,
                    ),
                    const SizedBox(height: 20), // Add some bottom padding
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1419),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: widget.isReadOnly ? const SizedBox.shrink() : SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1F2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Color(0xFF1A1F2B),
                          strokeWidth: 2,
                        )
                      : Text(
                          isEditMode ? 'Update Event' : 'Add Event',
                          style: const TextStyle(
                            color: Color(0xFF1A1F2B),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ThemeService themeService,
    bool isRequired = false,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: maxLines == 1 ? 42 : null,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            enabled: !readOnly,
            style: TextStyle(color: themeService.textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: themeService.inputPlaceholderColor),
              filled: true,
              fillColor: themeService.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeService.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeService.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$label is required';
                  }
                  return null;
                }
              : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoDropdown(
          value: _formatEventType(_selectedType),
          items: _eventTypes.map((type) => _formatEventType(type)).toList(),
          hintText: 'Select event type',
          onChanged: widget.isReadOnly ? null : (value) {
            if (value != null) {
              final index = _eventTypes.indexWhere((type) => 
                _formatEventType(type) == value
              );
              if (index != -1) {
                setState(() {
                  _selectedType = _eventTypes[index];
                });
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildDateSection(ThemeService themeService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: widget.isReadOnly ? null : _selectStartDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            decoration: BoxDecoration(
              color: themeService.cardColor,
              border: Border.all(color: themeService.borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('MM/dd/yyyy').format(_startDate),
                  style: TextStyle(color: themeService.textColor, fontSize: 16),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today,
                  color: themeService.inputPlaceholderColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSection(ThemeService themeService) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start Time',
                style: TextStyle(
                  color: themeService.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoDropdown(
                value: TimeUtils.formatTimeForDropdown(_startTime),
                items: TimeUtils.getTimeSlots(),
                hintText: 'Select time',
                onChanged: widget.isReadOnly ? null : (value) {
                  if (value != null) {
                    final newTime = TimeUtils.parseTimeString(value);
                    if (newTime != null) {
                      setState(() {
                        _startTime = newTime;
                        // Auto-adjust end time if needed
                        if (_endDate.isAtSameMomentAs(_startDate) && 
                            (_endTime.hour < _startTime.hour || 
                             (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute))) {
                          _endTime = TimeOfDay(
                            hour: _startTime.hour + 1 > 23 ? 23 : _startTime.hour + 1,
                            minute: _startTime.minute,
                          );
                        }
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'End Time',
                style: TextStyle(
                  color: themeService.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoDropdown(
                value: TimeUtils.formatTimeForDropdown(_endTime),
                items: TimeUtils.getTimeSlots(),
                hintText: 'Select time',
                onChanged: widget.isReadOnly ? null : (value) {
                  if (value != null) {
                    final newTime = TimeUtils.parseTimeString(value);
                    if (newTime != null) {
                      setState(() {
                        _endTime = newTime;
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openLocationEditScreen(BuildContext screenContext) async {
    // Prevent multiple simultaneous navigation attempts
    if (_isLocationLoading) return;
    
    setState(() {
      _isLocationLoading = true;
    });

    try {
      String? suggestAddress;
      LatLng? suggestCoords;

      // Check location permissions first - deny navigation if no permission
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      var status = await Permission.locationWhenInUse.status;
      
      if (status.isDenied) {
        status = await Permission.locationWhenInUse.request();
      }

      // Handle all permission issues in one place
      if (!servicesEnabled || status.isPermanentlyDenied || status.isRestricted || status.isDenied) {
        if (!mounted) return;
        
        String message;
        bool openLocationSettings = false;
        
        if (!servicesEnabled) {
          message = 'Location services are required to use the location feature. Enable them in Settings to continue.';
          openLocationSettings = true;
        } else {
          message = 'Location permission is required to use the location feature. Enable it in Settings to continue.';
        }
        
        final shouldOpenSettings = await _showLocationPermissionDialog(message);
        if (shouldOpenSettings) {
          if (openLocationSettings) {
            await Geolocator.openLocationSettings();
          } else {
            await openAppSettings();
          }
        }
        return; // Don't navigate if any permission issue
      }

      // Only proceed if permission is granted
      if (status.isGranted) {
        // Try to get current location
        try {
          Position pos = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 5),
          );
          suggestCoords = LatLng(pos.latitude, pos.longitude);
          List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
            pos.latitude, 
            pos.longitude
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final address = [
              if (place.street != null) place.street,
              if (place.subLocality != null) place.subLocality,
              if (place.locality != null) place.locality,
              if (place.administrativeArea != null) place.administrativeArea,
              if (place.country != null) place.country,
            ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
            suggestAddress = address;
          }
        } catch (e) {
          // Location getting failed - continue with navigation
        }
      }

      if (!mounted) return;
      
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
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }


  Future<bool> _showLocationPermissionDialog(String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          title: const Text(
            'Location Permission',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Go to Settings',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> _showLocationPermissionDeniedDialog(BuildContext dialogContext) async {
    return await showDialog<bool>(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location access is permanently denied. To enable automatic location suggestions, please go to Settings and enable location permission for this app.\n\nYou can still manually enter addresses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Go to Settings'),
            ),
          ],
        );
      },
    ) ?? false;
  }
}