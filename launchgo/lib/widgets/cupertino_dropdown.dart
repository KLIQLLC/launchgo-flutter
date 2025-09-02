import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:provider/provider.dart';

class CupertinoDropdown extends StatefulWidget {
  final String? value;
  final List<String> items;
  final Function(String?)? onChanged;
  final String? hintText;
  final bool isRequired;
  final String? Function(String?)? validator;

  const CupertinoDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.isRequired = false,
    this.validator,
  });

  @override
  State<CupertinoDropdown> createState() => _CupertinoDropdownState();
}

class _CupertinoDropdownState extends State<CupertinoDropdown> {
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(CupertinoDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setState(() {
        _selectedValue = widget.value;
      });
    }
  }

  void _showPicker(BuildContext context, ThemeService themeService) {
    // Don't show picker if items list is empty
    if (widget.items.isEmpty) return;
    
    int initialIndex = 0;
    if (_selectedValue != null) {
      final index = widget.items.indexOf(_selectedValue!);
      if (index != -1) {
        initialIndex = index;
      }
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        String tempValue = _selectedValue ?? widget.items[initialIndex];
        
        return Container(
          height: 250,
          color: themeService.backgroundColor,
          child: Column(
            children: [
              // Header with Cancel and Done buttons
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: themeService.cardColor,
                  border: Border(
                    bottom: BorderSide(
                      color: themeService.borderColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: themeService.textSecondaryColor,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        setState(() {
                          _selectedValue = tempValue;
                        });
                        widget.onChanged?.call(tempValue);
                        Navigator.pop(context);
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: ThemeService.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Picker
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: themeService.backgroundColor,
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempValue = widget.items[index];
                  },
                  children: widget.items.map((String item) {
                    return Center(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: themeService.textColor,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    // Check if there's a validation error
    String? errorText;
    if (widget.validator != null) {
      errorText = widget.validator!(_selectedValue);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.items.isEmpty ? null : () => _showPicker(context, themeService),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: themeService.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText != null ? Colors.red : themeService.borderColor,
                width: errorText != null ? 1 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedValue ?? widget.hintText ?? 'Select an option',
                    style: TextStyle(
                      color: _selectedValue != null 
                          ? themeService.textColor 
                          : themeService.textTertiaryColor,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.expand_more,
                  color: themeService.textSecondaryColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}