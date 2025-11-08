import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Add Storage

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Keep for icons
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:uuid/uuid.dart'; // For unique image names

// --- Data Structure for Company Locations ---
class CompanyLocation {
  String name;
  String imageUrl;
  GeoPoint geopoint; // Use Firestore GeoPoint

  CompanyLocation({required this.name, required this.imageUrl, required this.geopoint});

  // For saving/loading from SharedPreferences (via JSON)
  Map<String, dynamic> toJson() => {
        'name': name,
        'imageUrl': imageUrl,
        'latitude': geopoint.latitude,
        'longitude': geopoint.longitude,
      };

  factory CompanyLocation.fromJson(Map<String, dynamic> json) => CompanyLocation(
        name: json['name'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        geopoint: GeoPoint(json['latitude'] ?? 0.0, json['longitude'] ?? 0.0),
      );
}


class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  int _currentStep = 0;
  String? _userId; // Firebase Auth User UID

  // --- Firebase Instances ---
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _uuid = Uuid(); // For generating unique IDs

  // --- Step 0: Auth State ---
  final _step0FormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(); // Single username
  final _emailAuthController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoadingAuth = false;
  bool _passwordVisible = false; // State for password visibility

  // --- Step 1: Common Info State ---
  final _step1FormKey = GlobalKey<FormState>();
  final _fullnameController = TextEditingController();
  final _phonenumberController = TextEditingController();
  final _ageController = TextEditingController(); // MOVED Age to Step 1
  // Location
  // **MODIFIED**: Controller for MANUAL address input
  final _locationAddressController = TextEditingController();
  late final MapController _mapController;
  LatLng? _selectedMapLatLng; // Use LatLng for map interaction
  GeoPoint? _selectedGeoPoint; // Use GeoPoint for Firestore (coordinates only)
  LatLng _mapCenter = const LatLng(28.6139, 77.2090); // Default map center
  bool _isLoadingLocation = false; // Kept for Get Current Location button action

  // --- Step 2: Specific Info State ---
  final _step2FormKey = GlobalKey<FormState>();
  bool _isCompany = false;

  // Profile Image/Logo
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // Individual Fields (Controllers kept for potential future use, but not used in individual sign-up flow)
  final _professionController = TextEditingController();
  final _languagesController = TextEditingController();
  final _skillsController = TextEditingController();

  // Company Fields
  final _companyNameController = TextEditingController();
  final _companyDescriptionController = TextEditingController();
  final _companyDomainsController = TextEditingController();
  List<CompanyLocation> _companyLocations = [];
  // Temp controllers for adding a new location
  final _newLocationNameController = TextEditingController();
  final _newLocationImageUrlController = TextEditingController();
  LatLng? _newLocationLatLng;

  bool _isSubmittingFinal = false;

