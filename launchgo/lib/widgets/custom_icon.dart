import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Enum defining all available custom icons
enum CustomIconPath {
  document('assets/icons/ic_document.svg'),
  schedule('assets/icons/ic_schedule.svg'),
  course('assets/icons/ic_course.svg'),
  recap('assets/icons/ic_recap.svg'),
  chat('assets/icons/ic_chat.svg'),
  goal('assets/icons/ic_goal.svg'),
  ;

  final String path;
  const CustomIconPath(this.path);
}

/// A reusable widget for displaying SVG icons with customizable styling
class CustomIcon extends StatelessWidget {
  /// The icon from the enum
  final CustomIconPath icon;
  
  /// Size of the icon - can be Size(width, height) or use convenience constructors
  final Size size;
  
  /// Color to tint the icon
  final Color? color;
  
  /// Optional gradient for special effects
  final Gradient? customGradient;
  
  /// Blend mode for color/gradient application
  final BlendMode? blendMode;

  const CustomIcon({
    super.key,
    required this.icon,
    this.size = const Size(24, 24),
    this.color,
    this.customGradient,
    this.blendMode = BlendMode.srcIn,
  });

  /// Convenience constructor for square icons with single dimension
  CustomIcon.square({
    super.key,
    required this.icon,
    double dimension = 24,
    this.color,
    this.customGradient,
    this.blendMode = BlendMode.srcIn,
  }) : size = Size(dimension, dimension);

  @override
  Widget build(BuildContext context) {
    final width = size.width;
    final height = size.height;

    if (customGradient != null) {
      // For gradient effect, we need to use ShaderMask
      return ShaderMask(
        shaderCallback: (bounds) => customGradient!.createShader(bounds),
        blendMode: blendMode!,
        child: SvgPicture.asset(
          icon.path,
          width: width,
          height: height,
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
        ),
      );
    }

    // Regular solid color rendering
    return SvgPicture.asset(
      icon.path,
      width: width,
      height: height,
      colorFilter: color != null
          ? ColorFilter.mode(color!, blendMode!)
          : null,
    );
  }

  /// Factory constructor for creating a gradient icon
  factory CustomIcon.gradient({
    required CustomIconPath icon,
    required Gradient gradient,
    Size size = const Size(24, 24),
  }) {
    return CustomIcon(
      icon: icon,
      customGradient: gradient,
      size: size,
    );
  }

  /// Factory constructor for creating an icon with theme-aware colors
  factory CustomIcon.adaptive({
    required CustomIconPath icon,
    required BuildContext context,
    Size size = const Size(24, 24),
    Color? lightColor,
    Color? darkColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomIcon(
      icon: icon,
      size: size,
      color: isDark 
          ? (darkColor ?? Colors.white)
          : (lightColor ?? Colors.black87),
    );
  }
}