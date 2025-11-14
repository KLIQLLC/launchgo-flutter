import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/api_service_retrofit.dart';
import '../../services/theme_service.dart';
import '../../widgets/cupertino_dropdown.dart';
import '../../utils/time_utils.dart';
import '../../utils/recurrence_utils.dart';
import '../../models/event_model.dart';
import '../../mixins/event_form_validation_mixin.dart';
import '../../services/event_validation_service.dart';

class RecurringEventFormScreen extends StatefulWidget {
  final Event? event;
  final bool isReadOnly;

  const RecurringEventFormScreen({
    super.key,
    this.event,
    this.isReadOnly = false,
  });

  @override
  State<RecurringEventFormScreen> createState() => _RecurringEventFormScreenState();
}

class _RecurringEventFormScreenState extends State<RecurringEventFormScreen> with EventFormValidationMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late DateTime _recurrenceEndDate;

  String _selectedType = 'study';
  String _recurrenceType = 'every-day';
  bool _isLoading = false;

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
      final localStartAt = widget.event!.startEventAt;
      final localEndAt = widget.event!.endEventAt;
      
      _selectedDate = DateTime(localStartAt.year, localStartAt.month, localStartAt.day);
      _startTime = TimeOfDay.fromDateTime(localStartAt);
      _endTime = TimeOfDay.fromDateTime(localEndAt);
      
      _selectedType = widget.event!.type;
      _recurrenceType = widget.event!.recurrenceType ?? 'every-day';
      _recurrenceEndDate = widget.event!.endRecurrenceAt ?? DateTime.now().add(const Duration(days: 30));
    } else {
      // Add mode - initialize with defaults using smart suggestions
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      
      final suggestedStart = suggestNextValidDateTime();
      final suggestedEnd = suggestEndTimeForStart(suggestedStart);
      
      _selectedDate = DateTime(suggestedStart.year, suggestedStart.month, suggestedStart.day);
      _startTime = TimeOfDay.fromDateTime(suggestedStart);
      _endTime = TimeOfDay.fromDateTime(suggestedEnd);
      _recurrenceEndDate = EventValidationService.suggestRecurrenceEndDate(suggestedStart);
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

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  DateTime get _startDateTime => _combineDateAndTime(_selectedDate, _startTime);
  DateTime get _endDateTime => _combineDateAndTime(_selectedDate, _endTime);

  /// Gets available time slots based on current date constraints
  List<String> _getAvailableTimeSlots() {
    final allSlots = TimeUtils.getTimeSlots();
    
    // If not today, return all slots
    final now = DateTime.now();
    if (_selectedDate.year != now.year || 
        _selectedDate.month != now.month || 
        _selectedDate.day != now.day) {
      return allSlots;
    }
    
    // For today, filter out past times
    final minTime = getMinimumTimeForDate(_selectedDate, isEditMode: isEditMode);
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



  Future<void> _selectDate() async {
    final constraints = getDateConstraints(
      isEditMode: isEditMode,
      originalDate: isEditMode ? widget.event?.startEventAt : null,
    );
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
        _selectedDate = picked;
        if (_recurrenceEndDate.isBefore(_selectedDate)) {
          _recurrenceEndDate = _selectedDate.add(const Duration(days: 30));
        }
      });
      
      // Trigger validation after date change (no auto-correction needed with valid dropdowns)
      validateEventTimes(
        startDateTime: _startDateTime,
        endDateTime: _endDateTime,
        recurrenceEndDate: _recurrenceEndDate,
        recurrenceType: _recurrenceType,
        isEditMode: isEditMode,
        originalStartTime: isEditMode ? widget.event?.startEventAt : null,
      );
    }
  }


  Future<void> _selectRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate,
      firstDate: _selectedDate,
      lastDate: EventValidationService.getMaximumDate(_selectedDate),
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
        _recurrenceEndDate = picked;
      });
      
      // Trigger validation after recurrence end date change
      validateEventTimes(
        startDateTime: _startDateTime,
        endDateTime: _endDateTime,
        recurrenceEndDate: _recurrenceEndDate,
        recurrenceType: _recurrenceType,
        isEditMode: isEditMode,
        originalStartTime: isEditMode ? widget.event?.startEventAt : null,
      );
    }
  }

  Future<void> _saveRecurringEvent() async {
    if (!_formKey.currentState!.validate()) return;

    // Perform final validation before save
    validateEventTimes(
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      recurrenceEndDate: _recurrenceEndDate,
      recurrenceType: _recurrenceType,
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
        // Update existing recurring event
        final eventData = <String, dynamic>{};
        
        if (_nameController.text.trim() != widget.event!.name) {
          eventData['name'] = _nameController.text.trim();
        }
        
        if (_descriptionController.text.trim() != (widget.event!.description ?? '')) {
          eventData['description'] = _descriptionController.text.trim();
        }
        
        if (_locationController.text.trim() != (widget.event!.addressLocation ?? '')) {
          eventData['addressLocation'] = _locationController.text.trim();
        }
        
        if (_selectedType != widget.event!.type) {
          eventData['type'] = _selectedType;
        }
        
        if (!_startDateTime.isAtSameMomentAs(widget.event!.startEventAt)) {
          eventData['startEventAt'] = _startDateTime.toUtc().toIso8601String();
        }
        
        if (!_endDateTime.isAtSameMomentAs(widget.event!.endEventAt)) {
          eventData['endEventAt'] = _endDateTime.toUtc().toIso8601String();
        }
        
        if (_recurrenceType != widget.event!.recurrenceType) {
          eventData['recurrenceType'] = _recurrenceType;
        }
        
        if (!_recurrenceEndDate.isAtSameMomentAs(widget.event!.endRecurrenceAt ?? DateTime.now())) {
          eventData['endRecurrenceAt'] = _recurrenceEndDate.toUtc().toIso8601String();
        }

        if (eventData.isEmpty) {
          Navigator.of(context).pop(false);
          return;
        }

        final result = await apiService.updateRecurringEvent(widget.event!.id, eventData);
        
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring event updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Create new recurring event
        final eventData = {
          'id': '',
          'name': _nameController.text.trim(),
          'startEventAt': _startDateTime.toUtc().toIso8601String(),
          'endEventAt': _endDateTime.toUtc().toIso8601String(),
          'addressLocation': _locationController.text.trim(),
          'longLocation': '',
          'latLocation': '',
          'checkInLocationStatus': 'check-in-required',
          'description': _descriptionController.text.trim(),
          'recurrenceType': _recurrenceType,
          'startRecurrenceAt': _startDateTime.toUtc().toIso8601String(),
          'endRecurrenceAt': _recurrenceEndDate.toUtc().toIso8601String(),
          'isRecurrence': true,
          'type': _selectedType,
        };

        await apiService.createRecurringEvent(eventData);
        
        // Consider the operation successful if no exception was thrown
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring events created successfully'),
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
            content: Text('Failed to ${isEditMode ? 'update' : 'create'} recurring event: $e'),
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
          widget.isReadOnly ? 'Recurring Event Details' : (isEditMode ? 'Edit Recurring Event' : 'Add Recurring Events'),
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
                    _buildDateField(themeService),
                    const SizedBox(height: 20),
                    _buildTimeSection(themeService),
                    const SizedBox(height: 20),
                    _buildRecurrenceSection(themeService),
                    const SizedBox(height: 20),
                    _buildTypeDropdown(themeService),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location (Optional)',
                      hint: 'Enter event location',
                      themeService: themeService,
                      readOnly: widget.isReadOnly,
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
            child: SafeArea(
              top: false,
              child: _buildActionButtons(),
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

  Widget _buildDateField(ThemeService themeService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start Recurrence Date',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.isReadOnly ? null : _selectDate,
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
                  DateFormat('MM/dd/yyyy').format(_selectedDate),
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
                    final time = TimeUtils.parseTimeString(value);
                    if (time != null) {
                      setState(() {
                        _startTime = time;
                        // Auto-adjust end time if needed
                        if (_endTime.hour < _startTime.hour || 
                            (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute)) {
                          _endTime = TimeOfDay(
                            hour: _startTime.hour + 1 > 23 ? 23 : _startTime.hour + 1,
                            minute: _startTime.minute,
                          );
                        }
                      });
                      
                      // Trigger validation without auto-correction (since dropdown prevents invalid times)
                      validateEventTimes(
                        startDateTime: _startDateTime,
                        endDateTime: _endDateTime,
                        recurrenceEndDate: _recurrenceEndDate,
                        recurrenceType: _recurrenceType,
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
                    final time = TimeUtils.parseTimeString(value);
                    if (time != null) {
                      setState(() {
                        _endTime = time;
                      });
                      
                      // Trigger validation without auto-correction (since dropdown prevents invalid times)
                      validateEventTimes(
                        startDateTime: _startDateTime,
                        endDateTime: _endDateTime,
                        recurrenceEndDate: _recurrenceEndDate,
                        recurrenceType: _recurrenceType,
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

  Widget _buildRecurrenceSection(ThemeService themeService) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recurrence Until',
                    style: TextStyle(
                      color: themeService.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.isReadOnly ? null : _selectRecurrenceEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                      decoration: BoxDecoration(
                        color: themeService.cardColor,
                        border: Border.all(color: themeService.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MM/dd/yyyy').format(_recurrenceEndDate),
                              style: TextStyle(color: themeService.textColor, fontSize: 16),
                            ),
                          ),
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
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recurrence Type',
                    style: TextStyle(
                      color: themeService.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoDropdown(
                    value: RecurrenceUtils.formatType(_recurrenceType),
                    items: RecurrenceUtils.formattedTypes,
                    hintText: 'Select recurrence',
                    onChanged: widget.isReadOnly ? null : (value) {
                      if (value != null) {
                        final rawType = RecurrenceUtils.getRawType(value);
                        if (rawType != null) {
                          setState(() {
                            _recurrenceType = rawType;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeDropdown(ThemeService themeService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Type',
          style: TextStyle(
            color: themeService.textColor,
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

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveRecurringEvent,
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
                isEditMode ? 'Update Recurring Event' : 'Add Recurring Events',
                style: const TextStyle(
                  color: Color(0xFF1A1F2B),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

}