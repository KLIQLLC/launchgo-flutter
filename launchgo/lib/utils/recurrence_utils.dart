/// Utility class for handling recurrence type formatting and constants
class RecurrenceUtils {
  /// Available recurrence types
  static const List<String> types = [
    'every-day',
    'every-week', 
    'every-month',
  ];

  /// Formats a recurrence type for display
  /// 
  /// Takes the raw API value (e.g., 'every-day') and returns a 
  /// human-readable format (e.g., 'Every Day')
  static String formatType(String? type) {
    switch (type?.toLowerCase()) {
      case 'every-day':
        return 'Every Day';
      case 'every-week':
        return 'Every Week';
      case 'every-month':
        return 'Every Month';
      default:
        return type ?? '';
    }
  }

  /// Gets all available recurrence types formatted for display
  static List<String> get formattedTypes {
    return types.map((type) => formatType(type)).toList();
  }

  /// Finds the raw type value from a formatted display string
  /// 
  /// Takes a formatted string (e.g., 'Every Day') and returns
  /// the raw API value (e.g., 'every-day')
  static String? getRawType(String formattedType) {
    final index = formattedTypes.indexOf(formattedType);
    return index != -1 ? types[index] : null;
  }
}