import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service_retrofit.dart';
import '../../services/theme_service.dart';
import '../../models/event_model.dart';
import '../../widgets/cupertino_dropdown.dart';
import '../../widgets/schedule/location_field.dart';
import '../../utils/time_utils.dart';
import '../../mixins/event_form_validation_mixin.dart';

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

class _EventFormScreenState extends State<EventFormScreen> with EventFormValidationMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

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

      // Extract date and time components from the local DateTime
      final localStartAt = widget.event!.startEventAt; // Already converted to local in Event.fromJson
      final localEndAt = widget.event!.endEventAt;     // Already converted to local in Event.fromJson

      _startDate = DateTime(localStartAt.year, localStartAt.month, localStartAt.day);
      _startTime = TimeOfDay.fromDateTime(localStartAt);
      _endDate = DateTime(localEndAt.year, localEndAt.month, localEndAt.day);
      _endTime = TimeOfDay.fromDateTime(localEndAt);

      _selectedType = widget.event!.type;
      _locationAddress = widget.event!.addressLocation ?? '';
      _locationLatLng = null;
    } else {
      // Add mode - initialize with defaults using smart suggestions
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      
      // Set start time to current time + 1 hour, rounded to 15-minute interval
      final oneHourFromNow = DateTime.now().add(const Duration(hours: 1));
      final suggestedStart = TimeUtils.roundTo15MinuteIntervalDateTime(oneHourFromNow);
      final suggestedEnd = suggestEndTimeForStart(suggestedStart);
      
      _startDate = DateTime(suggestedStart.year, suggestedStart.month, suggestedStart.day);
      _startTime = TimeOfDay.fromDateTime(suggestedStart);
      _endDate = DateTime(suggestedEnd.year, suggestedEnd.month, suggestedEnd.day);
      _endTime = TimeOfDay.fromDateTime(suggestedEnd);
      
      _selectedType = 'lg_session';
      _locationAddress = '';
      _locationLatLng = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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

  /// Gets available time slots based on current date constraints
  List<String> _getAvailableTimeSlots() {
    final allSlots = TimeUtils.getTimeSlots();
    
    // If not today, return all slots
    final now = DateTime.now();
    if (_startDate.year != now.year || 
        _startDate.month != now.month || 
        _startDate.day != now.day) {
      return allSlots;
    }
    
    // For today, filter out past times
    final minTime = getMinimumTimeForDate(_startDate, isEditMode: isEditMode);
    if (minTime == null) return allSlots;
    
    return allSlots.where((slot) {
      final time = TimeUtils.parseTimeString(slot);
      if (time == null) return false;
      return time.hour > minTime.hour || 
             (time.hour == minTime.hour && time.minute >= minTime.minute);
    }).toList();
  }

  String _formatEventType(String type) {
    if (type == 'lg_session') {
      return 'LG Session';
    }
    return type[0].toUpperCase() + type.substring(1);
  }


  Future<void> _selectStartDate() async {
    final constraints = getDateConstraints(
      isEditMode: isEditMode,
      originalDate: isEditMode ? widget.event?.startEventAt : null,
    );
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: constraints.start,
      lastDate: constraints.end,
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
      
      // Trigger validation after date change
      validateEventTimes(
        startDateTime: _startDateTime,
        endDateTime: _endDateTime,
        isEditMode: isEditMode,
        originalStartTime: isEditMode ? widget.event?.startEventAt : null,
      );
    }
  }



  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    // Perform final validation before save
    validateEventTimes(
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      isEditMode: isEditMode,
      originalStartTime: isEditMode ? widget.event?.startEventAt : null,
      immediate: true,
    );
    
    if (!canSubmitForm()) {
      return; // Validation errors will be shown by the mixin
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
        
        if (!_startDateTime.isAtSameMomentAs(widget.event!.startEventAt)) {
          eventData['startEventAt'] = _startDateTime.toUtc().toIso8601String();
        }
        
        if (!_endDateTime.isAtSameMomentAs(widget.event!.endEventAt)) {
          eventData['endEventAt'] = _endDateTime.toUtc().toIso8601String();
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
          'id': '',
          'name': _nameController.text.trim(),
          'startEventAt': _startDateTime.toUtc().toIso8601String(),
          'endEventAt': _endDateTime.toUtc().toIso8601String(),
          'addressLocation': _locationAddress ?? '',
          'longLocation': _locationLatLng != null ? _locationLatLng!.longitude.toString() : '',
          'latLocation': _locationLatLng != null ? _locationLatLng!.latitude.toString() : '',
          'description': _descriptionController.text.trim(),
          'isRecurrence': false,
          'type': _selectedType,
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
                    LocationField(
                      initialAddress: _locationAddress,
                      initialLatLng: _locationLatLng,
                      onLocationChanged: (address, latLng) {
                        setState(() {
                          _locationAddress = address;
                          _locationLatLng = latLng;
                        });
                      },
                      isReadOnly: widget.isReadOnly,
                      themeService: themeService,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description (Optional)',
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
        TextFormField(
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
              isDense: true,
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
                items: _getAvailableTimeSlots(),
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
                      
                      // Trigger validation (no auto-correction needed since dropdown has valid 15-min intervals)
                      validateEventTimes(
                        startDateTime: _startDateTime,
                        endDateTime: _endDateTime,
                        isEditMode: isEditMode,
                        originalStartTime: isEditMode ? widget.event?.startEventAt : null,
                      );
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
                items: _getAvailableTimeSlots(),
                hintText: 'Select time',
                onChanged: widget.isReadOnly ? null : (value) {
                  if (value != null) {
                    final newTime = TimeUtils.parseTimeString(value);
                    if (newTime != null) {
                      setState(() {
                        _endTime = newTime;
                      });
                      
                      // Trigger validation (no auto-correction needed since dropdown has valid 15-min intervals)
                      validateEventTimes(
                        startDateTime: _startDateTime,
                        endDateTime: _endDateTime,
                        isEditMode: isEditMode,
                        originalStartTime: isEditMode ? widget.event?.startEventAt : null,
                      );
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

}