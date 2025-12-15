/// Service for sanitizing and validating user inputs to prevent injection attacks
class InputSanitizationService {
  /// Sanitize text input to prevent injection attacks
  static String sanitizeText(String input) {
    if (input.isEmpty) return '';

    // Remove dangerous characters but keep reasonable symbols
    return input
        .replaceAll(RegExp(r'[<>"' + "'" + r']'), '') // Remove HTML/script tags
        .replaceAll(RegExp(r'[{}[\]\\]'), '') // Remove braces
        .trim();
  }

  /// Validate and sanitize email
  static String? sanitizeEmail(String email) {
    final trimmed = email.trim().toLowerCase();

    // RFC 5322 simplified email regex
    const emailRegex =
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$";

    if (RegExp(emailRegex).hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  /// Validate and sanitize phone number
  static String? sanitizePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Validate phone number length (e.g., 10 digits for US)
    if (digits.length >= 10 && digits.length <= 15) {
      return digits;
    }
    return null;
  }

  /// Validate and sanitize name
  static String? sanitizeName(String name, {int maxLength = 50}) {
    final trimmed = name.trim();

    // Check length
    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }

    // Allow letters, spaces, hyphens, and apostrophes only
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(trimmed)) {
      return null;
    }

    return trimmed;
  }

  /// Validate and sanitize password
  static String? sanitizePassword(String password) {
    // Password must be at least 8 characters
    if (password.length < 8) {
      return null;
    }

    // Check for at least one uppercase, one lowercase, one digit
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return null;
    }

    return password;
  }

  /// Validate and sanitize URL
  static String? sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Only allow http and https schemes
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      return uri.toString();
    } catch (e) {
      return null;
    }
  }

  /// Sanitize location/address input
  static String? sanitizeAddress(String address, {int maxLength = 200}) {
    final trimmed = address.trim();

    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }

    // Allow letters, numbers, spaces, commas, dots, hyphens
    if (!RegExp(r"^[a-zA-Z0-9\s,.#\-]+$").hasMatch(trimmed)) {
      return null;
    }

    return trimmed;
  }

  /// Validate and sanitize currency amount
  static double? sanitizeCurrency(String amount) {
    try {
      final value = double.parse(amount);

      // Validate positive amount
      if (value < 0) return null;

      // Round to 2 decimal places
      return double.parse(value.toStringAsFixed(2));
    } catch (e) {
      return null;
    }
  }

  /// Sanitize product/item name
  static String? sanitizeProductName(String name, {int maxLength = 100}) {
    final trimmed = name.trim();

    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }

    // Allow alphanumeric, spaces, hyphens, parentheses
    if (!RegExp(r"^[a-zA-Z0-9\s\-()]+$").hasMatch(trimmed)) {
      return null;
    }

    return trimmed;
  }

  /// Validate and sanitize description/review text
  static String? sanitizeDescription(String text, {int maxLength = 500}) {
    final trimmed = text.trim();

    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }

    // Remove potential XSS characters but keep regular text
    final sanitized = trimmed
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'javascript:'), '') // Remove javascript protocol
        .replaceAll(RegExp(r'on\w+\s*='), ''); // Remove event handlers

    return sanitized.isNotEmpty ? sanitized : null;
  }

  /// Sanitize numeric input (integers)
  static int? sanitizeInteger(String value) {
    try {
      return int.parse(value.trim());
    } catch (e) {
      return null;
    }
  }

  /// Sanitize numeric input (doubles)
  static double? sanitizeDouble(String value) {
    try {
      return double.parse(value.trim());
    } catch (e) {
      return null;
    }
  }

  /// Validate username
  static String? sanitizeUsername(String username, {int maxLength = 30}) {
    final trimmed = username.trim().toLowerCase();

    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }

    // Allow alphanumeric, underscores, hyphens (no spaces)
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(trimmed)) {
      return null;
    }

    return trimmed;
  }

  /// Batch sanitize multiple fields (returns true if all valid)
  static bool validateBatch(Map<String, dynamic> fields) {
    for (final entry in fields.entries) {
      if (entry.value == null || entry.value.isEmpty) {
        return false;
      }
    }
    return true;
  }
}
