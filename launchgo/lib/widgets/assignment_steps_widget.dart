import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AssignmentStepsWidget extends StatefulWidget {
  final List<TextEditingController> stepControllers;
  final List<Map<String, dynamic>?> originalStepData;
  final TextEditingController newStepController;
  final ThemeService themeService;
  final Function(int) onDeleteStep;
  final VoidCallback onAddStep;
  final InputDecoration Function({
    required String hintText,
    String? prefixText,
    TextStyle? prefixStyle,
    EdgeInsetsGeometry? contentPadding,
  }) getInputDecoration;

  static const double fieldHeight = 42.0;
  static const double borderRadius = 12.0;
  static const double horizontalPadding = 12.0;
  static const double verticalPadding = 10.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const int maxSteps = 10;

  const AssignmentStepsWidget({
    super.key,
    required this.stepControllers,
    required this.originalStepData,
    required this.newStepController,
    required this.themeService,
    required this.onDeleteStep,
    required this.onAddStep,
    required this.getInputDecoration,
  });

  @override
  State<AssignmentStepsWidget> createState() => _AssignmentStepsWidgetState();
}

class _AssignmentStepsWidgetState extends State<AssignmentStepsWidget> {
  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 Building assignment steps UI - ${widget.stepControllers.length} controllers');
    return Column(
      children: [
        // Existing steps
        ...widget.stepControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Container(
            margin: EdgeInsets.only(bottom: AssignmentStepsWidget.spacingMedium),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AssignmentStepsWidget.fieldHeight,
                    child: TextFormField(
                      controller: controller,
                      style: TextStyle(
                        color: widget.themeService.inputTextColor,
                        fontSize: 16,
                      ),
                      decoration: widget.getInputDecoration(
                        hintText: 'Step ${index + 1}',
                        prefixText: '${index + 1}. ',
                        prefixStyle: TextStyle(
                          color: widget.themeService.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AssignmentStepsWidget.horizontalPadding,
                          vertical: AssignmentStepsWidget.verticalPadding,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AssignmentStepsWidget.spacingSmall),
                IconButton(
                  onPressed: () => widget.onDeleteStep(index),
                  icon: Icon(
                    Icons.close,
                    color: widget.themeService.textSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        }),
        // Add new step row
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: AssignmentStepsWidget.fieldHeight,
                child: TextField(
                  controller: widget.newStepController,
                  style: TextStyle(
                    color: widget.themeService.inputTextColor,
                    fontSize: 16,
                  ),
                  decoration: widget.getInputDecoration(
                    hintText: 'Add a step...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AssignmentStepsWidget.horizontalPadding,
                      vertical: AssignmentStepsWidget.verticalPadding,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: AssignmentStepsWidget.spacingMedium),
            SizedBox(
              height: AssignmentStepsWidget.fieldHeight,
              child: ElevatedButton(
                onPressed: widget.stepControllers.length < AssignmentStepsWidget.maxSteps
                    ? widget.onAddStep
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.stepControllers.length < AssignmentStepsWidget.maxSteps
                      ? widget.themeService.backgroundColor
                      : widget.themeService.backgroundColor.withValues(alpha: 0.5),
                  foregroundColor: widget.stepControllers.length < AssignmentStepsWidget.maxSteps
                      ? widget.themeService.textColor
                      : widget.themeService.textColor.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AssignmentStepsWidget.borderRadius),
                    side: BorderSide(
                      color: widget.stepControllers.length < AssignmentStepsWidget.maxSteps
                          ? widget.themeService.borderColor
                          : widget.themeService.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Text(
                  widget.stepControllers.length < AssignmentStepsWidget.maxSteps
                      ? 'Add Step (${widget.stepControllers.length}/${AssignmentStepsWidget.maxSteps})'
                      : 'Max steps reached',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.stepControllers.length < AssignmentStepsWidget.maxSteps
                        ? widget.themeService.textColor
                        : widget.themeService.textColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}