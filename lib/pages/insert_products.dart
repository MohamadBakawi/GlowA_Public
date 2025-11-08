import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InsertProducts extends StatefulWidget {
  const InsertProducts({Key? key}) : super(key: key);

  @override
  _InsertProductsState createState() => _InsertProductsState();
}

class _InsertProductsState extends State<InsertProducts> {
  final _formKey = GlobalKey<FormState>();

  // Controllers remain the same
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController(); // Still used for general keywords
  final TextEditingController _quantityController = TextEditingController();

  // Checkbox state variables remain the same
  bool _isSuitableForOily = false;
  bool _isSuitableForDry = false;
  bool _isSuitableForNormal = false;
  // bool _isSuitableForSensitive = false; // Example if you add more

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitProduct() async {
    // --- 1. Validate Form ---
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // --- 2. Check User Login ---
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = "Error: You must be logged in to add products.";
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    final String ownerUid = currentUser.uid;

    // --- 3. Set Loading State ---
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // --- 4. Fetch User Location (NEW STEP) ---
    GeoPoint? userLocation; // Variable to store the fetched location
    try {
      // Reference the user's document in the 'users' collection
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(ownerUid);
      final userDocSnapshot = await userDocRef.get();

      if (userDocSnapshot.exists) {
        final userData = userDocSnapshot.data();
        // Attempt to get the 'location' field as a GeoPoint
        // Adjust 'location' if your field name is different
        userLocation = userData?['location'] as GeoPoint?;

        if (userLocation == null) {
          // Location field might be missing or not a GeoPoint
          // Decide how to handle this: proceed without location, or show error?
          // For now, we'll proceed without, but log a warning.
          print("Warning: User location data not found or is not a GeoPoint for user $ownerUid.");
          // Optionally set an error message and return:
          // setState(() {
          //   _errorMessage = "Your location data is missing or invalid in your profile.";
          //   _isLoading = false;
          // });
          // return;
        }
      } else {
        // This is unexpected if the user is logged in, indicates missing user profile data
        throw Exception("User profile data not found.");
      }
    } catch (error) {
      // Handle errors during user data fetching
      if (mounted) {
        setState(() {
          _errorMessage = "Error fetching your location: ${error.toString()}";
          _isLoading = false; // Stop loading on error
        });
      }
      print("Firestore User Data Error: $error");
      return; // Stop the product submission process
    }

    // --- 5. Prepare Other Product Data ---
    try {
      // Process general keywords from the text field
      List<String> generalKeywords = _keywordsController.text
          .split(',')
          .map((s) => s.trim().toLowerCase()) // Also making general keywords lowercase
          .where((s) => s.isNotEmpty)
          .toList();

      // Process skin type suitability flags into a list
      List<String> suitableSkinTypes = [];
      if (_isSuitableForOily) suitableSkinTypes.add('Oily Skin'); // using lowercase tags
      if (_isSuitableForDry) suitableSkinTypes.add('Dry Skin');
      if (_isSuitableForNormal) suitableSkinTypes.add('Normal Skin');
      // if (_isSuitableForSensitive) suitableSkinTypes.add('sensitive');

      // Combine general keywords and skin type tags into one keywords list
      // (You might want separate fields in Firestore if needed, e.g., 'tags' and 'skinTypes')
      List<String> allKeywords = [
          ...generalKeywords,
          ...suitableSkinTypes,
          // Add the lowercase product name itself as a keyword for easier searching
          _nameController.text.trim().toLowerCase(),
          // Maybe add parts of the name too? e.g., if name is "Hydrating Face Cream" add "hydrating", "face", "cream"
          ..._nameController.text.trim().toLowerCase().split(' ').where((part) => part.length > 2) // Example: split name
      ];
      // Remove duplicates if any word appears in multiple places
      allKeywords = allKeywords.toSet().toList();


      final double price = double.parse(_priceController.text);
      final int quantity = int.parse(_quantityController.text);

      // --- 6. Prepare Final Product Data Map ---
      final Map<String, dynamic> productData = {
        // *** MODIFIED HERE: Convert name to lowercase before saving ***
        'name': _nameController.text.trim(),
        'searchName':_nameController.text.trim().toLowerCase(),
        'description': _descController.text.trim(),
        'price': price,
        'imageUrl': _imageUrlController.text.trim(),
        'quantity': quantity,
        'owner': ownerUid,
        // 'keywords': allKeywords, // Using a combined list for searching (consider if separate fields are better)
        'skinTypes': suitableSkinTypes, // Keep skin types separate if needed for specific filtering
        'keyWords': allKeywords, // Using a dedicated field for all searchable terms
        'createdAt': FieldValue.serverTimestamp(),
        // Conditionally add location only if it was successfully fetched
        if (userLocation != null) 'location': userLocation,
      };

      // --- 7. Add Product to Firestore ---
      await FirebaseFirestore.instance.collection('products').add(productData);

      // --- 8. Show Success & Clear Fields ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product inserted successfully!'), backgroundColor: Colors.green),
        );
        _clearFormFields();
      }
    } catch (error) {
      // Handle errors during product data preparation or Firestore insertion
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to insert product: ${error.toString()}";
        });
        print("Firestore Product Insert Error: $error");
      }
    } finally {
      // --- 9. Reset Loading State ---
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // _clearFormFields remains the same
  void _clearFormFields() {
    _nameController.clear();
    _descController.clear();
    _priceController.clear();
    _imageUrlController.clear();
    _keywordsController.clear();
    _quantityController.clear();
    setState(() {
       _isSuitableForOily = false;
       _isSuitableForDry = false;
       _isSuitableForNormal = false;
       // _isSuitableForSensitive = false;
       _errorMessage = null;
    });
     // Also reset the validation state of the form
     _formKey.currentState?.reset();
  }

  // dispose remains the same
  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _keywordsController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // build method remains the same structure, just uses the modified _submitProduct
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insert Product'),
        backgroundColor: Colors.tealAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                          border: OutlineInputBorder(),
                           prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Enter product name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                           prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 3,
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Enter product description' : null,
                      ),
                      const SizedBox(height: 16),

                      // Price Field
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                           FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter product price';
                          if (double.tryParse(value) == null) return 'Enter a valid number';
                          if (double.parse(value) <= 0) return 'Price must be positive';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Quantity Field
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                           prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [ FilteringTextInputFormatter.digitsOnly ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter product quantity';
                          if (int.tryParse(value) == null) return 'Enter a valid whole number';
                          if (int.parse(value) < 0) return 'Quantity cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Image URL Field
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Image URL',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                         keyboardType: TextInputType.url,
                        validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Enter image URL';
                            // Basic URL validation (can be enhanced)
                            final uri = Uri.tryParse(value.trim());
                            if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
                              return 'Enter a valid URL (e.g., https://...)';
                            }
                            return null;
                        }
                      ),
                      const SizedBox(height: 16),

                      // Keywords Field (for general keywords)
                      TextFormField(
                        controller: _keywordsController,
                        decoration: const InputDecoration(
                          labelText: 'Keywords (comma separated)',
                          hintText: 'e.g., hydrating, anti-aging, organic',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        // Keywords are optional, so no validator needed unless required
                      ),
                      const SizedBox(height: 24),

                      // --- Skin Suitability Checkboxes ---
                      const Text("Suitable For:", style: TextStyle(fontWeight: FontWeight.bold)),
                       CheckboxListTile(
                         title: const Text("Oily Skin"),
                         value: _isSuitableForOily,
                         onChanged: (bool? newValue) {
                           setState(() { _isSuitableForOily = newValue ?? false; });
                         },
                         controlAffinity: ListTileControlAffinity.leading,
                         contentPadding: EdgeInsets.zero,
                       ),
                       CheckboxListTile(
                         title: const Text("Dry Skin"),
                         value: _isSuitableForDry,
                         onChanged: (bool? newValue) {
                           setState(() { _isSuitableForDry = newValue ?? false; });
                         },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                       ),
                       CheckboxListTile(
                         title: const Text("Normal Skin"),
                         value: _isSuitableForNormal,
                         onChanged: (bool? newValue) {
                           setState(() { _isSuitableForNormal = newValue ?? false; });
                         },
                         controlAffinity: ListTileControlAffinity.leading,
                         contentPadding: EdgeInsets.zero,
                       ),
                       // Add more checkboxes here if needed (e.g., Sensitive Skin)
                       // CheckboxListTile(
                       //   title: const Text("Sensitive Skin"),
                       //   value: _isSuitableForSensitive,
                       //   onChanged: (bool? newValue) {
                       //     setState(() { _isSuitableForSensitive = newValue ?? false; });
                       //   },
                       //   controlAffinity: ListTileControlAffinity.leading,
                       //   contentPadding: EdgeInsets.zero,
                       // ),

                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Insert Product'),
                      ),

                      // Error Message Display
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ]
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}