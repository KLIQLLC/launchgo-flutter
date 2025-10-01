import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/api_service_retrofit.dart';
import '../../services/theme_service.dart';
import '../../widgets/cupertino_dropdown.dart';

class RecurringEventFormScreen extends StatefulWidget {
  const RecurringEventFormScreen({super.key});

  @override
  State<RecurringEventFormScreen> createState() => _RecurringEventFormScreenState();
}

class _RecurringEventFormScreenState extends State<RecurringEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late DateTime _recurrenceEndDate;

  String _selectedType = 'study';
  String _recursionType = 'every-day';
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

  final List<String> _recursionTypes = [
    'every-day',
    'every-week',
    'every-month',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    
    _selectedDate = DateTime.now();
    _startTime = const TimeOfDay(hour: 12, minute: 0); // 12:00 PM
    _endTime = const TimeOfDay(hour: 12, minute: 0); // 12:00 PM
    _recurrenceEndDate = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _formatEventType(String type) {
    if (type == 'lg_session') {
      return 'LG Session';
    }
    return type[0].toUpperCase() + type.substring(1);
  }

  String _formatRecursionType(String type) {
    switch (type) {
      case 'every-day':
        return 'Every Day';
      case 'every-week':
        return 'Every Week';
      case 'every-month':
        return 'Every Month';
      default:
        return type;
    }
  }

  String _formatTimeForApi(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatTimeForDropdown(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
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
        _selectedDate = picked;
        if (_recurrenceEndDate.isBefore(_selectedDate)) {
          _recurrenceEndDate = _selectedDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
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
        _startTime = picked;
        // Auto-adjust end time if needed
        if (_endTime.hour < _startTime.hour || 
            (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute)) {
          _endTime = TimeOfDay(
            hour: _startTime.hour + 1 > 23 ? 23 : _startTime.hour + 1,
            minute: _startTime.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
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
        _endTime = picked;
      });
    }
  }

  Future<void> _selectRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate,
      firstDate: _selectedDate,
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
        _recurrenceEndDate = picked;
      });
    }
  }

  Future<void> _saveRecurringEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = _combineDateAndTime(_selectedDate, _startTime);
    final endDateTime = _combineDateAndTime(_selectedDate, _endTime);

    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
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
      
      final eventData = {
        'id': '',
        'name': _nameController.text.trim(),
        'dateAt': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'startTime': _formatTimeForApi(_startTime),
        'endTime': _formatTimeForApi(_endTime),
        'recursionEndAt': _recurrenceEndDate.toUtc().toIso8601String(),
        'recursionType': _recursionType,
        'type': _selectedType,
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'startAt': startDateTime.toUtc().toIso8601String(),
        'endAt': endDateTime.toUtc().toIso8601String(),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create recurring events: $e'),
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
        title: const Text(
          'Add Recurring Events',
          style: TextStyle(color: Colors.white),
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
                    _buildDateField(),
                    const SizedBox(height: 20),
                    _buildTimeSection(),
                    const SizedBox(height: 20),
                    _buildRecurrenceSection(),
                    const SizedBox(height: 20),
                    _buildTypeDropdown(),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location (Optional)',
                      hint: 'Enter event location',
                      themeService: themeService,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description (Optional)',
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

  Widget _buildDateField() {
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
          onTap: _selectDate,
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
                  DateFormat('MM/dd/yyyy').format(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                SvgPicture.asset(
                  'assets/icons/ic_calendar.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    Colors.grey[400]!,
                    BlendMode.srcIn,
                  ),
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
                value: _formatTimeForDropdown(_startTime),
                items: _generateTimeSlots(),
                hintText: 'Select time',
                onChanged: (value) {
                  if (value != null) {
                    final time = _parseTimeString(value);
                    if (time != null) {
                      setState(() {
                        _startTime = time;
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
                value: _formatTimeForDropdown(_endTime),
                items: _generateTimeSlots(),
                hintText: 'Select time',
                onChanged: (value) {
                  if (value != null) {
                    final time = _parseTimeString(value);
                    if (time != null) {
                      setState(() {
                        _endTime = time;
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

  Widget _buildRecurrenceSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recurrence Until',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectRecurrenceEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2332),
                        border: Border.all(color: Colors.grey[600]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MM/dd/yyyy').format(_recurrenceEndDate),
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          SvgPicture.asset(
                            'assets/icons/ic_calendar.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              Colors.grey[400]!,
                              BlendMode.srcIn,
                            ),
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
                  const Text(
                    'Recursion Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoDropdown(
                    value: _formatRecursionType(_recursionType),
                    items: _recursionTypes.map((type) => _formatRecursionType(type)).toList(),
                    hintText: 'Select recursion',
                    onChanged: (value) {
                      if (value != null) {
                        final index = _recursionTypes.indexWhere((type) => 
                          _formatRecursionType(type) == value
                        );
                        if (index != -1) {
                          setState(() {
                            _recursionType = _recursionTypes[index];
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

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveRecurringEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1F2B),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF1A1F2B),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Add Recurring Events',
                style: TextStyle(
                  color: Color(0xFF1A1F2B),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  List<String> _generateTimeSlots() {
    final List<String> slots = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 15) {
        final time = TimeOfDay(hour: hour, minute: minute);
        final displayHour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
        final period = time.period == DayPeriod.am ? 'AM' : 'PM';
        slots.add('${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period');
      }
    }
    return slots;
  }

  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1] == 'PM';
      
      if (hour == 12 && !isPM) {
        hour = 0; // 12:00 AM is 0:00
      } else if (hour != 12 && isPM) {
        hour += 12; // Convert PM hours
      }
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
}