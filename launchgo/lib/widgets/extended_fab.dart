import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ExtendedFAB extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  
  const ExtendedFAB({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1F2B),
      icon: SvgPicture.asset(
        'assets/icons/ic_plus.svg',
        width: 20,
        height: 20,
        colorFilter: const ColorFilter.mode(
          Color(0xFF1A1F2B),
          BlendMode.srcIn,
        ),
      ),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1A1F2B),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}