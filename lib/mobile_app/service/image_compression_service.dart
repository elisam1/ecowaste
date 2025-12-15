import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';


/// Service for optimizing images before storage
class ImageCompressionService {
  /// Compress an image file to reduce storage size and bandwidth
  ///
  /// [imagePath] - Path to the image file
  /// [quality] - JPEG quality (0-100), defaults to AppConstants.imageCompressionQuality
  ///
  /// Returns compressed image file or null if compression fails
  static Future<File?> compressImage(
    String imagePath, {
    int quality = AppConstants.imageCompressionQuality,
  }) async {
    try {
      final file = File(imagePath);

      // Check file size
      final fileSize = await file.length();
      if (fileSize > AppConstants.maxImageSizeBytes) {
        throw Exception(
          'Image size ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB exceeds '
          'maximum allowed size of ${AppConstants.maxImageSizeMB}MB',
        );
      }

      // Decode image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if necessary
      img.Image resized = image;
      if (image.width > AppConstants.compressedImageWidth ||
          image.height > AppConstants.compressedImageHeight) {
        resized = img.copyResize(
          image,
          width: AppConstants.compressedImageWidth,
          height: AppConstants.compressedImageHeight,
          interpolation: img.Interpolation.average,
        );
      }

      // Compress and encode
      final compressed = img.encodeJpg(resized, quality: quality);

      // Save to temporary file
      final compressedFile = File(imagePath)..writeAsBytesSync(compressed);

      return compressedFile;
    } catch (e) {

      return null;
    }
  }

  /// Create a thumbnail for preview
  ///
  /// [imagePath] - Path to the image file
  ///
  /// Returns thumbnail image bytes or null if creation fails
  static Future<List<int>?> createThumbnail(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final thumbnail = img.copyResize(
        image,
        width: AppConstants.thumbnailSize,
        height: AppConstants.thumbnailSize,
        interpolation: img.Interpolation.average,
      );

      return img.encodeJpg(thumbnail, quality: 85);
    } catch (e) {

      return null;
    }
  }

  /// Get compression ratio (original size vs compressed size)
  static Future<double> getCompressionRatio(
    File originalFile,
    File compressedFile,
  ) async {
    try {
      final originalSize = await originalFile.length();
      final compressedSize = await compressedFile.length();

      if (originalSize == 0) return 0;
      return ((originalSize - compressedSize) / originalSize) * 100;
    } catch (e) {

      return 0;
    }
  }

  /// Batch compress multiple images
  static Future<List<File?>> compressBatch(
    List<String> imagePaths, {
    int quality = AppConstants.imageCompressionQuality,
  }) async {
    final results = <File?>[];

    for (final path in imagePaths) {
      final compressed = await compressImage(path, quality: quality);
      results.add(compressed);
    }

    return results;
  }

  /// Validate image before compression
  static Future<bool> validateImage(String imagePath) async {
    try {
      final file = File(imagePath);

      // Check file exists
      if (!await file.exists()) {
        throw Exception('Image file does not exist');
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize > AppConstants.maxImageSizeBytes) {
        throw Exception(
          'Image size exceeds maximum allowed: '
          '${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB > '
          '${AppConstants.maxImageSizeMB}MB',
        );
      }

      // Validate image format
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Invalid image format');
      }

      return true;
    } catch (e) {

      return false;
    }
  }

  /// Get image dimensions
  static Future<Map<String, int>?> getImageDimensions(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      return {'width': image.width, 'height': image.height};
    } catch (e) {

      return null;
    }
  }
}


