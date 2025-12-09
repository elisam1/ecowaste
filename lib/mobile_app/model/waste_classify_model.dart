// import 'dart:io';
// // import 'dart:typed_data';
// import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
// import 'package:flutter_application_1/service/recycling_inst.dart';
// import 'package:flutter_application_1/user_screen/not_using/classification_result_screen.dart';
// import 'package:logger/logger.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:image/image.dart' as img;
// import 'package:flutter/material.dart';
// import 'dart:math' as math;

// // ml_service.dart

// final log = Logger();

// class ClassificationResult {
//   final String category;
//   final double confidence;

//   ClassificationResult({required this.category, required this.confidence});

//   @override
//   String toString() =>
//       'ClassificationResult(category: $category, confidence: $confidence)';
// }

// class MLService {
//   static const String modelName =
//       'waste-classify'; // Replace with your Firebase ML model name
//   Interpreter? _interpreter;
//   List<String> _labels = [];

//   // Define your waste categories - adjust these based on your model's output classes
//   static const List<String> wasteCategories = [
//     'Cardboard',
//     'Glass',
//     'Metal',
//     'Paper',
//     'Plastic',
//     'Trash',
//     // Add/modify categories based on your model
//   ];

//   /// Loads the model from Firebase ML
//   Future<void> _loadModel() async {
//     if (_interpreter != null) return;

//     try {
//       log.i('Downloading model from Firebase ML...');

//       // Download model from Firebase ML
//       final customModel = await FirebaseModelDownloader.instance.getModel(
//         modelName,
//         FirebaseModelDownloadType.latestModel,
//       );

//       log.i('Model downloaded, loading interpreter...');

//       // Create interpreter options for better compatibility
//       final options = InterpreterOptions();

//       // Set thread count for CPU execution
//       options.threads = 4;

//       // Load the TensorFlow Lite interpreter with options
//       _interpreter = Interpreter.fromFile(
//         File(customModel.file.path),
//         options: options,
//       );

//       _labels = wasteCategories;

//       log.i('Model loaded successfully');
//       log.i('Input shape: ${_interpreter!.getInputTensor(0).shape}');
//       log.i('Output shape: ${_interpreter!.getOutputTensor(0).shape}');

//       // Validate model compatibility
//       await _validateModel();
//     } catch (e) {
//       log.e('Error loading model: $e');

//       // Try loading without delegates as fallback
//       try {
//         log.i('Retrying without delegates...');
//         final customModel = await FirebaseModelDownloader.instance.getModel(
//           modelName,
//           FirebaseModelDownloadType.latestModel,
//         );

//         final basicOptions = InterpreterOptions();
//         basicOptions.threads = 2;

//         _interpreter = Interpreter.fromFile(
//           File(customModel.file.path),
//           options: basicOptions,
//         );

//         _labels = wasteCategories;
//         log.i('Model loaded with basic options');

//         await _validateModel();
//       } catch (fallbackError) {
//         log.e('Fallback loading failed: $fallbackError');
//         throw Exception(
//           'Failed to load model: $fallbackError. Please check if your model is compatible with the current TFLite version.',
//         );
//       }
//     }
//   }

//   /// Validates the loaded model
//   Future<void> _validateModel() async {
//     try {
//       final inputTensor = _interpreter!.getInputTensor(0);
//       final outputTensor = _interpreter!.getOutputTensor(0);

//       log.i('Model validation:');
//       log.i(
//         'Input tensor - Shape: ${inputTensor.shape}, Type: ${inputTensor.type}',
//       );
//       log.i(
//         'Output tensor - Shape: ${outputTensor.shape}, Type: ${outputTensor.type}',
//       );

//       // Validate input shape
//       if (inputTensor.shape.length != 4) {
//         throw Exception(
//           'Expected 4D input tensor, got ${inputTensor.shape.length}D',
//         );
//       }

//       // Validate output shape
//       if (outputTensor.shape.length != 2) {
//         throw Exception(
//           'Expected 2D output tensor, got ${outputTensor.shape.length}D',
//         );
//       }

