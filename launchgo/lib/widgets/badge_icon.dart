import 'package:flutter/material.dart';

/// A widget that displays an icon with an optional badge for showing counts
class BadgeIcon extends StatelessWidget {
  final Widget icon;
  final int count;
  final Color? badgeColor;
  final Color? textColor;
  final double? badgeSize;
  final bool showBadge;

  const BadgeIcon({
    super.key,
    required this.icon,
    this.count = 0,
    this.badgeColor,
    this.textColor,
    this.badgeSize = 18,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge || count <= 0) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor ?? const Color(0xFF6B2024),
              shape: BoxShape.circle,
            ),
            constraints: BoxConstraints(
              minWidth: badgeSize!,
              minHeight: badgeSize!,
            ),
            child: Center(
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: textColor ?? const Color(0xFFF8FAFC),
                  fontSize: count > 99 ? 9 : 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}