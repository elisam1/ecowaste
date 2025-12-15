/// Application-wide constants to eliminate magic numbers and hardcoded values
class AppConstants {
  // Pricing
  static const double pricePerBin = 20.0;
  static const double minBinPrice = 0.0;

  // Bin constraints
  static const int maxBinCount = 10;
  static const int minBinCount = 1;

  // Timeout durations (in milliseconds)
  static const int requestTimeoutMs = 30000;
  static const int debounceDelayMs = 500;
  static const int pickupReminderMinutes = 30;
  static const int pickupReminderCheckIntervalMinutes = 5;

  // Location
  static const double locationAccuracyThreshold = 50.0; // meters
  static const int locationUpdateIntervalSeconds = 5;
  static const double defaultMapZoom = 15.0;
  static const double pickupLocationZoom = 18.0;

  // Image handling
  static const int maxImageSizeMB = 5;
  static const int maxImageSizeBytes = maxImageSizeMB * 1024 * 1024;
  static const int imageCompressionQuality = 75; // 0-100
  static const int compressedImageWidth = 800;
  static const int compressedImageHeight = 600;
  static const int thumbnailSize = 150;

  // Pagination
  static const int pageSize = 15;
  static const int itemsPerPage = 20;
  static const int marketplacePageSize = 12;

  // Chat
  static const int maxMessageLength = 1000;
  static const int typingIndicatorDurationSeconds = 3;
  static const int messageReadReceiptDelayMs = 500;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int maxBioLength = 500;
  static const int phoneNumberLength = 10;

  // Ratings & Reviews
  static const double minRating = 1.0;
  static const double maxRating = 5.0;
  static const int minReviewLength = 10;
  static const int maxReviewLength = 500;

  // Waste Classification
  static const List<String> wasteCategories = [
    'Plastic',
    'Metal',
    'Glass',
    'Paper',
    'Organic',
    'Electronics',
    'Mixed',
  ];

  // Marketplace Conditions
  static const List<String> itemConditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor',
  ];

  // Shipping Methods
  static const List<String> shippingMethods = [
    'Pickup',
    'Delivery',
    'Courier',
    'Local Meeting',
  ];

  // Request Status
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusRejected = 'rejected';

  // User Roles
  static const String roleUser = 'user';
  static const String roleCollector = 'collector';
  static const String roleAdmin = 'admin';

  // Firebase Collections
  static const String collectionUsers = 'users';
  static const String collectionCollectors = 'collectors';
  static const String collectionPickupRequests = 'pickup_requests';
  static const String collectionMarketplaceItems = 'marketplace_items';
  static const String collectionChats = 'chats';
  static const String collectionMessages = 'messages';
  static const String collectionReviews = 'reviews';
  static const String collectionTransactions = 'transactions';
  static const String collectionNotifications = 'notifications';

  // API Endpoints
  static const String apiBaseUrl = 'https://firebaseio.googleapis.com';

  // App Info
  static const String appVersion = '1.0.0';
  static const String appName = 'EcoWaste';

  // Cache Duration
  static const int cacheDurationMinutes = 30;
  static const int userCacheDurationMinutes = 60;

  // Rate Limiting
  static const int maxSignupAttemptsPerHour = 5;
  static const int maxLoginAttemptsPerHour = 10;
  static const int maxPaymentAttemptsPerHour = 20;

  // Thresholds
  static const double excellentRatingThreshold = 4.5;
  static const double goodRatingThreshold = 3.5;
  static const double fairRatingThreshold = 2.5;

  // Date/Time
  static const int maxFuturePickupDays = 30;
  static const int minPickupTimeFromNowMinutes = 30;

  // Weight/Volume
  static const double minWeightKg = 0.1;
  static const double maxWeightKg = 1000.0;
  static const double minVolumeM3 = 0.01;
  static const double maxVolumeM3 = 100.0;
}
