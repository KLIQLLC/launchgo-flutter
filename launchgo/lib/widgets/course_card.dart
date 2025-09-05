import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final ThemeService themeService;
  final VoidCallback? onTap;
  final VoidCallback? onAssignmentsTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.themeService,
    this.onTap,
    this.onAssignmentsTap,
  });

  @override
  Widget build(BuildContext context) {
    final assignments = course['assignments'] as List? ?? [];
    final authService = context.read<AuthService>();
    final selectedSemester = authService.getSelectedSemester();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: themeService.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeService.borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and badges with automatic wrapping
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              course['name'] ?? '',
                              style: TextStyle(
                                color: themeService.textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Course code badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: themeService.borderColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                course['code'] ?? '',
                                style: TextStyle(
                                  color: themeService.textColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Credits badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF37474F),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${course['credits'] ?? 0} credit${course['credits'] != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              course['instructor'] ?? '',
                              style: TextStyle(
                                color: themeService.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                            if (selectedSemester != null) ...[
                              const Text(
                                ' • ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                selectedSemester.name,
                                style: TextStyle(
                                  color: themeService.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Grade badge with graduation cap icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    child: SvgPicture.asset(
                      'assets/icons/ic_graduation_cap.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        themeService.textColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getGradeBackgroundColor(course['grade']),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      course['grade'] ?? 'N/A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Description
              if (course['description'] != null && course['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  course['description'],
                  style: TextStyle(
                    color: themeService.textSecondaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // Assignments section
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onAssignmentsTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeService.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/ic_course.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                           themeService.textColor,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Assignments (${assignments.length})',
                        style: TextStyle(
                          color: themeService.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      SvgPicture.asset(
                        'assets/icons/ic_arrow.svg',
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          themeService.textSecondaryColor,
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
      ),
    );
  }

  Color _getGradeColor(String? grade) {
    if (grade == null) return Colors.grey;
    
    if (grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return Colors.blue;
    if (grade.startsWith('C')) return Colors.orange;
    if (grade.startsWith('D')) return Colors.deepOrange;
    if (grade == 'F') return Colors.red;
    
    return Colors.grey;
  }

  Color _getGradeBackgroundColor(String? grade) {
    if (grade == null) return Colors.grey;
    
    if (grade.startsWith('A')) return const Color(0xFF4CAF50);
    if (grade.startsWith('B')) return const Color(0xFF2196F3);
    if (grade.startsWith('C')) return const Color(0xFFFF9800);
    if (grade.startsWith('D')) return const Color(0xFFFF5722);
    if (grade == 'F') return const Color(0xFFF44336);
    
    return Colors.grey;
  }
}