//       // Check if number of classes matches
//       final numClasses = outputTensor.shape[1];
//       if (numClasses != wasteCategories.length) {
//         log.w(
//           'Model output classes ($numClasses) don\'t match defined categories (${wasteCategories.length})',
//         );
//         // Adjust categories list if needed
//         if (numClasses < wasteCategories.length) {
//           _labels = wasteCategories.take(numClasses).toList();
//         }
//       }

//       log.i('Model validation passed');
//     } catch (e) {
//       log.e('Model validation failed: $e');
//       throw Exception('Model validation failed: $e');
//     }
//   }

//   /// Main method to classify an image
//   Future<List<ClassificationResult>> classifyImage(String imagePath) async {
//     try {
//       // Ensure model is loaded
//       await _loadModel();

//       if (_interpreter == null) {
//         throw Exception('Model not loaded');
//       }

//       log.i('Starting image classification for: $imagePath');

//       // Preprocess the image
//       final inputTensor = await _preprocessImage(imagePath);

//       // Prepare output tensor
//       final outputShape = _interpreter!.getOutputTensor(0).shape;
//       final outputTensor = List.generate(
//         outputShape[0], // batch size
//         (index) => List.filled(outputShape[1], 0.0), // number of classes
//       );

//       // Run inference
//       log.i('Running inference...');
//       _interpreter!.run(inputTensor, outputTensor);

//       // Process results - take first batch
//       final results = _processResults(outputTensor[0]);

//       log.i('Classification completed. Results: $results');
//       return results;
//     } catch (e) {
//       log.e('Classification error: $e');
//       throw Exception('Classification failed: $e');
//     }
//   }

//   /// Preprocesses the image for model input
//   Future<List<List<List<List<double>>>>> _preprocessImage(
//     String imagePath,
//   ) async {
//     try {
//       final imageFile = File(imagePath);
//       if (!await imageFile.exists()) {
//         throw Exception('Image file does not exist: $imagePath');
//       }

//       final bytes = await imageFile.readAsBytes();
//       final image = img.decodeImage(bytes);

//       if (image == null) {
//         throw Exception('Failed to decode image');
//       }

//       // Get model input shape
//       final inputShape = _interpreter!.getInputTensor(0).shape;
//       final batchSize = inputShape[0];
//       final height = inputShape[1];
//       final width = inputShape[2];
//       final channels = inputShape[3];

//       log.i(
//         'Model expects input: batch=$batchSize, height=$height, width=$width, channels=$channels',
//       );
//       log.i('Original image size: ${image.width}x${image.height}');

//       // Resize image to match model input size
//       final resized = img.copyResize(image, width: width, height: height);

//       // Convert to the format expected by your model
//       final input = List.generate(
//         batchSize, // batch size (usually 1)
//         (batch) => List.generate(
//           height,
//           (y) => List.generate(
//             width,
//             (x) => List.generate(channels, (c) {
//               // Handle different channel configurations
//               final pixel = resized.getPixel(x, y);

//               // Extract RGB values from the pixel integer
//               final r = pixel.r.toDouble();
//               final g = pixel.g.toDouble();
//               final b = pixel.b.toDouble();

//               double value;

//               if (channels == 3) {
//                 // RGB
//                 switch (c) {
//                   case 0:
//                     value = r.toDouble();
//                     break;
//                   case 1:
//                     value = g.toDouble();
//                     break;
//                   case 2:
//                     value = b.toDouble();
//                     break;
//                   default:
//                     value = 0.0;
//                 }
//               } else if (channels == 1) {
//                 // Grayscale
//                 value = (r * 0.299 + g * 0.587 + b * 0.114);
//               } else {
//                 throw Exception('Unsupported number of channels: $channels');
//               }

//               // Normalize pixel values to [0, 1] range
//               // Some models might need [-1, 1] range: (value / 127.5) - 1.0
//               // Or standardization: (value - mean) / std
//               return value / 255.0;
//             }),
//           ),
//         ),
//       );

