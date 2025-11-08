import 'dart:async'; // Needed for Timer if you use Debouncer elsewhere, keep for consistency
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cosmopharma/widgets/profile_div.dart'; // Assuming this path is correct
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'package:encrypt/encrypt.dart' as enc;
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Data class for representing a map location.
class MapLocation {
  final String name;
  final LatLng point;
  final String? imageUrl;

  MapLocation({required this.name, required this.point, this.imageUrl});
}

/// A separate page to display multiple company locations on a map.
class CompanyLocationsMapPage extends StatelessWidget {
  final List<MapLocation> locations;
  final LatLng? initialCenter;

  static const Color _corporateBluePrimary = Color(0xFF0D47A1); // Dark Blue

  const CompanyLocationsMapPage({
    super.key,
    required this.locations,
    this.initialCenter,
  });

  @override
  Widget build(BuildContext context) {
    // Create map markers from location data
    final List<Marker> markers = locations.map((loc) {
      return Marker(
        width: 80.0, // Increased size to accommodate button tap area
        height: 80.0,
        point: loc.point,
        child: Column( // Use Column to position icon slightly above point if needed
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.location_pin, color: _corporateBluePrimary, size: 30.0),
              tooltip: loc.name, // Add tooltip for accessibility
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(loc.name),
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
          ],
        ),
      );
    }).toList();

    // Determine map center and zoom level
    LatLng center;
    double zoom;
    if (initialCenter != null) {
      center = initialCenter!;
      zoom = 14.0; // Zoom in closer if specific center is provided
    } else if (locations.isNotEmpty) {
      center = locations.first.point;
      // Adjust zoom based on number of locations (simple logic)
      zoom = locations.length > 1 ? 8.0 : 14.0;
    } else {
      // Default fallback coordinates (e.g., center of Lebanon)
      center = const LatLng(33.8547, 35.8623);
      zoom = 8.0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Locations'),
        backgroundColor: _corporateBluePrimary,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          minZoom: 5.0, // Prevent zooming out too far
          maxZoom: 18.0, // Allow reasonable zoom in
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.skillxchange.app', // Replace with your actual package name
            tileProvider: CancellableNetworkTileProvider(), // Use cancellable provider
            retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0, // Enable for high-res displays
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              ),
            ],
            alignment: AttributionAlignment.bottomLeft,
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

/// Displays the profile page for a company user.
class CompanyProfilePage extends StatefulWidget {
  final String userId; // The ID of the company user whose profile is being viewed
  const CompanyProfilePage({super.key, required this.userId});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  // Firestore and Auth instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  Future<DocumentSnapshot>? _userDocFuture; // Future for loading user data
  String? _currentUserId; // ID of the currently logged-in user
  Map<String, dynamic>? _userData; // Holds fetched company data
  bool _isReporting = false; // Loading state for reporting action
  bool _hasAlreadyReported = false; // Flag if current user reported this company

  // Stats calculated from user data
  int _jobsCreated = 0;
  int _jobsFulfilled = 0;
  double? _averageRating; // Average rating from employee reviews
  int _reviewCount = 0; // Number of valid employee reviews

  // Map picker defaults
  static final LatLng _defaultInitialPickerCenter = LatLng(33.8547, 35.8623); // Default center (Lebanon)
  static const double _defaultPickerZoom = 8.0;
  static const double _selectedPickerZoom = 15.0;

  // Corporate color palette
  static const Color _corporateBluePrimary = Color(0xFF0D47A1);
  static const Color _corporateBlueAccent = Color(0xFF42A5F5);
  static const Color _onCorporateBlue = Colors.white;
  static const Color _corporateSurface = Color(0xFFF5F5F5);
  static const Color _corporateOnSurface = Color(0xFF333333);
  static const Color _corporateGreyText = Colors.grey;
  static const Color _corporateErrorColor = Colors.redAccent;
  static const Color _corporateSuccessColor = Colors.green;
  static const Color _corporateWarningColor = Colors.orangeAccent;


  // --- Encryption constants and helpers ---
  static const String _encryptionKeyString = "WAVEROVER"; // Consider more secure key management

