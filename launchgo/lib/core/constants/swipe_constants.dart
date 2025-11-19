/// Global constants for swipe-to-delete functionality
class SwipeConstants {
  // Maximum distance a card can slide (as a ratio of card width)
  static const double maxSlideRatio = 0.35; // 35% of card width
  
  // Threshold to trigger deletion (as a ratio of max slide distance)
  static const double dismissThreshold = 0.5; // 50% of max slide to trigger delete
  
  // Animation duration for slide animations
  static const Duration slideAnimationDuration = Duration(milliseconds: 200);
  
  // Animation duration for snap back
  static const Duration snapBackDuration = Duration(milliseconds: 150);
  
  // Delete background color
  static const double deleteBackgroundOpacity = 0.9;
}