//       log.i('Image preprocessed successfully');
//       return input;
//     } catch (e) {
//       log.e('Image preprocessing error: $e');
//       throw Exception('Failed to preprocess image: $e');
//     }
//   }

//   /// Processes the raw model output into classification results
//   List<ClassificationResult> _processResults(List<double> probabilities) {
//     final results = <ClassificationResult>[];

//     log.i('Raw probabilities: $probabilities');

//     // Apply softmax if probabilities don't sum to ~1
//     final sum = probabilities.fold<double>(0.0, (a, b) => a + b);
//     List<double> normalizedProbs = probabilities;

//     if (sum > 1.1 || sum < 0.9) {
//       log.i('Applying softmax normalization, sum was: $sum');
//       normalizedProbs = _softmax(probabilities);
//     }

//     // Create results for each category
//     for (int i = 0; i < normalizedProbs.length && i < _labels.length; i++) {
//       results.add(
//         ClassificationResult(
//           category: _labels[i],
//           confidence: normalizedProbs[i],
//         ),
//       );
//     }

//     // Sort by confidence (highest first)
//     results.sort((a, b) => b.confidence.compareTo(a.confidence));

//     return results;
//   }

//   /// Apply softmax normalization
//   List<double> _softmax(List<double> logits) {
//     final maxLogit = logits.reduce((a, b) => a > b ? a : b);
//     final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
//     final sumExp = expValues.fold<double>(0.0, (a, b) => a + b);
//     return expValues.map((x) => x / sumExp).toList();
//   }

//   /// Gets the top prediction
//   Future<ClassificationResult?> getTopPrediction(String imagePath) async {
//     final results = await classifyImage(imagePath);
//     return results.isNotEmpty ? results.first : null;
//   }

//   /// Gets predictions above a certain confidence threshold
//   Future<List<ClassificationResult>> getConfidentPredictions(
//     String imagePath, {
//     double threshold = 0.8,
//   }) async {
//     final results = await classifyImage(imagePath);
//     return results.where((result) => result.confidence >= threshold).toList();
//   }

//   /// Checks if model is ready
//   bool get isModelLoaded => _interpreter != null;

//   /// Disposes of the interpreter to free up resources
//   void dispose() {
//     _interpreter?.close();
//     _interpreter = null;
//     log.i('ML Service disposed');
//   }
// }

// // Integration with your existing ClassificationResultScreen:
// class HomeScreenIntegration {
//   final MLService _mlService = MLService();

//   Future<void> classifyAndShowResult(
//     BuildContext context,
//     String imagePath,
//   ) async {
//     try {
//       // Show loading dialog
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => const Dialog(
//           child: Padding(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(),
//                 SizedBox(height: 16),
//                 Text('Analyzing image...'),
//               ],
//             ),
//           ),
//         ),
//       );

//       // Classify the image
//       final results = await _mlService.classifyImage(imagePath);

//       // Close loading dialog
//       if (context.mounted) {
//         Navigator.of(context).pop();
//       }

//       if (results.isNotEmpty) {
//         final topResult = results.first;

//         // Show your classification result screen
//         if (context.mounted) {
//           showClassificationResult(
//             context,
//             imagePath: imagePath,
//             category: topResult.category,
//             confidence: topResult.confidence,
//             recyclingInstructions: RecyclingInstructions.getInstructions(
//               topResult.category,
//             ),
//           );
//         }
//       } else {
//         if (context.mounted) {
//           _showErrorDialog(context, 'No classification results found');
//         }
//       }
//     } catch (e) {
//       // Close loading dialog if it's still open
//       if (context.mounted) {
//         Navigator.of(context).pop();
//         _showErrorDialog(context, 'Classification failed: ${e.toString()}');
//       }
//     }
//   }

//   void _showErrorDialog(BuildContext context, String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Error'),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   void dispose() {
//     _mlService.dispose();
//   }
// }
