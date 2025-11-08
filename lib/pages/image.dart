import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'dart:io'; // No longer needed directly for File if using bytes primarily
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter/foundation.dart' show kIsWeb; // To check platform if needed, though not strictly required for this specific fix
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType

class ClassificationPage extends StatefulWidget {
  const ClassificationPage({super.key});

  @override
  State<ClassificationPage> createState() => _ClassificationPageState();
}

class _ClassificationPageState extends State<ClassificationPage> {
  // --- Configuration ---
  final String apiUrl = 'http://127.0.0.1:5000/predict'; // <--- CHANGE THIS IP

  // --- State Variables ---
  // File? _imageFile; // Replace File with bytes
  Uint8List? _imageBytes; // To store image data for web and mobile
  String? _imageName; // Store the filename for the upload request
  String _predictionResult = 'Get your face close and face the camera headon.';
  double? _probability;
  bool _isLoading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  // --- Methods ---

  // Function to pick an image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes(); // Read bytes directly
        final name = pickedFile.name; // Get the filename
        setState(() {
          // _imageFile = File(pickedFile.path); // Don't store File object
          _imageBytes = bytes; // Store bytes
          _imageName = name;   // Store name
          _predictionResult = 'Image selected. Press Classify.';
          _probability = null;
          _errorMessage = null;
        });
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image selection cancelled.')),
          );
         }
      }
    } catch (e) {
      print("Error picking image: $e");
      setState(() {
        _errorMessage = "Error picking image: $e";
        _isLoading = false;
      });
    }
  }

  // Function to upload the image and get classification
  Future<void> _uploadAndClassify() async {
    // if (_imageFile == null) { // Check bytes instead
    if (_imageBytes == null || _imageName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _predictionResult = 'Classifying...';
      _probability = null;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Attach the file using bytes
      request.files.add(
        // await http.MultipartFile.fromPath( // Use fromBytes instead
        //   'image',
        //   _imageFile!.path,
        //   contentType: MediaType('image', 'jpeg'),
        // ),
        http.MultipartFile.fromBytes(
          'image', // Field name MUST match Flask
          _imageBytes!, // The image byte data
          filename: _imageName!, // Provide a filename (required for fromBytes)
          contentType: MediaType('image', 'jpeg'), // Adjust if needed (png, etc.)
        ),
      );

      // Send request (timeout is good practice)
      print("Sending request to $apiUrl with image: $_imageName");
      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));

      // Get response
      var response = await http.Response.fromStream(streamedResponse);
      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var decodedResponse = jsonDecode(response.body);
        final String prediction = decodedResponse['prediction']; // Get the prediction string
        final double probability = decodedResponse['probability']?.toDouble() ?? 0.0;

        // Option 1: Update state locally AND pop with result (good for immediate feedback)
        setState(() {
          _predictionResult = "Prediction: $prediction";
          _probability = probability;
          _isLoading = false; // Stop loading indicator BEFORE popping
        });

        // Pop the screen and return the prediction result string
        // Check if the widget is still mounted before popping
        if (mounted) {
          Navigator.pop(context, prediction); // <-- RETURN THE RESULT HERE
        }


        // Option 2: Just pop with the result (MainMenu will handle displaying feedback if needed)
        // _isLoading = false; // Still good to set this
        // if (mounted) {
        //   Navigator.pop(context, prediction);
        // }

      } else {
         // ... existing error handling ...
         // Make sure to set isLoading to false in error cases too
         setState(() {
            _isLoading = false;
            // ... other error state updates ...
         });
         // Do NOT pop automatically on error, let the user see the error message.
      }
    } on SocketException catch (e) {
       // ... existing error handling ...
       setState(() { _isLoading = false; /* ... */ });
    } on TimeoutException catch (e) {
       // ... existing error handling ...
       setState(() { _isLoading = false; /* ... */ });
    } catch (e) {
      // ... existing error handling ...
      // Ensure isLoading is set to false even if an unexpected error happens before setState
      if (_isLoading) {
          setState(() { _isLoading = false; });
      
    }
    // Remove the finally block that sets isLoading=false if you handle it in all paths above
    // finally {
    //   if (mounted && _isLoading) { // Only set if still loading (might have been set false already)
    //     setState(() {
    //       _isLoading = false;
    //     });
    //   }
    // }

    } on SocketException catch (e) {
       print("Network Error: $e");
       setState(() {
         _errorMessage = "Network Error: Could not connect to the server. Check IP address and ensure the server is running.";
         _predictionResult = 'Classification failed.';
       });
    } on TimeoutException catch (e) {
       print("Timeout Error: $e");
       setState(() {
         _errorMessage = "Request timed out. The server might be busy or unreachable.";
         _predictionResult = 'Classification failed.';
       });
    } catch (e) {
      print("Error during classification: $e");
      setState(() {
        _errorMessage = "An unexpected error occurred: $e";
        _predictionResult = 'Classification failed.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hyper Sebaceous Classifier (Web Compatible)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Image Display Area (Using Image.memory)
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        // Replace Image.file with Image.memory
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print("Error displaying image bytes: $error");
                            return const Center(child: Text('Error loading image preview'));
                          },
                        ),
                      )
                    : const Center(
                        child: Text(
                          'No Image Selected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Image Picker Buttons (No change needed here)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),

                ],
              ),
              const SizedBox(height: 20),

              // Classify Button (Check _imageBytes instead of _imageFile)
              ElevatedButton(
                onPressed: (_imageBytes != null && !_isLoading) ? _uploadAndClassify : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Classify Image'),
              ),
              const SizedBox(height: 30),

              // Loading Indicator and Results (No change needed here)
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                Text(
                  _predictionResult,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                if (_probability != null)
                  Text(
                    'Probability (Normal): ${(_probability! * 100).toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey),
                    textAlign: TextAlign.center,
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 15),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ]
              ],
            ],
          ),
        ),
      ),
    );
  }
}