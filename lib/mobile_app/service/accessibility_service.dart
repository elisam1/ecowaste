import 'package:flutter/material.dart';
import 'logging_service.dart';
import 'dart:math' as math;

/// Service for accessibility features: text-to-speech, high contrast, font scaling
/// Ensures EcoWaste is usable by users with various accessibility needs
class AccessibilityService {
  // Font size scale ranges
  static const double minFontScale = 0.8;
  static const double maxFontScale = 2.0;
  static const double defaultFontScale = 1.0;

  // High contrast mode state
  static bool _highContrastEnabled = false;

  // Font scale state
  static double _currentFontScale = defaultFontScale;

  // Text-to-speech enabled state
  static bool _textToSpeechEnabled = false;

  /// Initialize accessibility service with user preferences
  static Future<void> initialize() async {
    try {
      LoggingService.info('Initializing accessibility service');
      // Load user preferences from SharedPreferences if implemented
      // For now, using defaults
    } catch (e) {
      LoggingService.error('Error initializing accessibility: $e');
    }
  }

  /// Get current font scale
  static double getFontScale() => _currentFontScale;

  /// Set font scale (0.8x to 2.0x)
  static bool setFontScale(double scale) {
    if (scale < minFontScale || scale > maxFontScale) {
      LoggingService.warning(
        'Font scale $scale outside valid range [$minFontScale, $maxFontScale]',
      );
      return false;
    }

    _currentFontScale = scale;
    LoggingService.info('Font scale set to ${scale}x');
    return true;
  }

  /// Increase font size
  static bool increaseFontSize() {
    final newScale = (_currentFontScale + 0.1).clamp(
      minFontScale,
      maxFontScale,
    );
    if (newScale != _currentFontScale) {
      _currentFontScale = newScale;
      LoggingService.info('Font size increased to ${_currentFontScale}x');
      return true;
    }
    return false;
  }

  /// Decrease font size
  static bool decreaseFontSize() {
    final newScale = (_currentFontScale - 0.1).clamp(
      minFontScale,
      maxFontScale,
    );
    if (newScale != _currentFontScale) {
      _currentFontScale = newScale;
      LoggingService.info('Font size decreased to ${_currentFontScale}x');
      return true;
    }
    return false;
  }

  /// Reset font size to default
  static void resetFontSize() {
    _currentFontScale = defaultFontScale;
    LoggingService.info('Font size reset to default');
  }

  /// Get adjusted font size for different text types
  static double getAdjustedFontSize(double baseSize) {
    return baseSize * _currentFontScale;
  }

  /// Accessibility-aware text styles with font scaling
  static TextStyle getHeadingStyle(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return TextStyle(
      fontSize: getAdjustedFontSize(24),
      fontWeight: fontWeight,
      color: color ?? (_highContrastEnabled ? Colors.black : Colors.grey[800]),
    );
  }

