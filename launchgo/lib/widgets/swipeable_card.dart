import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/constants/swipe_constants.dart';
import '../theme/app_colors.dart';

/// A reusable swipeable card widget with consistent swipe-to-delete behavior
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Future<bool> Function()? onSwipeToDelete;
  final bool canSwipe;
  final bool canTap;
  final Color deleteBackgroundColor;
  final String? deleteIconPath;
  final IconData? deleteIcon;
  
  const SwipeableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onSwipeToDelete,
    this.canSwipe = true,
    this.canTap = true,
    this.deleteBackgroundColor = Colors.red,
    this.deleteIconPath = 'assets/icons/ic_delete.svg',
    this.deleteIcon,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  double _maxSlideDistance = 0;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: SwipeConstants.slideAnimationDuration,
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.canSwipe || _isDeleting) return;
    
    if (details.delta.dx < 0) {
      // Sliding left (revealing delete)
      final progress = (_slideAnimation.value * _maxSlideDistance - details.delta.dx) / _maxSlideDistance;
      _animationController.value = progress.clamp(0.0, 1.0);
    } else if (details.delta.dx > 0) {
      // Sliding right (hiding delete)
      final progress = (_slideAnimation.value * _maxSlideDistance - details.delta.dx) / _maxSlideDistance;
      _animationController.value = progress.clamp(0.0, 1.0);
    }
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    if (!widget.canSwipe || _isDeleting) return;
    
    if (_slideAnimation.value > SwipeConstants.dismissThreshold) {
      // If swiped past threshold, trigger delete
      if (widget.onSwipeToDelete != null) {
        setState(() => _isDeleting = true);
        
        final shouldDelete = await widget.onSwipeToDelete!();
        
        if (mounted) {
          setState(() => _isDeleting = false);
          
          if (shouldDelete) {
            // The parent widget should handle the actual deletion
            // Just keep the card in deleted position
          } else {
            // User cancelled, snap back
            _animationController.reverse();
          }
        }
      } else {
        _animationController.reverse();
      }
    } else {
      // Snap back
      _animationController.animateBack(0, 
        duration: SwipeConstants.snapBackDuration
      );
    }
  }

  void _handleTap() {
    if (_slideAnimation.value == 0 && widget.canTap && widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxSlideDistance = constraints.maxWidth * SwipeConstants.maxSlideRatio;
        
        return Stack(
          children: [
            // Delete background
            if (widget.canSwipe)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    final progress = _slideAnimation.value;
                    return Opacity(
                      opacity: progress * SwipeConstants.deleteBackgroundOpacity,
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: widget.deleteBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: widget.deleteIconPath != null
                          ? SvgPicture.asset(
                              widget.deleteIconPath!,
                              width: 28,
                              height: 28,
                              colorFilter: ColorFilter.mode(
                                AppColors.textPrimary.withValues(alpha: progress),
                                BlendMode.srcIn,
                              ),
                            )
                          : Icon(
                              widget.deleteIcon,
                              color: AppColors.textPrimary.withValues(alpha: progress),
                              size: 28,
                            ),
                      ),
                    );
                  },
                ),
              ),
            
            // Main card that slides
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                final slideOffset = _slideAnimation.value * _maxSlideDistance;
                return Transform.translate(
                  offset: Offset(-slideOffset, 0),
                  child: child,
                );
              },
              child: GestureDetector(
                onHorizontalDragUpdate: widget.canSwipe ? _handleDragUpdate : null,
                onHorizontalDragEnd: widget.canSwipe ? _handleDragEnd : null,
                onTap: _handleTap,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}