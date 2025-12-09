// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_application_1/model/waste_classify_model.dart';
// import 'package:flutter_application_1/service/recycling_inst.dart';
// import 'package:flutter_application_1/user_screen/not_using/classification_result_screen.dart';
// import 'package:flutter_application_1/user_screen/not_using/homecontent.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:logger/web.dart';

// class Classifywaste extends StatefulWidget {
//   const Classifywaste({super.key});

//   @override
//   State<Classifywaste> createState() => _ClassifywasteState();
// }

// final MLService _mlService = MLService();

// class _ClassifywasteState extends State<Classifywaste> {
//   File? image;

//   final log = Logger();
//   Future<void> _classifyAndNavigate(
//     File imageFile,
//     BuildContext context,
//   ) async {
//     final navigator = Navigator.of(context);
//     try {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const Center(child: CircularProgressIndicator()),
//       );

//       final result = await _mlService.getTopPrediction(imageFile.path);
//       if (!mounted) return;
//       navigator.pop(); // close the loading dialog

//       if (result != null) {
//         if (!mounted) return;
//         navigator.push(
//           MaterialPageRoute(
//             builder: (_) => ClassificationResultScreen(
//               imagePath: imageFile.path,
//               category: result.category,
//               confidence: result.confidence,
//               recyclingInstructions: RecyclingInstructions.getInstructions(
//                 result.category,
//               ),
//               onDone: () {
//                 setState(() {
//                   image = null;
//                 });
//               },
//             ),
//           ),
//         );
//       } else {
//         if (!mounted) return;
//         _showError(context, 'No classification result found');
//       }
//     } catch (e) {
//       navigator.pop(); // close dialog
//       _showError(context, 'Classification failed: $e');
//     }
//   }

//   void _showError(BuildContext context, String message) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Error'),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future pickImage(ImageSource source) async {
//     try {
//       final pickedImage = await ImagePicker().pickImage(source: source);
//       if (pickedImage == null) return;
//       final imageTemporary = File(pickedImage.path);
//       setState(() {
//         image = imageTemporary;
//       });
//     } on PlatformException catch (e) {
//       log.e('Failed to pick image: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: HomeContent(
//         image: image,
//         pickImageCallback: pickImage,
//         onSubmit: () async {
//           if (image != null) {
//             await _classifyAndNavigate(image!, context);
//           }
//         },
//       ),
//     );
//   }
// }