  static TextStyle getBodyStyle(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      fontSize: getAdjustedFontSize(16),
      fontWeight: fontWeight,
      color: color ?? (_highContrastEnabled ? Colors.black : Colors.grey[700]),
    );
  }

  static TextStyle getCaptionStyle(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: getAdjustedFontSize(12),
      color:
          color ?? (_highContrastEnabled ? Colors.black54 : Colors.grey[600]),
    );
  }

  /// Check if high contrast mode is enabled
  static bool isHighContrastEnabled() => _highContrastEnabled;

  /// Toggle high contrast mode
  static bool toggleHighContrast() {
    _highContrastEnabled = !_highContrastEnabled;
    LoggingService.info(
      'High contrast mode ${_highContrastEnabled ? "enabled" : "disabled"}',
    );
    return _highContrastEnabled;
  }

  /// Enable high contrast mode
  static void enableHighContrast() {
    _highContrastEnabled = true;
    LoggingService.info('High contrast mode enabled');
  }

  /// Disable high contrast mode
  static void disableHighContrast() {
    _highContrastEnabled = false;
    LoggingService.info('High contrast mode disabled');
  }

  /// Get high contrast color scheme
  static Map<String, Color> getHighContrastColors() {
    return {
      'primary': Colors.black,
      'secondary': Colors.white,
      'background': Colors.white,
      'text': Colors.black,
      'accent': Colors.yellow[700] ?? Colors.yellow,
      'error': Colors.red[900] ?? Colors.red,
      'success': Colors.green[900] ?? Colors.green,
      'warning': Colors.orange[900] ?? Colors.orange,
    };
  }

  /// Get normal color scheme
  static Map<String, Color> getNormalColors() {
    return {
      'primary': const Color(0xFF4CAF50),
      'secondary': const Color(0xFF2196F3),
      'background': Colors.white,
      'text': Colors.grey[800] ?? Colors.black,
      'accent': Colors.teal,
      'error': Colors.red,
      'success': Colors.green,
      'warning': Colors.orange,
    };
  }

  /// Get appropriate color scheme based on contrast settings
  static Color getColor(String colorKey) {
    final scheme = _highContrastEnabled
        ? getHighContrastColors()
        : getNormalColors();
    return scheme[colorKey] ?? Colors.black;
  }

  /// Check if text-to-speech is enabled
  static bool isTextToSpeechEnabled() => _textToSpeechEnabled;

  /// Enable text-to-speech
  static void enableTextToSpeech() {
    _textToSpeechEnabled = true;
    LoggingService.info('Text-to-speech enabled');
  }

  /// Disable text-to-speech
  static void disableTextToSpeech() {
    _textToSpeechEnabled = false;
    LoggingService.info('Text-to-speech disabled');
  }

  /// Toggle text-to-speech
  static bool toggleTextToSpeech() {
    _textToSpeechEnabled = !_textToSpeechEnabled;
    LoggingService.info(
      'Text-to-speech ${_textToSpeechEnabled ? "enabled" : "disabled"}',
    );
    return _textToSpeechEnabled;
  }

  /// Generate accessible text-to-speech transcript
  /// In production, integrate with flutter_tts package
  static String generateAccessibleTranscript(String text) {
    LoggingService.info('Generated accessible transcript for TTS');
    return text;
  }

  /// Prepare description for text-to-speech with clear pronunciation
  static String prepareForSpeech(String text) {
    // Replace symbols with spoken equivalents
    var prepared = text
        .replaceAll('&', ' and ')
        .replaceAll('@', ' at ')
        .replaceAll('#', ' number ')
        .replaceAll('₦', ' naira ')
        .replaceAll(r'$', ' dollars ')
        .replaceAll('%', ' percent ')
        .replaceAll('°C', ' degrees celsius ')
        .replaceAll('°F', ' degrees fahrenheit ');

    LoggingService.info('Prepared text for speech synthesis');
    return prepared;
  }

  /// Get accessibility label for icons and images
  static String getAccessibilityLabel(String key) {
    final labels = {
      'pickup_location': 'Pickup location on map',
      'collector_status': 'Collector status indicator',
      'rating_stars': 'User rating in stars',
      'trash_icon': 'Waste bin icon',
      'marketplace_item': 'Marketplace item image',
      'profile_avatar': 'User profile picture',
      'send_message': 'Send message button',
      'location_pin': 'Location pin icon',
      'phone_call': 'Call button',
      'favorite_heart': 'Add to favorites button',
      'share': 'Share button',
      'delete': 'Delete button',
      'edit': 'Edit button',
      'back': 'Back button',
      'menu': 'Navigation menu',
    };

    return labels[key] ?? 'Button';
  }

  /// Create accessible tooltip text
  static String createAccessibleTooltip(String action, String description) {
    return '$action: $description';
  }

  /// Validate text contrast ratio (WCAG 2.0 AA standard: 4.5:1 for normal text)
  static bool isContrastSufficient(Color foreground, Color background) {
    final fgLuminance = _relativeLuminance(foreground);
    final bgLuminance = _relativeLuminance(background);

    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

    final ratio = (lighter + 0.05) / (darker + 0.05);
    return ratio >= 4.5; // WCAG AA standard
  }

  /// Calculate relative luminance of a color
  static double _relativeLuminance(Color color) {
    // Use non-deprecated normalized channel getters (0.0 - 1.0)
    final red = _linearizeColorComponent(color.r);
    final green = _linearizeColorComponent(color.g);
    final blue = _linearizeColorComponent(color.b);

    return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }

  /// Linearize color component for luminance calculation
  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return math.pow((component + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Get all accessibility settings as map
  static Map<String, dynamic> getAllSettings() {
    return {
      'fontScale': _currentFontScale,
      'highContrast': _highContrastEnabled,
      'textToSpeech': _textToSpeechEnabled,
      'minFontScale': minFontScale,
      'maxFontScale': maxFontScale,
    };
  }

  /// Reset all accessibility settings to defaults
  static void resetAllSettings() {
    _currentFontScale = defaultFontScale;
    _highContrastEnabled = false;
    _textToSpeechEnabled = false;
    LoggingService.info('All accessibility settings reset to defaults');
  }
}

// Using `dart:math` for power calculations (supports fractional exponents)