  static (enc.Key, enc.IV) _getEncryptionKeyIV(String keyString) {
    final keyBytes = utf8.encode(keyString);
    final keyHash = sha256.convert(keyBytes);
    final key = enc.Key(Uint8List.fromList(keyHash.bytes));
    final ivBytes = keyHash.bytes.sublist(0, 16); // Use first 16 bytes of hash for IV
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    return (key, iv);
  }

  static String? _encryptUID(String uid) {
    if (uid.isEmpty) return null;
    try {
      final (key, iv) = _getEncryptionKeyIV(_encryptionKeyString);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc)); // Use CBC mode
      final encrypted = encrypter.encrypt(uid, iv: iv);
      return encrypted.base64; // Return Base64 encoded string
    } catch (e) {
      if (kDebugMode) { print("Encryption Error: $e"); }
      return null;
    }
  }

  // ignore: unused_element // Keep for potential future use or reference
  static String? _decryptUID(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return null;
    try {
      final (key, iv) = _getEncryptionKeyIV(_encryptionKeyString);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(encryptedBase64), iv: iv);
      return decrypted;
    } catch (e) {
      if (kDebugMode) { print("Decryption Error: $e"); }
      return null;
    }
  }
  // --- End Encryption ---

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _userDocFuture = _fetchUserDocument(); // Start fetching data immediately
  }

  /// Fetches the company's user document from Firestore and calculates stats.
  Future<DocumentSnapshot> _fetchUserDocument() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(widget.userId) // The ID of the company profile being viewed
          .get();

      if (userDoc.exists && mounted) { // Check if widget is still mounted
        final data = userDoc.data() as Map<String, dynamic>;

        // --- Calculate Average Rating ---
        double totalRatingSum = 0;
        int validRatingCount = 0;
        double? calculatedAverage;
        final List<dynamic> employeeReviewsRaw = data['employeeReviews'] as List<dynamic>? ?? [];
        for (var reviewData in employeeReviewsRaw) {
          if (reviewData is Map) {
            final dynamic ratingValue = reviewData['rating'];
            double? rating;
            if (ratingValue is num) { rating = ratingValue.toDouble(); }
            if (rating != null && rating >= 0 && rating <= 5) {
              totalRatingSum += rating;
              validRatingCount++;
            }
          }
        }
        if (validRatingCount > 0) {
          calculatedAverage = totalRatingSum / validRatingCount;
        }
        // --- End Calculation ---

        // --- Check Reported Status ---
        bool alreadyReported = false;
        final List<dynamic> encryptedReportersDynamic = data['reportedBy'] as List<dynamic>? ?? [];
        final List<String> encryptedReporterStrings = encryptedReportersDynamic.map((e) => e.toString()).toList();
        if (_currentUserId != null) {
          final encryptedCurrentUid = _encryptUID(_currentUserId!);
          alreadyReported = encryptedCurrentUid != null && encryptedReporterStrings.contains(encryptedCurrentUid);
        }
        // --- End Check ---

        // Update state
        setState(() {
          _userData = data;
          _jobsCreated = data['jobsPosted'] as int? ?? 0; // Use appropriate field name
          _jobsFulfilled = data['jobsTaken'] as int? ?? 0; // Use appropriate field name
          _averageRating = calculatedAverage;
          _reviewCount = validRatingCount;
          _hasAlreadyReported = alreadyReported;
        });
      } else if (mounted) {
        // Handle profile not found
        setState(() {
           _userData = null;
           _averageRating = null;
           _reviewCount = 0;
           _hasAlreadyReported = false;
           _jobsCreated = 0;
           _jobsFulfilled = 0;
        });
      }
      return userDoc; // Return the snapshot for the FutureBuilder
    } catch (e, s) { // Add stack trace logging
      if (kDebugMode) { print("Error fetching user document: $e\n$s"); }
      if (mounted) {
        // Reset state on error
        setState(() {
          _averageRating = null;
          _reviewCount = 0;
          _hasAlreadyReported = false;
          _jobsCreated = 0;
           _jobsFulfilled = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching company data: $e'), backgroundColor: _corporateErrorColor),
        );
      }
      rethrow; // Rethrow to let FutureBuilder handle the error state
    }
  }


  /// Reports the company user.
  Future<void> reportUsr(String reportedUserId) async {
    if (_currentUserId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to report.'), backgroundColor: _corporateWarningColor));
      return;
    }
    if (_currentUserId == reportedUserId) return; // Cannot report self
    if (_isReporting || _hasAlreadyReported) return; // Prevent multiple reports/clicks

    final String? encryptedUidToReport = _encryptUID(_currentUserId!);
    if (encryptedUidToReport == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error preparing report data.'), backgroundColor: _corporateErrorColor));
      return;
    }

    setState(() { _isReporting = true; }); // Show loading indicator

    try {
      final userRef = _firestore.collection('users').doc(reportedUserId);
      await userRef.update({'reportedBy': FieldValue.arrayUnion([encryptedUidToReport])});

      if (mounted) {
        setState(() { _hasAlreadyReported = true; }); // Update UI immediately
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted successfully.'), backgroundColor: _corporateSuccessColor));
      }
    } catch (e, s) { // Add stack trace logging
      if (kDebugMode) { print("Error submitting report: $e\n$s"); }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting report: $e'), backgroundColor: _corporateErrorColor));
    } finally {
      if (mounted) setState(() { _isReporting = false; }); // Hide loading indicator
    }
  }


  /// Adds a new location to the company's profile. (Owner only)
  Future<void> _addLocation(Map<String, dynamic> newLocation) async {
    if (_currentUserId == null || _currentUserId != widget.userId) return; // Owner check
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .update({'locations': FieldValue.arrayUnion([newLocation])});

      await _fetchUserDocument(); // Refresh data after adding

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location added successfully!'), backgroundColor: _corporateSuccessColor));
      }
    } catch (e, s) { // Add stack trace logging
      if (kDebugMode) { print("Error adding location: $e\n$s"); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding location: $e'), backgroundColor: _corporateErrorColor));
      }
    }
  }

  /// Adds a new domain to the company's profile. (Owner only)
  Future<void> _addDomain(String newDomain) async {
    if (_currentUserId == null || _currentUserId != widget.userId) return; // Owner check
    if (newDomain.trim().isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .update({'domains': FieldValue.arrayUnion([newDomain.trim()])});

      await _fetchUserDocument(); // Refresh data after adding

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Domain "$newDomain" added successfully!'), backgroundColor: _corporateSuccessColor));
      }
    } catch (e, s) { // Add stack trace logging
      if (kDebugMode) { print("Error adding domain: $e\n$s"); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding domain: $e'), backgroundColor: _corporateErrorColor));
      }
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final bool isOwner = _currentUserId == widget.userId;

    // Configure report button appearance based on state
    IconData reportIcon = Icons.flag_outlined;
    Color reportIconColor = _onCorporateBlue;
    String reportTooltip = 'Report User';
    if (_hasAlreadyReported) {
      reportIcon = Icons.flag;
      reportIconColor = _corporateWarningColor; // Use warning color
      reportTooltip = 'You have reported this user';
    }

    return Scaffold(
      backgroundColor: _corporateSurface,
      appBar: AppBar(
        title: const Text('Company Profile'),
        backgroundColor: _corporateBluePrimary,
        foregroundColor: _onCorporateBlue,
        elevation: 2.0,
        centerTitle: true,
        actions: [
          // Show report button only if logged in and not the owner
          if (!isOwner && _currentUserId != null)
            IconButton(
              icon: _isReporting // Show spinner while reporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _onCorporateBlue, strokeWidth: 2))
                  : Icon(reportIcon, color: reportIconColor),
              tooltip: reportTooltip,
              // Disable button while reporting or if already reported
              onPressed: (_isReporting || _hasAlreadyReported) ? null : () => reportUsr(widget.userId),
            ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userDocFuture,
        builder: (context, snapshot) {
          // --- Loading State ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _corporateBluePrimary));
          }
          // --- Error State ---
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading profile: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: _corporateErrorColor)),
              ),
            );
          }
          // --- Not Found State ---
          // Check _userData as well, which is set only on success in fetch
          if (_userData == null || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text('Company profile not found.', style: TextStyle(fontSize: 18, color: _corporateGreyText)),
            );
          }

          // --- Data Loaded State ---
          // Safely extract data using the helper or null-aware operators
          final String description = _userData!['description'] as String? ?? 'No description provided.';
          final String contactName = _userData!['name'] as String? ?? 'N/A';
          final String contactEmail = _userData!['contactEmail'] as String? ?? 'N/A';
          final String phoneNumber = _userData!['phoneNumber'] as String? ?? 'N/A'; // Assuming field name is 'phoneNumber'
          final String socialMediaLink = _userData!['socialMediaLink'] as String? ?? '';
          final List<dynamic> locationsRaw = _userData!['locations'] as List<dynamic>? ?? [];
          final List<Map<String, dynamic>> firestoreLocations = List<Map<String, dynamic>>.from(locationsRaw.whereType<Map<String, dynamic>>());

          // Convert Firestore location data to MapLocation objects
          final List<MapLocation> mapLocations = firestoreLocations.map((locData) {
              final geoPoint = locData['geoPoint'] as GeoPoint?;
              if (geoPoint == null) return null; // Skip if no GeoPoint
              return MapLocation(
                name: locData['name'] as String? ?? 'Unnamed Location',
                point: LatLng(geoPoint.latitude, geoPoint.longitude),
                imageUrl: locData['imageUrl'] as String?,
              );
          }).whereType<MapLocation>().toList(); // Filter out any nulls

          final List<dynamic> domainsRaw = _userData!['domains'] as List<dynamic>? ?? [];
          final List<String> domains = List<String>.from(domainsRaw.whereType<String>());

          // Build the main content
          return RefreshIndicator(
            onRefresh: _fetchUserDocument, // Allow pull-to-refresh
            color: _corporateBluePrimary,
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Ensure scrollable even with little content
                padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileDiv(userId: widget.userId), // Assumes ProfileDiv handles its own data fetching/display
                    const SizedBox(height: 16),
                    _buildStatsSection(), // Display calculated stats
                    const SizedBox(height: 16),
                    _buildSectionCard( // About Us section
                      title: 'About Us',
                      icon: Icons.business_center,
                      content: Text(description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _corporateOnSurface, height: 1.5)),
                    ),
                    _buildLocationsSection(mapLocations, isOwner, context), // Locations section
                    _buildDomainsSection(domains, isOwner), // Domains section
                    _buildDetailsSection(contactName, contactEmail, phoneNumber, socialMediaLink, context), // Details section
                  ],
                ),
              ),
          );
        },
      ),
      // Show Add Location FAB only for the owner
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: _showAddLocationDialog,
              tooltip: 'Add Location',
              backgroundColor: _corporateBlueAccent,
              foregroundColor: _onCorporateBlue,
              child: const Icon(Icons.add_location_alt),
            )
          : null,
    );
  }

  /// Builds a standard card wrapper for profile sections.
  Widget _buildSectionCard({ required String title, required IconData icon, required Widget content, Widget? trailing }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center, // Align title and trailing vertically
              children: [
                Row(
                  children: [
                    Icon(icon, color: _corporateBluePrimary, size: 24),
                    const SizedBox(width: 10),
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: _corporateBluePrimary)),
                  ],
                ),
                if (trailing != null) trailing,
              ],
            ),
            const Divider(height: 20, thickness: 1, color: _corporateSurface),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  /// Builds the statistics row (Jobs Created, Fulfilled, Reviews).
  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 1.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(title: 'Jobs Created', value: _jobsCreated, icon: Icons.work_history),
              _StatItem(title: 'Jobs Fulfilled', value: _jobsFulfilled, icon: Icons.check_circle_outline),
              // Use the state variables for rating and review count
              _StatItem(
                  title: 'Reviews',
                  icon: Icons.star_border,
                  rating: _averageRating,
                  reviewCount: _reviewCount
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the locations section with a list and map navigation buttons.
  Widget _buildLocationsSection(List<MapLocation> locations, bool isOwner, BuildContext context) {
      return _buildSectionCard(
      title: 'Locations',
      icon: Icons.location_on,
      trailing: locations.isNotEmpty
          ? TextButton.icon( // Button to view all locations on map
              icon: const Icon(Icons.map, size: 18, color: _corporateBlueAccent),
              label: const Text('View All', style: TextStyle(color: _corporateBlueAccent)),
              onPressed: () => _navigateToMapPage(context, locations),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
            )
          : null, // No button if no locations
      content: locations.isEmpty
          ? Center( // Message when no locations
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No locations listed yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _corporateGreyText)),
              ),
            )
          : ListView.separated( // List of locations
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling within card
              itemCount: locations.length,
              separatorBuilder: (context, index) => Divider(indent: 70, color: _corporateSurface), // Divider between items
              itemBuilder: (context, index) {
                final mapLocation = locations[index];
                final imageUrl = mapLocation.imageUrl;
                final name = mapLocation.name;
                final point = mapLocation.point;

                return ListTile(
                  contentPadding: EdgeInsets.zero, // Adjust padding as needed
                  leading: CircleAvatar( // Location image/icon
                    radius: 25,
                    backgroundColor: _corporateSurface,
                    backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                    child: (imageUrl == null || imageUrl.isEmpty) ? Icon(Icons.business, color: _corporateGreyText) : null,
                  ),
                  title: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _corporateOnSurface)),
                  subtitle: Text('Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _corporateGreyText)),
                  trailing: IconButton( // Button to view single location on map
                    icon: const Icon(Icons.map_outlined, color: _corporateBlueAccent),
                    tooltip: 'View on Map',
                    onPressed: () => _navigateToMapPage(context, [mapLocation], initialCenter: point),
                  ),
                  onTap: () => _navigateToMapPage(context, [mapLocation], initialCenter: point), // Allow tapping whole item
                );
              },
            ),
    );
  }

  /// Navigates to the CompanyLocationsMapPage.
  void _navigateToMapPage(BuildContext context, List<MapLocation> locationsToShow, {LatLng? initialCenter}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyLocationsMapPage(
          locations: locationsToShow,
          initialCenter: initialCenter,
        ),
      ),
    );
  }

  /// Builds the domains section with chips.
  Widget _buildDomainsSection(List<String> domains, bool isOwner) {
    return _buildSectionCard(
      title: 'Domains',
      icon: Icons.category,
      trailing: isOwner // Show Add button only for owner
          ? IconButton(
              icon: const Icon(Icons.add_circle_outline, color: _corporateBlueAccent),
              tooltip: 'Add Domain',
              onPressed: _showAddDomainDialog,
            )
          : null,
      content: domains.isEmpty
          ? Center( // Message when no domains
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No specific domains listed.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _corporateGreyText)),
              ),
            )
          : _buildDomainsChipsWidget(domains), // Display chips if domains exist
    );
  }

  /// Helper to build the Wrap widget containing domain chips.
  Widget _buildDomainsChipsWidget(List<String> domains) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    // Determine label color based on chip background brightness
    final Color labelColor = ThemeData.estimateBrightnessForColor(_corporateBlueAccent) == Brightness.dark
        ? _onCorporateBlue : _corporateOnSurface;

    return Wrap(
      spacing: 8.0, // Horizontal spacing between chips
      runSpacing: 4.0, // Vertical spacing between lines of chips
      children: domains.map((domain) => Chip(
        label: Text(domain),
        backgroundColor: _corporateBlueAccent,
        labelStyle: textTheme.labelLarge?.copyWith(color: labelColor),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
      )).toList(),
    );
  }

  /// Builds the expandable section for company contact details.
  Widget _buildDetailsSection(String name, String email, String phone, String social, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: Colors.white,
      child: ExpansionTile( // Use ExpansionTile for collapsibility
        initiallyExpanded: false, // Start collapsed
        leading: const Icon(Icons.info_outline, color: _corporateBluePrimary),
        title: Text('Company Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: _corporateBluePrimary)),
        childrenPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Padding for content inside
        iconColor: _corporateBluePrimary, // Color for expand/collapse icon
        collapsedIconColor: _corporateBluePrimary,
        children: [ // List of detail rows
          _buildCopyableInfo('Company Name', name, Icons.business, context),
          Divider(height: 24, color: _corporateSurface),
          _buildCopyableInfo('Contact Email', email, Icons.email_outlined, context),
          Divider(height: 24, color: _corporateSurface),
          _buildCopyableInfo('Phone Number', phone, Icons.phone_outlined, context),
          Divider(height: 24, color: _corporateSurface),
          _buildLinkableInfo('Social Media / Website', social, Icons.link, context), // Clarified label
        ],
      ),
    );
  }

  /// Helper to build a row for information that can be copied.
  Widget _buildCopyableInfo(String label, String value, IconData icon, BuildContext context) {
    final String displayValue = (value.isEmpty || value == 'N/A') ? 'Not Provided' : value;
    final bool canCopy = displayValue != 'Not Provided';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: _corporateGreyText, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _corporateGreyText, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(displayValue, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: canCopy ? _corporateOnSurface : _corporateGreyText)),
            ],
          ),
        ),
        SizedBox( // Constrain IconButton size
          width: 48, height: 48,
          child: canCopy ? IconButton( // Show copy button only if value exists
                icon: const Icon(Icons.copy, size: 18, color: _corporateBlueAccent),
                tooltip: 'Copy $label',
                padding: EdgeInsets.zero,
                alignment: Alignment.center,
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture context
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!mounted) return; // Check mounted after async gap
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Copied $label to clipboard'), duration: const Duration(seconds: 2)));
                },
              ) : null, // No button if no value
        )
      ],
    );
  }

  /// Helper to build a row for information that is a clickable link.
  Widget _buildLinkableInfo(String label, String value, IconData icon, BuildContext context) {
    final String displayValue = (value.isEmpty) ? 'Not Provided' : value;
    // Check if the value is a valid absolute URL before enabling launch
    final bool canLaunch = displayValue != 'Not Provided' && Uri.tryParse(value)?.isAbsolute == true;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: _corporateGreyText, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _corporateGreyText, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              // Style link differently if launchable
              Text(displayValue, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: canLaunch ? _corporateBlueAccent : _corporateOnSurface), overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          ),
        ),
        SizedBox( // Constrain IconButton size
          width: 48, height: 48,
          child: canLaunch ? IconButton( // Show launch button only if valid link
                icon: const Icon(Icons.open_in_new, size: 18, color: _corporateBlueAccent),
                tooltip: 'Open $label',
                padding: EdgeInsets.zero, alignment: Alignment.center,
                onPressed: () async {
                    final Uri? uri = Uri.tryParse(value);
                    if (uri != null) {
                      try {
                        // Attempt to launch URL externally
                        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $label'), backgroundColor: _corporateWarningColor));
                        }
                      } catch (e) {
                        if (kDebugMode) { print("Error launching URL: $e"); }
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching link: $e'), backgroundColor: _corporateErrorColor));
                      }
                    }
                },
              ) : null, // No button if not launchable
        )
      ],
    );
  }

  /// Shows the dialog for adding a new company location. (Owner only)
  void _showAddLocationDialog() {
    if (_currentUserId == null || _currentUserId != widget.userId) return; // Owner check

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final imageController = TextEditingController();
    LatLng? selectedPoint; // Store selected coordinates
    final MapController mapController = MapController(); // Controller for the picker map

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (dialogContext) => StatefulBuilder( // Use StatefulBuilder to update map marker
        builder: (stfContext, setDialogState) {

          final screenSize = MediaQuery.of(stfContext).size;
          final List<Marker> markers = []; // Markers for the picker map
          if (selectedPoint != null) { // Add marker if a point is selected
            markers.add(
              Marker(
                width: 80.0, height: 80.0, point: selectedPoint!,
                child: const Icon(Icons.location_pin, color: _corporateBlueAccent, size: 30.0),
              ),
            );
          }

          // Define input decoration theme for the dialog
          final inputDecorationTheme = InputDecorationTheme(
            iconColor: _corporateBluePrimary,
            labelStyle: const TextStyle(color: _corporateBluePrimary),
            hintStyle: const TextStyle(color: _corporateGreyText),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _corporateBlueAccent, width: 2.0),
                borderRadius: BorderRadius.circular(8.0)
            ),
            enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _corporateGreyText),
                borderRadius: BorderRadius.circular(8.0)
            ),
          );

          return AlertDialog(
            title: const Text('Add New Location', style: TextStyle(color: _corporateBluePrimary)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
            backgroundColor: Colors.white,
            content: SizedBox( // Constrain dialog content size
              width: screenSize.width * 0.9,
              height: screenSize.height * 0.7,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Theme( // Apply theme to dialog inputs
                    data: Theme.of(context).copyWith(inputDecorationTheme: inputDecorationTheme),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Location Name Input
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Location Name *', hintText: 'e.g., Headquarters', icon: Icon(Icons.label_important_outline)),
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        // Map Picker Label
                        const Text("Tap on the map to select location:", style: TextStyle(fontWeight: FontWeight.bold, color: _corporateOnSurface)),
                        const SizedBox(height: 8),
                        // Map Picker Widget
                        Container(
                          height: 250, // Fixed height for the map
                          decoration: BoxDecoration( border: Border.all(color: _corporateGreyText), borderRadius: BorderRadius.circular(8), ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedPoint ?? _defaultInitialPickerCenter,
                              initialZoom: selectedPoint != null ? _selectedPickerZoom : _defaultPickerZoom,
                              onTap: (TapPosition tapPosition, LatLng point) {
                                // Update selected point and map view on tap
                                setDialogState(() { selectedPoint = point; });
                                mapController.move(point, _selectedPickerZoom);
                              },
                            ),
                            children: [
                              TileLayer( urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.skillxchange.app', tileProvider: CancellableNetworkTileProvider(), ),
                              RichAttributionWidget( attributions: [ TextSourceAttribution( 'OpenStreetMap contributors', onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')), ), ], alignment: AttributionAlignment.bottomLeft, ),
                              MarkerLayer(markers: markers), // Show selected marker
                            ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Display selected coordinates or prompt
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            selectedPoint == null
                              ? 'Please tap the map above to select.'
                              : 'Selected: (${selectedPoint!.latitude.toStringAsFixed(5)}, ${selectedPoint!.longitude.toStringAsFixed(5)})',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selectedPoint == null ? _corporateGreyText : Colors.green[700],
                              fontStyle: selectedPoint == null ? FontStyle.italic : FontStyle.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Optional Image URL Input
                        TextFormField(
                          controller: imageController,
                          decoration: const InputDecoration(labelText: 'Image URL (Optional)', hintText: 'https://example.com/image.jpg', icon: Icon(Icons.image_outlined)),
                          keyboardType: TextInputType.url,
                          validator: (value) { // Basic URL validation
                            if (value != null && value.isNotEmpty && Uri.tryParse(value)?.isAbsolute != true) {
                              return 'Enter a valid URL (e.g., https://...)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [ // Dialog Actions
              TextButton(
                onPressed: () => Navigator.pop(dialogContext), // Cancel button
                child: const Text('Cancel', style: TextStyle(color: _corporateBlueAccent)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add Location'),
                // Disable button if no location is selected
                onPressed: selectedPoint == null ? null : () async {
                  if (formKey.currentState!.validate()) { // Validate form inputs
                      final newLocation = {
                        'name': nameController.text.trim(),
                        'geoPoint': GeoPoint(selectedPoint!.latitude, selectedPoint!.longitude), // Save as GeoPoint
                        'imageUrl': imageController.text.trim().isEmpty ? null : imageController.text.trim(), // Save null if empty
                      };
                      Navigator.pop(dialogContext); // Close dialog first
                      await _addLocation(newLocation); // Call Firestore update function
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corporateBluePrimary, foregroundColor: _onCorporateBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  // Style disabled state to look less prominent
                  disabledBackgroundColor: _corporateBluePrimary.withOpacity(0.5),
                  disabledForegroundColor: _onCorporateBlue.withOpacity(0.7),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  /// Shows the dialog for adding a new company domain. (Owner only)
  void _showAddDomainDialog() {
    if (_currentUserId == null || _currentUserId != widget.userId) return; // Owner check

    final formKey = GlobalKey<FormState>();
    final domainController = TextEditingController();

    // Define input decoration theme for the dialog
    final inputDecorationTheme = InputDecorationTheme(
        iconColor: _corporateBluePrimary,
        labelStyle: const TextStyle(color: _corporateBluePrimary),
        hintStyle: const TextStyle(color: _corporateGreyText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _corporateBlueAccent, width: 2.0),
            borderRadius: BorderRadius.circular(8.0)
        ),
        enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _corporateGreyText),
            borderRadius: BorderRadius.circular(8.0)
        ),
      );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Domain', style: TextStyle(color: _corporateBluePrimary)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        backgroundColor: Colors.white,
        content: Theme( // Apply theme to dialog input
          data: Theme.of(context).copyWith(inputDecorationTheme: inputDecorationTheme),
          child: Form(
            key: formKey,
            child: TextFormField( // Domain Name Input
              controller: domainController,
              decoration: const InputDecoration(labelText: 'Domain Name *', hintText: 'e.g., Web Development', icon: Icon(Icons.category_outlined)),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
          ),
        ),
        actions: [ // Dialog Actions
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Cancel button
            child: const Text('Cancel', style: TextStyle(color: _corporateBlueAccent)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_circle),
            label: const Text('Add Domain'),
            onPressed: () async {
              if (formKey.currentState!.validate()) { // Validate form
                final newDomain = domainController.text.trim();
                Navigator.pop(dialogContext); // Close dialog first
                await _addDomain(newDomain); // Call Firestore update function
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _corporateBluePrimary, foregroundColor: _onCorporateBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
        ],
      ),
    );
  }
}


/// A helper widget to display a single statistic item in the stats row.
class _StatItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final int? value;        // For simple counts like Jobs Created/Fulfilled
  final double? rating;     // For average rating
  final int? reviewCount; // For the number of reviews

  const _StatItem({
    required this.title,
    required this.icon,
    this.value,
    this.rating,
    this.reviewCount,
  });

  // Define colors used within this widget for consistency
  static const Color _corporateBluePrimary = Color(0xFF0D47A1);
  static const Color _corporateGreyText = Colors.grey;
  static final Color _starColor = Colors.amber.shade700;

  @override
  Widget build(BuildContext context) {
    Widget valueWidget; // The widget to display the value/rating

    // Decide what to display based on provided values
    if (rating != null && reviewCount != null && reviewCount! > 0) {
      // Display Rating and Count (only if count > 0)
      valueWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.star, color: _starColor, size: 20),
          const SizedBox(width: 4),
          Text( rating!.toStringAsFixed(1), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _corporateBluePrimary) ),
          const SizedBox(width: 4),
          Text( '(${reviewCount!})', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _corporateGreyText, fontSize: 12) ),
        ],
      );
    } else if (value != null) {
      // Display simple integer value
      valueWidget = Text( value.toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _corporateBluePrimary) );
    } else {
      // Fallback: Show N/A if review count is 0, otherwise show a dash
      valueWidget = Text(
        (reviewCount != null && reviewCount == 0) ? "N/A" : "-",
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _corporateGreyText)
      );
    }

    // Build the column structure for the stat item
    return Column(
      mainAxisSize: MainAxisSize.min, // Take minimum vertical space
      children: [
        Icon(icon, size: 28, color: _corporateBluePrimary), // Icon
        const SizedBox(height: 4),
        valueWidget, // Display the determined value/rating widget
        const SizedBox(height: 2),
        Text( // Title text
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _corporateGreyText)
        ),
      ],
    );
  }
}