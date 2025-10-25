import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final ThemeService themeService;
  final VoidCallback? onTap;
  final VoidCallback? onAssignmentsTap;
  final int cardIndex;

  const CourseCard({
    super.key,
    required this.course,
    required this.themeService,
    this.onTap,
    this.onAssignmentsTap,
    required this.cardIndex,
  });

  LinearGradient _getGradeGradient() {
    final gradients = [
      // First card: Blue gradient
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4A8EF2), Color(0xFF0E4FD3)],
      ),
      // Second card: Purple gradient  
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB862E8), Color(0xFF9433C5)],
      ),
      // Third card: Green gradient
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5FD585), Color(0xFF27A353)],
      ),
    ];
    return gradients[cardIndex % gradients.length];
  }

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
                                  color: AppColors.textWhite30,
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
                                color: AppColors.badgeGrey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${course['credits'] ?? 0} credit${course['credits'] != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
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
                                  color: AppColors.textGrey,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: _getGradeGradient(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/ic_graduation_cap.svg',
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            course['grade'] ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: _getGradeGradient(),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/ic_course.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                           Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Assignments (${assignments.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      SvgPicture.asset(
                        'assets/icons/ic_arrow.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
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

}