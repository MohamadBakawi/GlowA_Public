import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Using Google Fonts for consistency
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // For potential icons
import 'package:intl/intl.dart'; // For date and number formatting
import 'package:rayanpharma/auth/login.dart';

// Adjust the import path based on your project structure for these pages/widgets
import 'package:rayanpharma/pages/product_details.dart'; // Your Product Detail Page
import 'package:rayanpharma/widgets/profile_div.dart'; // Your Profile Image Widget

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // --- State Variables ---
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userDocFuture;
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _productsFuture; // Future for user's products

  String? _currentUserId; // ID of the currently logged-in user
  bool _isLoading = true; // To manage initial loading state explicitly

  // --- Common User Fields ---
  bool _isCompany = false;
  String _displayName = ''; // Name shown in AppBar (Company Name or Real Name)
  String _username = ''; // User's unique username
  String _email = ''; // Contact email
  String _phoneNumber = '';
  String _imageUrl = ''; // URL for profile image/logo
  Timestamp? _createdAt; // User creation timestamp

  // --- Individual Specific Fields ---
  String _realName = '';
  int? _age;
  String _profession = '';
  List<String> _languages = [];
  List<String> _skills = [];
  GeoPoint? _locationGeoPoint;
  String _locationAddress = '';

  // --- Company Specific Fields ---
  String _companyName = '';
  String _companyDescription = '';
  List<String> _companyDomains = [];
  List<Map<String, dynamic>> _companyLocations = []; // Raw location data
  GeoPoint? _primaryLocationGeoPoint;
  String _primaryLocationAddress = '';

  // --- Social/Stats Fields ---
  String _socialMediaLink = '';
  int _jobsPosted = 0; // Or Products listed for companies
  int _jobsTaken = 0;
  int _reviews = 0;
  List<String> _following = [];
  List<String> _followedBy = [];
  List<String> _institutionIds = []; // For Education section

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Fetch user data and products concurrently when the page loads
    _userDocFuture = _fetchUserDocument();
    _productsFuture = _fetchUserProducts();
  }

  // --- Data Fetching Functions ---

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserDocument() async {
    if (!mounted) return Future.error("Widget not mounted");
    setState(() { _isLoading = true; });
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get() as DocumentSnapshot<Map<String, dynamic>>;

      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (!mounted) return userDoc; // Check mounted state again after await

        // Populate state variables safely
        setState(() {
          _isCompany = data['isCompany'] ?? false;
          _username = data['username'] ?? '';
          _email = data['email'] ?? '';
          _phoneNumber = data['phoneNb'] ?? '';
          _imageUrl = data['imageUrl'] ?? '';
          _createdAt = data['createdAt'] as Timestamp?;

          // Common Stats/Social
          _jobsPosted = (data['jobsPosted'] ?? 0) as int;
          _jobsTaken = (data['jobsTaken'] ?? 0) as int;
          _reviews = (data['reviews'] ?? 0) as int;
          _following = data['following'] != null ? List<String>.from(data['following']) : [];
          _followedBy = data['followedBy'] != null ? List<String>.from(data['followedBy']) : [];
          _socialMediaLink = data['socialMediaLink'] ?? '';

          if (_isCompany) {
            // Populate Company fields
            _companyName = data['companyName'] ?? _username;
            _companyDescription = data['description'] ?? '';
            _companyDomains = data['domains'] != null ? List<String>.from(data['domains']) : [];
            var rawLocations = data['locations'];
            _companyLocations = (rawLocations is List)
                ? rawLocations.map((loc) => Map<String, dynamic>.from(loc as Map)).toList()
                : [];
            _primaryLocationGeoPoint = data['primaryLocationGeoPoint'] as GeoPoint?;
            _primaryLocationAddress = data['primaryLocationAddress'] ?? '';
            _displayName = _companyName; // Use Company Name for display

            // Clear individual fields
            _realName = ''; _age = null; _profession = ''; _skills = []; _languages = [];
            _locationGeoPoint = null; _locationAddress = ''; _institutionIds = [];
          } else {
            // Populate Individual fields
            _realName = data['realName'] ?? _username;
            _age = (data['age'] as num?)?.toInt();
            _profession = data['profession'] ?? '';
            _languages = data['languages'] != null ? List<String>.from(data['languages']) : [];
            _skills = data['skills'] != null ? List<String>.from(data['skills']) : [];
            _locationGeoPoint = data['locationGeoPoint'] as GeoPoint?;
            _locationAddress = data['locationAddress'] ?? '';
            _institutionIds = data['institutions'] != null ? List<String>.from(data['institutions']) : [];
            _displayName = _realName; // Use Real Name for display

            // Clear company fields
            _companyName = ''; _companyDescription = ''; _companyDomains = [];
            _companyLocations = []; _primaryLocationGeoPoint = null; _primaryLocationAddress = '';
          }
          _isLoading = false; // Mark loading as complete
        });
        return userDoc;
      } else {
        if (mounted) setState(() { _isLoading = false; });
        throw Exception("User not found");
      }
    } catch (e) {
      print("Error fetching user document: $e");
      if (mounted) setState(() { _isLoading = false; });
      throw Exception("Error loading profile: $e"); // Rethrow for FutureBuilder
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchUserProducts() async {
    try {
      print("Fetching products for owner: ${widget.userId}");
      final productQuery = FirebaseFirestore.instance
          .collection('products') // Your products collection name
          .where('owner', isEqualTo: widget.userId) // Filter by owner ID
          // Optional: Add ordering if needed (e.g., by a 'createdAt' timestamp)
          // .orderBy('createdAt', descending: true)
          ;
      final productSnapshot = await productQuery.get();
      print("Found ${productSnapshot.docs.length} products.");
      return productSnapshot.docs;
    } catch (e) {
      print("Error fetching user products: $e");
      return []; // Return empty list on error
    }
  }

  Future<List<DocumentSnapshot>> _fetchInstitutionsData() async {
    if (_institutionIds.isEmpty) return [];
    List<Future<DocumentSnapshot>> futures = _institutionIds.map((id) =>
        FirebaseFirestore.instance.collection('institutions').doc(id).get()
    ).toList();
    List<DocumentSnapshot> docs = [];
    try {
       final results = await Future.wait(futures);
       docs = results.where((doc) => doc.exists).toList();
    } catch(e) {
       print("Error fetching institutions in batch: $e");
       // Optionally implement individual fetches as fallback if needed
    }
    return docs;
  }

  // --- Product Deletion Logic ---

  Future<bool> _showDeleteConfirmationDialog(BuildContext context, String productName) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the product "$productName"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ) ?? false; // Return false if dialog is dismissed without selection
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    if (_currentUserId != widget.userId) return; // Security check

    final bool confirmed = await _showDeleteConfirmationDialog(context, productName);

    if (confirmed && mounted) { // Check mounted again after await
      print("Deleting product: $productId");
      try {
        await FirebaseFirestore.instance.collection('products').doc(productId).delete();

        // Show success message and refresh the product list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$productName" deleted successfully.'), backgroundColor: Colors.green),
        );
        // Trigger FutureBuilder reload by assigning a new Future
        setState(() {
          _productsFuture = _fetchUserProducts();
        });
      } catch (e) {
        print("Error deleting product $productId: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete product: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      print("Product deletion cancelled for: $productId");
    }
  }

  // --- Add/Remove Logic for Skills/Languages (Placeholders) ---
  // Assuming you have the full implementation elsewhere or will add it
  Future<void> _removeSkill(String skill) async { /* TODO: Implement Firestore update and UI refresh */ }
  void _showAddSkillDialog() { /* TODO: Implement Dialog and call _addSkillToFirestore */ }
  Future<void> _addSkillToFirestore(String skill) async { /* TODO: Implement Firestore update and UI refresh */ }
  Future<void> _removeLanguage(String language) async { /* TODO: Implement Firestore update and UI refresh */ }
  void _showAddLanguageDialog() { /* TODO: Implement Dialog and call _addLanguageToFirestore */ }
  Future<void> _addLanguageToFirestore(String language) async { /* TODO: Implement Firestore update and UI refresh */ }


  @override
  Widget build(BuildContext context) {
    // Check if the current user is the owner of the profile being viewed
    final isOwner = _currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _userDocFuture,
        builder: (context, userSnapshot) {
          // Handle Loading State
          if (userSnapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // Handle Error State
          if (userSnapshot.hasError) {
            return Center(child: Text('Error loading profile: ${userSnapshot.error}'));
          }
          // Handle User Not Found State
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('User profile not found.'));
          }

          // --- User Data Ready - Build UI ---
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context), // AppBar
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _buildGlassProfileCard(), // Profile Image/Name Card
                  const SizedBox(height: 20),
                  _buildStatsRow(), // Stats (Jobs/Reviews)
                  const SizedBox(height: 30),

                  // --- Conditional Sections based on user type ---
                  if (_isCompany) ...[ // Company Sections
                    if (_companyDescription.isNotEmpty) ..._buildCompanyDescriptionSection(),
                    if (_companyDomains.isNotEmpty) ..._buildCompanyDomainsSection(),
                    if (_companyLocations.isNotEmpty) ..._buildCompanyLocationsSection(),
                  ] else ...[ // Individual Sections
                    if (_languages.isNotEmpty || isOwner) ..._buildLanguagesSection(isOwner), // Show even if empty if owner can add
                    if (_skills.isNotEmpty || isOwner) ..._buildSkillsSection(isOwner),       // Show even if empty if owner can add
                    if (_institutionIds.isNotEmpty) ..._buildEducationSection(),
                  ],

                  // --- Products Section (Always shown, content depends on FutureBuilder) ---
                  _buildUserProductsSection(),

                  // --- Contact Info Section ---
                  _buildInfoTile(isOwner),
                  const SizedBox(height: 40), // Bottom padding
                ]),
              )
            ],
          );
        },
      ),
      // FAB for editing own profile
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: () { /* TODO: Navigate to Edit Profile Page */
                ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Edit Profile (Not Implemented)')));
              },
              backgroundColor: Colors.teal,
              tooltip: 'Edit Profile',
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  // --- UI Helper Methods ---

  // --- UI Helper Methods ---

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      floating: false,
      backgroundColor: Colors.teal.shade400,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _displayName.isNotEmpty ? _displayName : "User Profile",
          style: GoogleFonts.lato(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      actions: [
        // --- MODIFIED LOGOUT BUTTON ---
        if (_currentUserId == widget.userId) // Only show if viewing own profile
          IconButton(
            icon: const Icon(Icons.logout), // Changed icon
            tooltip: 'Logout', // Changed tooltip
            onPressed: () async {
              // 1. Confirm with the user
              final bool? confirmLogout = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false); // Return false
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Logout'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true); // Return true
                        },
                      ),
                    ],
                  );
                },
              );

              // 2. Proceed if confirmed (and widget is still mounted)
              if (confirmLogout == true && context.mounted) {
                try {
                  // 3. Sign out using Firebase Auth
                  await FirebaseAuth.instance.signOut();

                  // 4. Navigate to login/splash screen and remove back stack
                  // IMPORTANT: Replace '/login' with your actual login route name
                    Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Login()), // <<< Create the route directly
          (Route<dynamic> route) => false);
                } catch (e) {
                  // 5. Handle potential errors
                  print('Error signing out: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Logout failed: ${e.toString()}'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
          ),
        // --- END OF MODIFIED BUTTON ---
      ],
    );
  }

  // ... rest of your _UserProfilePageState class ...

  Widget _buildGlassProfileCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), // Slightly less transparent
          boxShadow: [ BoxShadow( color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5), ), ],
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text( _username, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87), ),
            const SizedBox(height: 4),
            // Location (Individual or Company Primary)
            if (_locationAddress.isNotEmpty || _primaryLocationAddress.isNotEmpty)
              Row( mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                 Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]), const SizedBox(width: 4),
                 Flexible( child: Text( _isCompany ? _primaryLocationAddress : _locationAddress, style: TextStyle(fontSize: 13, color: Colors.grey[700]), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2, ), ),
                ],
              ),
             // Joined Date
             if (_createdAt != null)
              Padding( padding: const EdgeInsets.only(top: 6.0), child: Text( 'Joined: ${DateFormat.yMMMd().format(_createdAt!.toDate())}', style: TextStyle(fontSize: 12, color: Colors.grey[500]), ), ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [ BoxShadow( color: Colors.grey.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4), ), ], ),
        child: Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            // Adapt Title based on context if needed
            _CategoryItem(title: _isCompany ? 'Listings' : 'Jobs Posted', value: _jobsPosted),
            _CategoryItem(title: 'Jobs Taken', value: _jobsTaken),
            _CategoryItem(title: 'Reviews', value: _reviews),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding( padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16, bottom: 8),
      child: Text( title, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87), ),
    );
  }

  // --- Specific Section Builders ---

  List<Widget> _buildCompanyDescriptionSection() {
    return [
       _buildSectionTitle("About Us"),
       Padding( padding: const EdgeInsets.symmetric(horizontal: 24.0),
         child: Text(_companyDescription, style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4)), // Added line height
       ),
       const SizedBox(height: 30),
    ];
  }

  List<Widget> _buildCompanyDomainsSection() {
    return [
      _buildSectionTitle("Domains / Industries"),
      _buildChipList(_companyDomains), // Reusable chip list builder
      const SizedBox(height: 30),
    ];
  }

  List<Widget> _buildCompanyLocationsSection() {
    return [
      _buildSectionTitle("Locations"),
      _buildCompanyLocationsList(),
      const SizedBox(height: 30),
    ];
  }

  List<Widget> _buildLanguagesSection(bool isOwner) {
     return [
      Padding( padding: const EdgeInsets.only(left: 24.0, right: 8.0),
        child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text( 'Languages', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87), ),
            if (isOwner) IconButton( icon: const Icon(Icons.add_circle_outline, color: Colors.teal), tooltip: 'Add Language', onPressed: _showAddLanguageDialog, ),
          ],
        ),
      ),
      _buildChipList(_languages, isRemovable: isOwner, onRemove: _removeLanguage),
      const SizedBox(height: 30),
    ];
  }

  List<Widget> _buildSkillsSection(bool isOwner) {
    return [
      Padding( padding: const EdgeInsets.only(left: 24.0, right: 8.0),
        child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text( 'Skills', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87), ),
            if (isOwner) IconButton( icon: const Icon(Icons.add_circle_outline, color: Colors.teal), tooltip: 'Add Skill', onPressed: _showAddSkillDialog, ),
          ],
        ),
      ),
      _buildChipList(_skills, isRemovable: isOwner, onRemove: _removeSkill),
      const SizedBox(height: 30),
    ];
  }

  List<Widget> _buildEducationSection() {
     return [
       _buildSectionTitle("Education"),
       _buildEducationList(), // Contains FutureBuilder for institution data
       const SizedBox(height: 30),
     ];
  }

  // --- List Builders (Chips, Education, Locations, Products) ---

  Widget _buildChipList(List<String> items, {bool isRemovable = false, Function(String)? onRemove}) {
    // Handles empty state internally if needed, or return placeholder
    if (items.isEmpty && !isRemovable) {
       return const Padding( padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Text('None specified.', style: TextStyle(color: Colors.grey)), );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: Wrap( spacing: 8.0, runSpacing: 4.0, children: items.map((item) => Chip(
            label: Text(item), backgroundColor: Colors.teal.shade50,
            labelStyle: TextStyle(color: Colors.teal.shade800, fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap area
            deleteIcon: isRemovable ? Icon(Icons.cancel, size: 16, color: Colors.red.shade300) : null,
            onDeleted: isRemovable ? () => onRemove?.call(item) : null,
          )).toList(),
      ),
    );
  }

  Widget _buildEducationList() {
    // FutureBuilder specifically for fetching linked institution data
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _fetchInstitutionsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Loading education...")));
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Padding( padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Text('No education added.', style: TextStyle(color: Colors.grey)), );

        return Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Column(
            children: snapshot.data!.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildCard(
                imageUrl: data['logoUrl'] ?? 'https://via.placeholder.com/150/CCCCCC/FFFFFF?Text=Edu',
                title: data['Name'] ?? 'Unknown Institution',
                subtitle: data['type'] ?? 'Education',
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCompanyLocationsList() {
     return Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Column(
        children: _companyLocations.map((locData) {
           String name = locData['name'] ?? 'Unnamed Location';
           String imageUrl = locData['imageUrl'] ?? 'https://via.placeholder.com/150/E0E0E0/000000?Text=Loc';
           GeoPoint? geo = locData['geopoint'] as GeoPoint?;
           String subtitle = geo != null ? 'Lat: ${geo.latitude.toStringAsFixed(4)}, Lng: ${geo.longitude.toStringAsFixed(4)}' : 'Coordinates not set';
          return _buildCard( imageUrl: imageUrl, title: name, subtitle: subtitle, /* onTap: () => _showLocationOnMap(geo) */ );
        }).toList(),
      ),
    );
   }

  Widget _buildUserProductsSection() {
    final bool isOwner = _currentUserId == widget.userId;
    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionTitle("Products"),
        FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          future: _productsFuture, // Use the state future
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 30), child: CircularProgressIndicator(strokeWidth: 2)));
            if (snapshot.hasError) return Center(child: Text('Error loading products: ${snapshot.error}'));
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Padding( padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), child: Center(child: Text('No products listed yet.')), );

            // --- Products Available ---
            final productDocs = snapshot.data!;
            return Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Column(
                // Use ListView.builder if the list can be very long
                children: productDocs.map((doc) {
                  final data = doc.data();
                  final productId = doc.id;
                  // Extract data needed for ProductListItem and Navigation/Deletion
                  final name = data['name'] ?? 'No Name';
                  final imageUrl = data['imageUrl'] ?? 'https://via.placeholder.com/150';
                  final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                  final description = data['description'] ?? 'No description.';

                  return _buildProductListItem( // Pass all required data
                    imageUrl: imageUrl, title: name, price: price,
                    productId: productId, isOwner: isOwner,
                    onTap: () => Navigator.push( context, MaterialPageRoute( builder: (context) => ProductDetailPage(
                          productId: productId, imageUrl: imageUrl, title: name,
                          description: description, price: price,
                        ),
                      ),
                    ),
                    onDelete: () => _deleteProduct(productId, name), // Pass delete handler
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 30), // Spacing after section
      ],
    );
  }

  // --- Generic Item Builders (Card, Product Item) ---

  Widget _buildCard({required String imageUrl, required String title, required String subtitle, VoidCallback? onTap}) {
    // Generic card layout used for Education, Locations, etc.
    return Padding( padding: const EdgeInsets.symmetric(vertical: 6.0), child: Card(
        elevation: 1.5, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
        child: InkWell( onTap: onTap, child: Padding( padding: const EdgeInsets.all(12), child: Row( children: [
                ClipRRect( borderRadius: BorderRadius.circular(8), child: Image.network( imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(width: 60, height: 60, color: Colors.grey[200], child: Icon(Icons.image_not_supported, color: Colors.grey[400])),
                    loadingBuilder: (c, child, p) => (p == null) ? child : Container(width: 60, height: 60, color: Colors.grey[200], child: Center(child: CircularProgressIndicator(strokeWidth: 2, value: p.expectedTotalBytes != null ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis,),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis,),
                    ],
                  ),
                ),
                 if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductListItem({ required String imageUrl, required String title, required double price, required String productId, required bool isOwner, required VoidCallback onDelete, VoidCallback? onTap, }) {
    // Specific layout for Product items in the list
    return Padding( padding: const EdgeInsets.symmetric(vertical: 6.0), child: Card(
        elevation: 1.5, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
        child: InkWell( onTap: onTap, child: Padding( padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12, right: 6), child: Row( children: [
                ClipRRect( borderRadius: BorderRadius.circular(8), child: Image.network( imageUrl, width: 65, height: 65, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(width: 65, height: 65, color: Colors.grey[200], child: Icon(Icons.storefront, color: Colors.grey[400], size: 30)),
                    loadingBuilder: (c, child, p) => (p == null) ? child : Container(width: 65, height: 65, color: Colors.grey[200], child: Center(child: CircularProgressIndicator(strokeWidth: 2, value: p.expectedTotalBytes != null ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text( title, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis, ),
                      const SizedBox(height: 6),
                      Text( NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(price), style: GoogleFonts.lato(fontSize: 15, color: Colors.teal.shade700, fontWeight: FontWeight.bold), ),
                    ],
                  ),
                ),
                // Conditional Delete Button or Navigation Chevron
                if (isOwner)
                  IconButton( icon: Icon(Icons.delete_outline, color: Colors.red.shade400), tooltip: 'Delete Product',
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(), iconSize: 20, onPressed: onDelete, )
                else if (onTap != null)
                  Padding( padding: const EdgeInsets.all(8.0), child: Icon(Icons.chevron_right, color: Colors.grey.shade400), ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Info Tile Builder ---

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onEdit, bool isOwner = false}) {
     if (value.isEmpty) return const SizedBox.shrink(); // Hide row if value is empty
     return Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
           Icon(icon, size: 18, color: Colors.teal.shade600), const SizedBox(width: 12),
           Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)), const SizedBox(height: 2),
                 Text(value, style: GoogleFonts.lato(fontSize: 15, color: Colors.black87)),
               ],
             ),
           ),
           if (isOwner && onEdit != null) // Edit button for owner
             IconButton( icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey[400]), padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: 'Edit $label', onPressed: onEdit, ),
         ],
       ),
     );
  }

  Widget _buildInfoTile(bool isOwner) {
    String tileTitle = _isCompany ? "Company Information" : "Contact & Info";
    List<Widget> infoRows = [];

    // Populate rows based on user type
    if (_isCompany) {
      infoRows.addAll([
         _buildInfoRow(Icons.email_outlined, "Contact Email", _email, isOwner: isOwner, onEdit: () {/* TODO */}),
         _buildInfoRow(Icons.phone_outlined, "Phone Number", _phoneNumber, isOwner: isOwner, onEdit: () {/* TODO */}),
         _buildInfoRow(FontAwesomeIcons.link, "Social/Website", _socialMediaLink, isOwner: isOwner, onEdit: () {/* TODO */}),
         _buildInfoRow(Icons.location_city_outlined, "Primary Address", _primaryLocationAddress, isOwner: isOwner, onEdit: () {/* TODO */}),
      ]);
    } else { // Individual Info
      infoRows.addAll([
         _buildInfoRow(Icons.person_outline, "Full Name", _realName, isOwner: isOwner, onEdit: () {/* TODO */}),
         if (_age != null) _buildInfoRow(Icons.cake_outlined, "Age", _age.toString(), isOwner: isOwner, onEdit: () {/* TODO */}),
         _buildInfoRow(Icons.email_outlined, "Contact Email", _email, isOwner: isOwner, onEdit: () {/* TODO */}),
         _buildInfoRow(Icons.phone_outlined, "Phone Number", _phoneNumber, isOwner: isOwner, onEdit: () {/* TODO */}),
         _buildInfoRow(FontAwesomeIcons.link, "Social Media", _socialMediaLink, isOwner: isOwner, onEdit: () {/* TODO */}),
         _buildInfoRow(Icons.location_on_outlined, "Location", _locationAddress, isOwner: isOwner, onEdit: () {/* TODO */}),
         if (_profession.isNotEmpty) _buildInfoRow(Icons.work_outline, "Profession", _profession, isOwner: isOwner, onEdit: () {/* TODO */}),
      ]);
    }

    // Use ExpansionTile within a Card for consistent look
    return Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Card(
        elevation: 1, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          title: Text( tileTitle, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87), ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Padding for content inside
          initiallyExpanded: true, // Keep it expanded by default
          children: infoRows.isEmpty ? [const Text("No information available.")] : infoRows,
        ),
      ),
    );
  }

} // End of _UserProfilePageState

// --- Helper Widgets ---

class _CategoryItem extends StatelessWidget {
  final String title;
  final int value;
  const _CategoryItem({Key? key, required this.title, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded( child: Column( mainAxisSize: MainAxisSize.min, children: [
          Text( value.toString(), style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade800), ),
          const SizedBox(height: 4),
          Text( title, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, ),
        ],
      ),
    );
  }
}

// --- ProfileDiv Widget (Ensure your actual implementation is imported) ---
/*
class ProfileDiv extends StatelessWidget {
  final String userId;
  final double size;
  const ProfileDiv({Key? key, required this.userId, this.size = 50.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This should fetch the user's image URL based on userId and display it
    // Example Placeholder:
    return FutureBuilder<String?>( // Example: Assuming you fetch URL
      future: fetchUserImageUrl(userId), // Replace with your actual image fetch logic
      builder: (context, snapshot) {
        String? imageUrl = snapshot.data;
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey[300],
          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
          child: (imageUrl == null || imageUrl.isEmpty)
              ? Icon(Icons.person, size: size * 0.6, color: Colors.white)
              : null,
        );
      }
    );
  }
  // Dummy function placeholder - replace with your actual logic
  Future<String?> fetchUserImageUrl(String userId) async => null;
}
*/