  // --- SharedPreferences Keys ---
  static const _prefStep = 'SignUp_current_step';
  static const _prefUserId = 'SignUp_user_id';
  static const _prefUsername = 'SignUp_username';
  static const _prefAuthEmail = 'SignUp_email';
  static const _prefFullName = 'SignUp_fullname';
  static const _prefPhone = 'SignUp_phone';
  static const _prefAge = 'SignUp_age';
  // **MODIFIED**: Key for manually entered address
  static const _prefLocationAddress = 'SignUp_location_address';
  // Keys for coordinates are still needed
  static const _prefLocationLat = 'SignUp_location_lat';
  static const _prefLocationLng = 'SignUp_location_lng';
  static const _prefIsCompany = 'SignUp_is_company';
  static const _prefImageBase64 = 'SignUp_image_base64';
  static const _prefProfession = 'SignUp_profession';
  static const _prefLanguages = 'SignUp_languages';
  static const _prefSkills = 'SignUp_skills';
  static const _prefCompanyName = 'SignUp_company_name';
  static const _prefCompanyDesc = 'SignUp_company_desc';
  static const _prefCompanyDomains = 'SignUp_company_domains';
  static const _prefCompanyLocations = 'SignUp_company_locations';


  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadSavedData();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _usernameController.dispose();
    _emailAuthController.dispose();
    _passwordController.dispose();
    _fullnameController.dispose();
    _phonenumberController.dispose();
    _ageController.dispose();
    // **MODIFIED**: Dispose new address controller name
    _locationAddressController.dispose();
    _professionController.dispose();
    _languagesController.dispose();
    _skillsController.dispose();
    _companyNameController.dispose();
    _companyDescriptionController.dispose();
    _companyDomainsController.dispose();
    _newLocationNameController.dispose();
    _newLocationImageUrlController.dispose();
    super.dispose();
  }

  // --- SharedPreferences Logic ---

  Future<void> _saveStepData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefStep, _currentStep);
    if (_userId != null) await prefs.setString(_prefUserId, _userId!);

    // Step 0 data
    await prefs.setString(_prefUsername, _usernameController.text);
    await prefs.setString(_prefAuthEmail, _emailAuthController.text);

    // Step 1 data
    await prefs.setString(_prefFullName, _fullnameController.text);
    await prefs.setString(_prefPhone, _phonenumberController.text);
    await prefs.setString(_prefAge, _ageController.text);
    // **MODIFIED**: Save manual address text
    await prefs.setString(_prefLocationAddress, _locationAddressController.text);
    // Save coordinates separately
     if (_selectedMapLatLng != null) {
      await prefs.setDouble(_prefLocationLat, _selectedMapLatLng!.latitude);
      await prefs.setDouble(_prefLocationLng, _selectedMapLatLng!.longitude);
    } else {
      await prefs.remove(_prefLocationLat);
      await prefs.remove(_prefLocationLng);
    }

    // Step 2 data
    await prefs.setBool(_prefIsCompany, _isCompany);
    if (_imageBytes != null) {
      await prefs.setString(_prefImageBase64, base64Encode(_imageBytes!));
    } else {
      await prefs.remove(_prefImageBase64);
    }

    if (_isCompany) {
      await prefs.setString(_prefCompanyName, _companyNameController.text);
      await prefs.setString(_prefCompanyDesc, _companyDescriptionController.text);
      await prefs.setString(_prefCompanyDomains, _companyDomainsController.text);
      final locationsJson = jsonEncode(_companyLocations.map((loc) => loc.toJson()).toList());
      await prefs.setString(_prefCompanyLocations, locationsJson);
      await prefs.remove(_prefProfession);
      await prefs.remove(_prefLanguages);
      await prefs.remove(_prefSkills);
    } else {
      await prefs.remove(_prefCompanyName);
      await prefs.remove(_prefCompanyDesc);
      await prefs.remove(_prefCompanyDomains);
      await prefs.remove(_prefCompanyLocations);
    }
     print("Saved Step $_currentStep data. isCompany: $_isCompany");
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentStep = prefs.getInt(_prefStep) ?? 0;
      _userId = prefs.getString(_prefUserId);

      // Step 0
      _usernameController.text = prefs.getString(_prefUsername) ?? '';
      _emailAuthController.text = prefs.getString(_prefAuthEmail) ?? '';

      // Step 1
      _fullnameController.text = prefs.getString(_prefFullName) ?? '';
      _phonenumberController.text = prefs.getString(_prefPhone) ?? '';
      _ageController.text = prefs.getString(_prefAge) ?? '';
      // **MODIFIED**: Load manual address text
      _locationAddressController.text = prefs.getString(_prefLocationAddress) ?? '';
      // Load coordinates
      final lat = prefs.getDouble(_prefLocationLat);
      final lng = prefs.getDouble(_prefLocationLng);
      if (lat != null && lng != null) {
        _selectedMapLatLng = LatLng(lat, lng);
        _selectedGeoPoint = GeoPoint(lat, lng);
        _mapCenter = _selectedMapLatLng!;
      }

      // Step 2
      _isCompany = prefs.getBool(_prefIsCompany) ?? false;
      final base64Image = prefs.getString(_prefImageBase64);
      if (base64Image != null) {
        _imageBytes = base64Decode(base64Image);
      }

      if (_isCompany) {
        _companyNameController.text = prefs.getString(_prefCompanyName) ?? '';
        _companyDescriptionController.text = prefs.getString(_prefCompanyDesc) ?? '';
        _companyDomainsController.text = prefs.getString(_prefCompanyDomains) ?? '';
         final locationsJson = prefs.getString(_prefCompanyLocations);
         if (locationsJson != null) {
           try {
              final decodedList = jsonDecode(locationsJson) as List;
              _companyLocations = decodedList.map((item) => CompanyLocation.fromJson(item)).toList();
           } catch (e) {
             print("Error decoding company locations: $e");
             _companyLocations = [];
           }
         } else {
           _companyLocations = [];
         }
      } else {
        _professionController.text = prefs.getString(_prefProfession) ?? '';
        _languagesController.text = prefs.getString(_prefLanguages) ?? '';
        _skillsController.text = prefs.getString(_prefSkills) ?? '';
      }
    });
     if (_selectedMapLatLng != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {

       });
     }
      print("Loaded saved data. Current Step: $_currentStep, isCompany: $_isCompany");
  }

  Future<void> _clearSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    const keys = {
      _prefStep, _prefUserId, _prefUsername, _prefAuthEmail, _prefFullName, _prefPhone,
      _prefAge,
      // **MODIFIED**: Include manual address key
      _prefLocationAddress,
      _prefLocationLat, _prefLocationLng, _prefIsCompany,
      _prefImageBase64,
      _prefProfession, _prefLanguages, _prefSkills,
      _prefCompanyName, _prefCompanyDesc, _prefCompanyDomains, _prefCompanyLocations
    };
    for (final key in keys) {
      await prefs.remove(key);
    }
     print("Cleared SharedPreferences data.");
  }

  // --- Step Logic ---

  Future<void> _performFirebaseAuth() async {
    if (_step0FormKey.currentState!.validate()) {
      setState(() => _isLoadingAuth = true);
      try {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: _emailAuthController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (credential.user != null) {
          _userId = credential.user!.uid;
           print("Firebase Auth User Created: UID: $_userId");

          try {
            await credential.user!.sendEmailVerification();
            print("Verification email sent to ${_emailAuthController.text.trim()}");
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text("Account created! Please check your email to verify your address. Proceeding with profile setup."),
                   backgroundColor: Colors.green,
                   duration: Duration(seconds: 5),
                 ),
               );
             }
          } catch (e) {
             print("Error sending verification email: $e");
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Text("Account created, but failed to send verification email: $e."),
                   backgroundColor: Colors.orangeAccent,
                   duration: Duration(seconds: 5),
                 ),
               );
             }
          }

          setState(() => _currentStep = 1);
          await _saveStepData();
          print("Moved to Step 1, saved data.");

        } else {
           print("FirebaseAuth Error: User object was null after creation.");
           throw Exception("User object was null after creation.");
        }

      } on FirebaseAuthException catch (e) {
        print("FirebaseAuthException: ${e.code} - ${e.message}");
        String errorMessage = "SignUp failed. Please try again.";
        // ... [Error handling unchanged] ...
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'An account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        } else {
           errorMessage = e.message ?? errorMessage;
         }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        print("Unexpected error during FirebaseAuth: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("An unexpected error occurred: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingAuth = false);
        }
      }
    } else {
      print("Step 0 Form Validation Failed");
    }
  }

  Future<void> _getCurrentLocation() async {
    // This function now ONLY gets coordinates and updates the map marker/center.
    // It does NOT update the address text field.
    setState(() => _isLoadingLocation = true);
    try {
      // ... [Permission checks unchanged] ...
       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services disabled.");
        throw Exception('Location services are disabled. Please enable them in your device settings.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
             print("Location permission denied.");
            throw Exception('Location permission denied. Please allow location access.');
          }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permission permanently denied.");
        throw Exception('Location permission is permanently denied. Please enable it in your app settings.');
      }
      print("Location permission granted.");


      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15)
      );
      print("Fetched current location: Lat: ${position.latitude}, Lng: ${position.longitude}");

      final newLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _mapCenter = newLatLng;
        _selectedMapLatLng = newLatLng;
        _selectedGeoPoint = GeoPoint(position.latitude, position.longitude);
        // Clear the manual address field when using current location? Optional.
        // _locationAddressController.clear();

      });

      // **REMOVED**: Do not automatically geocode and set address text.
      // await _getAndSetLocationName(position.latitude, position.longitude);

      await _saveStepData(); // Save updated coordinates
      print("Updated location coordinates and saved data.");
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Location coordinates updated. Please enter the address manually if needed.'), duration: Duration(seconds: 3),)
         );
      }


    } catch (e) {
       print("Error getting location: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting location: ${e.toString()}')));
       }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // _getAndSetLocationName is NO LONGER USED in Step 1 for the main address.
  // Keep it if it might be useful elsewhere (e.g., Company Location adding).
  Future<void> _getAndSetLocationName(double lat, double lng) async {
     // ... [Function definition unchanged, but call removed from Step 1 map tap and _getCurrentLocation] ...
     print("Geocoding coordinates: Lat: $lat, Lng: $lng");
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country
        ].where((s) => s != null && s.isNotEmpty).join(', ');
         print("Geocoded address: $address");
         // **IMPORTANT**: This function should no longer modify _locationAddressController directly in the Step 1 context.
         // If used elsewhere, adapt the target controller/state.
         // setState(() {
         //   _locationAddressController.text = address.isNotEmpty ? address : "Location Name Unavailable";
         // });
      } else {
         print("Geocoding returned no placemarks.");
         // setState(() { _locationAddressController.text = "Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}"; });
      }
    } catch (e) {
       print("Error during geocoding: $e");
       // setState(() { _locationAddressController.text = "Error getting address. Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}"; });
    }
  }

  // --- Image Handling --- (Unchanged)
  Future<void> _pickImage() async { /* ... */
     ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          actions: [
             TextButton(onPressed: () => Navigator.pop(context, ImageSource.camera), child: const Text('Camera')),
             TextButton(onPressed: () => Navigator.pop(context, ImageSource.gallery), child: const Text('Gallery')),
          ],
        ),
    );

    if (source == null) {
        print("Image source selection cancelled.");
        return;
    }

    print("Picking image from ${source.name}");
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        print("Image picked: ${pickedFile.path}");
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
        await _saveStepData();
        print("Image bytes saved to SharedPreferences.");
      } else {
         print("Image picking cancelled or failed.");
      }
    } catch (e) {
       print("Image picking error: $e");
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image picking error: $e')));
       }
    }
  }
  Future<String?> _uploadProfileImage(Uint8List imageBytes, String userId) async { /* ... */
     print("Uploading profile image for user: $userId");
     try {
       String fileExtension = 'jpg';
       String fileName = '${_uuid.v4()}.$fileExtension';
       Reference ref = _storage.ref('profile_images/$userId/$fileName');
       print("Uploading to Storage path: ${ref.fullPath}");

       UploadTask uploadTask = ref.putData(
           imageBytes,
           SettableMetadata(contentType: 'image/jpeg')
        );

       TaskSnapshot snapshot = await uploadTask;
       String downloadUrl = await snapshot.ref.getDownloadURL();
       print("Image uploaded successfully. Download URL: $downloadUrl");
       return downloadUrl;
     } catch (e) {
       print("Failed to upload profile image: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Failed to upload profile image: $e"), backgroundColor: Colors.red),
         );
       }
       return null;
     }
  }

  // --- Final Submission ---
  Future<void> _submitFinalForm() async {
     print("Attempting final form submission...");
     bool isStep2Valid = _isCompany ? (_step2FormKey.currentState?.validate() ?? false) : true;
     print("Step 2 Validation (Required only if Company): $isStep2Valid");

    if (isStep2Valid && _userId != null) {
      setState(() => _isSubmittingFinal = true);
      String? uploadedImageUrl;

      try {
        // 1. Upload Image if exists (Unchanged)
        if (_imageBytes != null) {
          uploadedImageUrl = await _uploadProfileImage(_imageBytes!, _userId!);
          if (uploadedImageUrl == null) {
             throw Exception("Image upload failed. Cannot proceed.");
          }
        }

        // 2. Prepare Base Data (Unchanged)
        Map<String, dynamic> userData = {
           'username': _usernameController.text.trim(),
           'email': _emailAuthController.text.trim(),
           'phoneNb': _phonenumberController.text.trim(),
           'isCompany': _isCompany,
           'imageUrl': uploadedImageUrl,
           'createdAt': FieldValue.serverTimestamp(),
        };
         print("Prepared base user data. isCompany: $_isCompany");

        // 3. Add Specific Data
        if (_isCompany) {
          final companyData = {
            'companyName': _companyNameController.text.trim(),
            'description': _companyDescriptionController.text.trim(),
            'domains': _companyDomainsController.text.trim()
                         .split(',')
                         .map((s) => s.trim())
                         .where((s) => s.isNotEmpty)
                         .toList(),
            'locations': _companyLocations.map((loc) => loc.toJson()).toList(), // Use toJson
            'primaryLocationGeoPoint': _selectedGeoPoint, // GeoPoint from map selection
            // **MODIFIED**: Use manual address text
            'primaryLocationAddress': _locationAddressController.text.trim(),
          };
          userData.addAll(companyData);
           print("Added company-specific data.");
        } else {
           int? age = int.tryParse(_ageController.text.trim());
           final individualData = {
             'realName': _fullnameController.text.trim(),
             'age': age,
             'locationGeoPoint': _selectedGeoPoint, // GeoPoint from map selection
             // **MODIFIED**: Use manual address text
             'locationAddress': _locationAddressController.text.trim(),
             // Other individual fields (profession, etc.) are not collected here
           };
          userData.addAll(individualData);
           print("Added individual-specific data (Name, Age, Location Address, GeoPoint).");
        }

        // 4. Write to Firestore (Unchanged)
         print("Writing user data to Firestore for user: $_userId");
         print("Data: $userData");
        await _firestore.collection('users').doc(_userId!).set(userData);
         print("Firestore write successful.");

        // 5. Clear and Navigate (Unchanged)
        await _clearSavedData();
        if (!mounted) return;
        print("Navigating to Success Page.");
        Navigator.of(context).pushAndRemoveUntil( /* ... Navigation ... */
           MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text("SignUp Success!")),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Welcome, ${userData['username']}!"),
                    Text("Account created for: ${userData['email']}"),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('login');
                      },
                      child: const Text('Continue to Login'),
                    )
                  ],
                ),
              )
            ),
          ),
          (Route<dynamic> route) => false,
        );

      } catch (e) {
         print("Error during final submission or Firestore write: $e");
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Failed to save profile: $e"), backgroundColor: Colors.red),
           );
         }
      } finally {
        if (mounted) {
          setState(() => _isSubmittingFinal = false);
        }
      }
    } else if (_userId == null) {
        print("Submission Error: User ID is null.");
        if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("User ID not found. Please go back and try creating the account again."), backgroundColor: Colors.red),
         );
       }
       setState(() => _currentStep = 0);
    } else {
       print("Step 2 Company Form Validation Failed");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Please fill all required company fields correctly."), backgroundColor: Colors.orange),
         );
       }
    }
  }


  // --- Navigation --- (Unchanged)
  void _nextStep() async {
    print("Next Step button pressed. Current Step: $_currentStep");
    bool valid = false;

    if (_currentStep == 0) {
       print("Validating Step 0 Form...");
      await _performFirebaseAuth();
      return;
    } else if (_currentStep == 1) {
       print("Validating Step 1 Form...");
      valid = _step1FormKey.currentState?.validate() ?? false;
      print("Step 1 Form Validation Result: $valid");
      // **MODIFIED**: Add check for the manual address field if it's required
      if (valid && _locationAddressController.text.trim().isEmpty) {
          print("Validation Failed: Address is empty.");
           if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter your primary address."), backgroundColor: Colors.orange));
         }
         return; // Require address input
      }
      if (valid && _selectedGeoPoint == null) {
         print("Validation Failed: Location coordinates not selected.");
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a location on the map to set coordinates."), backgroundColor: Colors.orange));
         }
         return; // Location coordinates still required
      }
       print("Address entered and location coordinates selected (or validation failed earlier).");
    } else if (_currentStep == 2) {
       print("Attempting final submission from Step 2...");
      await _submitFinalForm();
      return;
    }

    if (valid && _currentStep < 2) {
       print("Moving to next step (from $_currentStep to ${_currentStep + 1})");
      setState(() { _currentStep++; });
      await _saveStepData();
       print("Saved data for new step: $_currentStep");
    } else if (!valid && _currentStep < 2) {
       print("Validation failed for Step $_currentStep, staying on current step.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields correctly."), backgroundColor: Colors.orange),
        );
      }
    }
  }
  void _previousStep() async { /* ... Unchanged ... */
     print("Previous Step button pressed. Current Step: $_currentStep");
    if (_currentStep > 0) {
       await _saveStepData();
        print("Saved data before going back from Step $_currentStep.");
      setState(() {
        _currentStep--;
         print("Moved back to Step $_currentStep.");
      });
    } else {
       print("Already on first step, navigating back to login.");
      Navigator.of(context).pushReplacementNamed("login");
    }
  }

   // --- UI Building ---

  // Helper for standard text form field decoration (Unchanged)
  InputDecoration _buildInputDecoration(String labelText, String hintText, IconData? prefixIconData, {Widget? suffixIcon}) { /* ... */
     return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIconData != null ? Icon(prefixIconData, size: 20) : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red.shade700),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
    );
  }

  @override
  Widget build(BuildContext context) { // (Unchanged)
    /* ... Structure remains the same ... */
    final size = MediaQuery.of(context).size;
    final isWeb = size.width >= 800;

    String nextButtonText = "Next";
    if (_currentStep == 0) nextButtonText = "Create Account & Next";
    if (_currentStep == 2) nextButtonText = "Finish SignUp";

    String appBarTitle = 'SignUp: Step ${_currentStep + 1} of 3';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(appBarTitle, style: GoogleFonts.quicksand(color: Colors.grey[600], fontSize: 16)),
        centerTitle: true,
        leading: _currentStep == 0
            ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black54), tooltip: "Back to Login", onPressed: () => Navigator.of(context).pushReplacementNamed("login"))
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 700 : size.width * 0.95),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final offsetAnimation = Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
                        .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offsetAnimation, child: child),
                    );
                  },
                  child: Container(
                    key: ValueKey<int>(_currentStep),
                    child: _buildStepContent(context, isWeb, size),
                  ),
                ),
                const SizedBox(height: 40),
                _buildNavigationButtons(nextButtonText),
                const SizedBox(height: 20),
                if (_currentStep == 0)
                  InkWell(
                    onTap: () => Navigator.of(context).pushReplacementNamed("login"),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: "Already have an account? ", style: GoogleFonts.quicksand(fontSize: isWeb ? 16 : 14)),
                          TextSpan(
                            text: "Login",
                            style: GoogleFonts.quicksand(color: const Color.fromARGB(255, 70, 107, 139), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Selects the content widget based on the current step (Unchanged)
  Widget _buildStepContent(BuildContext context, bool isWeb, Size size) { /* ... */
     switch (_currentStep) {
      case 0: return _buildStep0(context, isWeb, size);
      case 1: return _buildStep1(context, isWeb, size);
      case 2: return _buildStep2(context, isWeb, size);
      default: return const Center(child: Text("Unknown Step"));
    }
  }

  // --- Step Specific Widgets ---

  Widget _buildStep0(BuildContext context, bool isWeb, Size size) { // (Unchanged)
    /* ... Auth form ... */
     return Form(
      key: _step0FormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/skill4.jpg', width: isWeb ? 250 : size.width * 0.6, fit: BoxFit.contain),
          SizedBox(height: isWeb ? 30 : 15),
          Text('Step 1: Create Account', style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: isWeb ? 10 : 5),
          Text('Create your Account', style: GoogleFonts.quicksand(fontSize: isWeb ? 24: 20, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 70, 107, 139))),
          SizedBox(height: isWeb ? 30 : 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: isWeb ? 400 : size.width * 0.85,
              child: TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.name,
                decoration: _buildInputDecoration(
                  'Username', 'Choose a username', FontAwesomeIcons.user,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Username cannot be empty" : null,
                onChanged: (value) => _saveStepData(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: isWeb ? 400 : size.width * 0.85,
              child: TextFormField(
                controller: _emailAuthController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  'Email address', 'Email address', FontAwesomeIcons.envelope,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Email cannot be empty";
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) return "Enter a valid email";
                  return null;
                },
                onChanged: (value) => _saveStepData(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: isWeb ? 400 : size.width * 0.85,
              child: TextFormField(
                controller: _passwordController,
                keyboardType: TextInputType.visiblePassword,
                obscureText: !_passwordVisible,
                decoration: _buildInputDecoration(
                  'Password', 'Enter your Password', FontAwesomeIcons.lock,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey, size: 20,
                    ),
                    tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Password cannot be empty";
                  if (val.length < 6) return "Password must be at least 6 characters";
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStep1(BuildContext context, bool isWeb, Size size) {
     // --- Step 1: Common Info (Includes Age, Manual Address Input) ---
     return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Step 2: Basic Information', style: GoogleFonts.quicksand(fontSize: 24, fontWeight: FontWeight.bold)),
           const SizedBox(height: 20),

           // Full Name (Unchanged)
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0),
             child: TextFormField(
               controller: _fullnameController,
               keyboardType: TextInputType.name,
               decoration: _buildInputDecoration('Full Name', 'Enter your full name', Icons.person),
               onChanged: (value) => _saveStepData(),
               validator: (val) => (val == null || val.trim().isEmpty) ? "Full name cannot be empty." : null,
               autovalidateMode: AutovalidateMode.onUserInteraction,
             ),
           ),

           // Phone Number (Unchanged)
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0),
             child: TextFormField(
               controller: _phonenumberController,
               keyboardType: TextInputType.phone,
               decoration: _buildInputDecoration('Phone Number', '+ Country Code...', Icons.phone),
               onChanged: (value) => _saveStepData(),
               validator: (val) => (val == null || val.trim().isEmpty) ? "Phone number cannot be empty." : null,
               autovalidateMode: AutovalidateMode.onUserInteraction,
             ),
           ),

           // Age Field (Unchanged)
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0),
             child: TextFormField(
               controller: _ageController,
               keyboardType: TextInputType.number,
               decoration: _buildInputDecoration('Age', 'Enter your age', Icons.cake),
               onChanged: (_) => _saveStepData(),
               validator: (val) { /* ... Age validation ... */
                  if (val == null || val.trim().isEmpty) return "Age is required";
                  final age = int.tryParse(val);
                  if (age == null || age < 16 || age > 120) return "Enter a valid age (16-120)";
                  return null;
               },
               autovalidateMode: AutovalidateMode.onUserInteraction,
             ),
           ),
           const SizedBox(height: 25),

           // --- Location Section ---
           Text("Primary Location", style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w600)),
           const SizedBox(height: 10),

           // **MODIFIED**: Manual Address Input Field
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0),
             child: TextFormField(
               controller: _locationAddressController, // Use the correct controller
               readOnly: false, // Allow input
               keyboardType: TextInputType.streetAddress, // Appropriate keyboard type
               decoration: _buildInputDecoration(
                 'Primary Address', // Updated label
                 'Enter street address, city, country', // Updated hint
                 Icons.location_on,
                 // **REMOVED**: Suffix icon (Get Current Location button) is removed from here
               ),
               onChanged: (_) => _saveStepData(), // Save on change
               validator: (val) => (val == null || val.trim().isEmpty) ? "Primary address cannot be empty." : null, // Add validator
               autovalidateMode: AutovalidateMode.onUserInteraction,
             ),
           ),
           const SizedBox(height: 15),

           // Button to use Current Location Coordinates (Separate from address field)
           Align(
             alignment: Alignment.centerRight,
             child: TextButton.icon(
               icon: _isLoadingLocation
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
               label: const Text("Use Current Location Coordinates"),
               onPressed: _isLoadingLocation ? null : _getCurrentLocation,
             ),
           ),
           const SizedBox(height: 5),

           // Map for selecting/displaying coordinates
           Text("Select Coordinates on Map:", style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w500)),
           const SizedBox(height: 10),
           Container(
               height: 250,
               decoration: BoxDecoration( border: Border.all(color: Colors.grey.shade300)),
               child: FlutterMap(
                 mapController: _mapController,
                 options: MapOptions(
                   initialCenter: _mapCenter,
                   initialZoom: _selectedMapLatLng != null ? 13.0 : 9.0,
                   onTap: (tapPosition, point) async {
                      print("Map tapped at: Lat: ${point.latitude}, Lng: ${point.longitude}");
                     // **MODIFIED**: Only update coordinates and map state
                     setState(() {
                       _selectedMapLatLng = point;
                       _selectedGeoPoint = GeoPoint(point.latitude, point.longitude);
                       _mapCenter = point;
                       // **REMOVED**: Do NOT update _locationAddressController text here
                       // _locationAddressController.text = "Fetching address...";
                     });
       
                     // **REMOVED**: Do NOT call geocoding function here
                     // await _getAndSetLocationName(point.latitude, point.longitude);
                     await _saveStepData(); // Save updated coordinates
                   },
                 ),
                 children: [
                   TileLayer(
                     urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                     userAgentPackageName: 'com.cosmopharma.app', // Replace with your actual package name
                   ),
                   if (_selectedMapLatLng != null)
                     MarkerLayer(
                       markers: [
                         Marker(
                           point: _selectedMapLatLng!, width: 40, height: 40,
                           child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                           alignment: Alignment(0.0, -0.5),
                         ),
                       ],
                     ),
                 ],
               ),
           ),
           const SizedBox(height: 30),
        ],
      ),
     );
  }

  Widget _buildStep2(BuildContext context, bool isWeb, Size size) { // (Unchanged)
    /* ... Profile Details Step ... */
     return Form(
      key: _step2FormKey,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step 3: Profile Details', style: GoogleFonts.quicksand(fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(
                      children: [
                        Text('Individual', style: TextStyle(color: !_isCompany ? Theme.of(context).primaryColor : Colors.grey, fontWeight: !_isCompany ? FontWeight.bold : FontWeight.normal)),
                        Switch(
                          value: _isCompany,
                          onChanged: (value) {
                             print("Switching user type to ${value ? 'Company' : 'Individual'}");
                             _saveStepData();
                            setState(() {
                              _isCompany = value;
                              if (_isCompany) {
                                 print("Clearing potential individual fields");
                                _professionController.clear();
                                _languagesController.clear();
                                _skillsController.clear();
                              } else {
                                 print("Clearing company fields.");
                                _companyNameController.clear();
                                _companyDescriptionController.clear();
                                _companyDomainsController.clear();
                                _companyLocations.clear();
                                _newLocationNameController.clear();
                                _newLocationImageUrlController.clear();
                                _newLocationLatLng = null;
                              }
                              _imageBytes = null;
                               print("Cleared image bytes.");
                            });
                            _saveStepData();
                             print("Saved switched state.");
                          },
                          activeColor: Theme.of(context).primaryColor,
                          inactiveTrackColor: Colors.grey.shade300,
                        ),
                        Text('Company', style: TextStyle(color: _isCompany ? Theme.of(context).primaryColor : Colors.grey, fontWeight: _isCompany ? FontWeight.bold : FontWeight.normal)),
                      ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _isCompany
                  ? _buildCompanyForm(context)
                  : _buildIndividualForm(context),
              const SizedBox(height: 30),
          ],
      ),
     );
  }

  Widget _buildImageUploader(String label) { // (Unchanged)
    /* ... Image uploader ... */
     return Column(
       crossAxisAlignment: CrossAxisAlignment.center,
       children: [
         Text(label, style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w500)),
         const SizedBox(height: 10),
         GestureDetector(
           onTap: _pickImage,
           child: Stack(
             alignment: Alignment.center,
             children: [
               CircleAvatar(
                 radius: 60,
                 backgroundColor: Colors.grey[200],
                 backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                 child: _imageBytes == null
                     ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(
                             _isCompany ? Icons.business : Icons.person,
                             size: 40, color: Colors.grey[400]
                           ),
                           const SizedBox(height: 4),
                           Text(
                             "Tap to Add",
                             style: TextStyle(fontSize: 10, color: Colors.grey[500])
                            )
                         ],
                       )
                     : null,
               ),
               Positioned(
                 bottom: 0, right: 0,
                 child: Container(
                   padding: const EdgeInsets.all(6),
                   decoration: BoxDecoration(
                     color: Theme.of(context).primaryColor,
                     shape: BoxShape.circle,
                     border: Border.all(color: Colors.white, width: 1.5),
                     boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)]
                    ),
                   child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                 ),
               ),
             ],
           ),
         ),
         const SizedBox(height: 10),
       ],
     );
  }

  Widget _buildIndividualForm(BuildContext context) { // (Unchanged - only image)
    /* ... Simplified individual form ... */
     return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(child: _buildImageUploader('Profile Photo (Optional)')),
      ],
    );
  }

  Widget _buildCompanyForm(BuildContext context) { // (Unchanged)
    /* ... Company form fields ... */
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: _companyNameController,
            keyboardType: TextInputType.name,
            decoration: _buildInputDecoration('Company Name', 'Enter official company name', Icons.business),
            validator: (val) => val == null || val.trim().isEmpty ? "Company name is required" : null,
            onChanged: (_) => _saveStepData(),
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ),
         Padding(
           padding: const EdgeInsets.symmetric(vertical: 8.0),
           child: TextFormField(
            controller: _companyDescriptionController,
            keyboardType: TextInputType.multiline,
            maxLines: null, minLines: 3,
            decoration: _buildInputDecoration('Description', 'What does your company do?', Icons.info_outline)
                .copyWith( prefixIcon: const Padding( padding: EdgeInsets.only(top: 12.0), child: Icon(Icons.info_outline, size: 20))),
            validator: (val) => val == null || val.trim().isEmpty ? "Description is required" : null,
            onChanged: (_) => _saveStepData(),
            autovalidateMode: AutovalidateMode.onUserInteraction,
           ),
         ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: _companyDomainsController,
            keyboardType: TextInputType.text,
            decoration: _buildInputDecoration('Domains', 'e.g., Technology, Healthcare (comma separated)', Icons.category),
            validator: (val) => val == null || val.trim().isEmpty ? "Domains/Industries are required" : null,
            onChanged: (_) => _saveStepData(),
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ),
        const SizedBox(height: 30),
        Center(child: _buildImageUploader('Company Logo (Optional)')),
        const SizedBox(height: 30),

        // --- Company Locations Section ---
        Text("Company Locations", style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (_companyLocations.isNotEmpty)
           ListView.builder(
             shrinkWrap: true,
             physics: const NeverScrollableScrollPhysics(),
             itemCount: _companyLocations.length,
             itemBuilder: (context, index) {
               final loc = _companyLocations[index];
               return Card(
                 margin: const EdgeInsets.symmetric(vertical: 4),
                 elevation: 1.5,
                 child: ListTile(
                   leading: CircleAvatar(
                     backgroundColor: Colors.grey[200],
                     backgroundImage: loc.imageUrl.isNotEmpty ? NetworkImage(loc.imageUrl) : null,
                     child: loc.imageUrl.isEmpty ? const Icon(Icons.location_city, color: Colors.grey) : null,
                   ),
                   title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                   subtitle: Text('Lat: ${loc.geopoint.latitude.toStringAsFixed(4)}, Lng: ${loc.geopoint.longitude.toStringAsFixed(4)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                   trailing: IconButton(
                     icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                     tooltip: "Remove Location",
                     onPressed: () {
                        print("Removing location at index: $index");
                       setState(() => _companyLocations.removeAt(index));
                       _saveStepData();
                        print("Saved data after removing location.");
                     },
                   ),
                 ),
               );
             },
           )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("No locations added yet. Add the first one below.", style: TextStyle(color: Colors.grey)),
          ),
        const SizedBox(height: 15),

        // --- Add New Location Input ---
         Theme(
           data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
           child: ExpansionTile(
             title: Text("Add New Location", style: GoogleFonts.quicksand(fontWeight: FontWeight.w600)),
             initiallyExpanded: _companyLocations.isEmpty,
             tilePadding: EdgeInsets.zero,
             childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
             children: [
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                 child: TextFormField(
                   controller: _newLocationNameController,
                   keyboardType: TextInputType.text,
                   decoration: _buildInputDecoration("Location Name", "e.g., Main Branch", Icons.label),
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                 child: TextFormField(
                   controller: _newLocationImageUrlController,
                   keyboardType: TextInputType.url,
                   decoration: _buildInputDecoration("Image URL", "https://... (Optional)", Icons.image),
                 ),
               ),
               const SizedBox(height: 10),
               Text("Select location on map below:", style: GoogleFonts.quicksand(fontSize: 14)),
               const SizedBox(height: 5),
               Container(
                 height: 200,
                 decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                 child: FlutterMap(
                   options: MapOptions(
                     initialCenter: _newLocationLatLng ?? _selectedMapLatLng ?? _mapCenter,
                     initialZoom: 11.0,
                     onTap: (tapPosition, point) {
                       print("New location map tapped: Lat: ${point.latitude}, Lng: ${point.longitude}");
                       setState(() => _newLocationLatLng = point);
                     },
                   ),
                   children: [
                     TileLayer(
                       urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                       userAgentPackageName: 'com.cosmopharma.app', // Replace with your package name
                     ),
                      if (_newLocationLatLng != null)
                       MarkerLayer(markers: [
                         Marker(
                           point: _newLocationLatLng!, width: 30, height: 30,
                           child: const Icon(Icons.add_location_alt, color: Colors.green, size: 30),
                            alignment: Alignment(0.0, -0.5),
                         )
                       ])
                   ],
                 ),
               ),
               const SizedBox(height: 15),
               ElevatedButton.icon(
                 icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                 label: const Text("Add This Location"),
                 style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), textStyle: const TextStyle(fontSize: 14)),
                 onPressed: () {
                   print("Attempting to add new company location.");
                   final name = _newLocationNameController.text.trim();
                   final imageUrl = _newLocationImageUrlController.text.trim();
                   final point = _newLocationLatLng;

                   if (name.isEmpty) {
                     print("Validation Failed: New location name is empty.");
                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location name is required."), backgroundColor: Colors.orange));
                     return;
                   }
                   if (point == null) {
                     print("Validation Failed: New location map point not selected.");
                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please tap the location on the map above."), backgroundColor: Colors.orange));
                     return;
                   }
                    print("Validation passed for new location.");
                   final newLocation = CompanyLocation(name: name, imageUrl: imageUrl, geopoint: GeoPoint(point.latitude, point.longitude));
                   setState(() {
                     _companyLocations.add(newLocation);
                     print("Added new location: ${newLocation.name}");
                     _newLocationNameController.clear();
                     _newLocationImageUrlController.clear();
                     _newLocationLatLng = null;
                     print("Cleared new location input fields.");
                   });
                   _saveStepData();
                    print("Saved data after adding location.");
                 },
               ),
             ],
           ),
         ), // End ExpansionTile
      ],
    );
  }


  Widget _buildNavigationButtons(String nextButtonText) { // (Unchanged)
    /* ... Navigation buttons ... */
     bool isLoading = _isLoadingAuth || _isSubmittingFinal;
    bool showBackButton = _currentStep > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showBackButton)
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            label: const Text("Back"),
            onPressed: isLoading ? null : _previousStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[400]!),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(100, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        if (showBackButton) const SizedBox(width: 20),
        isLoading
            ? const Center(child: Padding( padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))))
            : ElevatedButton(
                onPressed: isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(100, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  nextButtonText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
      ],
    );
  }

} // End _SignUpState