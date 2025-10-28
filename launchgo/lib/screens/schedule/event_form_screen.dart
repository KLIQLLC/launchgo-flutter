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

  const EventFormScreen({
    super.key,
    this.event,
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
      _locationController = TextEditingController(text: widget.event!.location ?? '');
      
      // Extract date and time components from the local DateTime
      final localStartAt = widget.event!.startAt; // Already converted to local in Event.fromJson
      final localEndAt = widget.event!.endAt;     // Already converted to local in Event.fromJson
      
      _startDate = DateTime(localStartAt.year, localStartAt.month, localStartAt.day);
      _startTime = TimeOfDay.fromDateTime(localStartAt);
      _endDate = DateTime(localEndAt.year, localEndAt.month, localEndAt.day);
      _endTime = TimeOfDay.fromDateTime(localEndAt);
      
      _selectedType = widget.event!.type;
      _locationAddress = widget.event!.location ?? '';
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
        
        if (_locationAddress != (widget.event!.location ?? '')) {
          eventData['addressLocation'] = _locationAddress;
        }
        eventData['latLocation'] = _locationLatLng?.latitude;
        eventData['longLocation'] = _locationLatLng?.longitude;
        
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
          'latLocation': _locationLatLng?.latitude,
          'longLocation': _locationLatLng?.longitude,
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
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        title: Text(
          isEditMode ? 'Edit Event' : 'Add Event',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
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
                    ),
                    const SizedBox(height: 20),
                    _buildDateSection(),
                    const SizedBox(height: 20),
                    _buildTimeSection(),
                    const SizedBox(height: 20),
                    _buildTypeDropdown(),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openLocationEditScreen(context),
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2332),
                              border: Border.all(color: Colors.grey[600]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _locationAddress?.isNotEmpty == true ? _locationAddress! : 'Enter event locationn',
                                    style: TextStyle(
                                      color: _locationAddress?.isNotEmpty == true ? Colors.white : Colors.white54,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  _locationAddress?.isNotEmpty == true ? Icons.edit_location_alt : Icons.add_location_alt,
                                  color: Colors.white,
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
            child: SafeArea(
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
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: themeService.inputPlaceholderColor),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
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
          onChanged: (value) {
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

  Widget _buildDateSection() {
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
          onTap: _selectStartDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              border: Border.all(color: Colors.grey[600]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('MM/dd/yyyy').format(_startDate),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoDropdown(
                value: TimeUtils.formatTimeForDropdown(_startTime),
                items: TimeUtils.getTimeSlots(),
                hintText: 'Select time',
                onChanged: (value) {
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
              const Text(
                'End Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoDropdown(
                value: TimeUtils.formatTimeForDropdown(_endTime),
                items: TimeUtils.getTimeSlots(),
                hintText: 'Select time',
                onChanged: (value) {
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

  void _openLocationEditScreen(BuildContext context) async {
    String? suggestAddress;
    LatLng? suggestCoords;

    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position pos = await Geolocator.getCurrentPosition();
        suggestCoords = LatLng(pos.latitude, pos.longitude);
        List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
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
        // fallback: не удалось определить координаты/адрес
      }
    }
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationEditScreen(
          initialLocation: suggestAddress ?? _locationAddress ?? '',
          initialCoords: suggestCoords ?? _locationLatLng,
        ),
      ),
    );
    if (result is Map && result['address'] is String) {
      setState(() {
        _locationAddress = result['address'] ?? '';
        if (result['lat'] is double && result['lng'] is double) {
          _locationLatLng = LatLng(result['lat'], result['lng']);
        } else {
          _locationLatLng = null;
        }
      });
    }
  }
}