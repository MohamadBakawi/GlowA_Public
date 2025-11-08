import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rayanpharma/pages/insert_products.dart';
import 'package:rayanpharma/pages/map_screen.dart';
import 'package:rayanpharma/widgets/card_div.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rayanpharma/pages/product_details.dart';
import 'package:rayanpharma/widgets/search_page.dart';
import 'package:rayanpharma/pages/user_profile_page.dart';
import 'package:rayanpharma/pages/image.dart';
class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  // Dropdown items and values
  final List<String> categories = ['All', 'Dry Skin', 'Normal Skin', 'Oily Skin'];
  final List<String> sortOptions = ['Popularity', 'Price: Low to High', 'Price: High to Low'];
  final List<String> brands = ['All Brands', 'Brand A', 'Brand B', 'Brand C'];
  // Make sure these values match the logic exactly
  final List<String> stockStatus = ['All','Abundunt Stock', 'In Stock', 'Low Stock'];
  final List<String> priceRange = ['All', '<\$10', '\$10-\$50', '>\$50']; // This filter is not yet implemented

  String selectedCategory = 'All';
  String selectedSort = 'Popularity';
  String selectedBrand = 'All Brands';
  String selectedStock = 'In Stock'; // This will now control stock filtering
  String selectedPrice = 'All'; // Price range filter state
  final String wideImageUrl = 'https://via.placeholder.com/800x100.png?text=Wide+Banner+Ad';
  late String userId = '';
  final TextEditingController _searchController = TextEditingController();

  // Define the threshold for low stock
  final int lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
       _initializeUserData(); // Call a combined init function

  }
  
  bool? _isUserCompany;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
 Future<void> _initializeUserData() async { // Create or adapt this
   User? user = FirebaseAuth.instance.currentUser;
   if (user != null) {
     if (mounted) setState(() => userId = user.uid);
     await _fetchUserCompanyStatus(); // Fetch status after getting ID
   } else {
     debugPrint("No user logged in.");
     if (mounted) setState(() => _isUserCompany = false);
   }
 }
  void getCurrentUser() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) {
         setState(() => userId = user.uid);
      }
    } else {
      debugPrint("No user logged in.");
    }
  }

  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsPage(searchString: query,),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildFilterBar(), // Contains all filter dropdowns
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildImageCarousel(),
                  const SizedBox(height: 24),
                  // Each section will now apply all filters and sorting
                  _buildProductSection('For everyday users', 'Normal Skin'),
                  const SizedBox(height: 24),
                  _buildProductSection('For users with hypersebacous skin', 'Oily Skin'),
                  const SizedBox(height: 24),
                  _buildWideBanner(),
                  const SizedBox(height: 24),
                  _buildProductSection('For users with dry skin', 'Dry Skin'),
                  const SizedBox(height: 24),
                  _buildImageCarousel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    // ... (AppBar code remains the same)
    return AppBar(
      backgroundColor: Colors.tealAccent,
      titleSpacing: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLogo(),
          _buildSearchBar(),
          _buildProfileIcon(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    // ... (Logo code remains the same)
        try {
      return Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: SvgPicture.asset(
          'assets/logo.svg',
          height: 32.0,
          placeholderBuilder: (context) => const Icon(Icons.image, size: 32), // Placeholder
        ),
      );
    } catch (e) {
       debugPrint("Error loading logo SVG: $e");
       return const Padding( // Fallback widget
         padding: EdgeInsets.only(left: 16.0),
         child: Icon(Icons.business, size: 32, color: Colors.white),
       );
    }
  }

  Widget _buildSearchBar() {
    // ... (Search bar code remains the same)
        return Container(
      width: MediaQuery.of(context).size.width * 0.5,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
          suffixIcon: IconButton(
             icon: const Icon(Icons.arrow_forward, size: 20, color: Colors.teal),
             tooltip: 'Search',
             onPressed: _handleSearch, // Trigger search on button press
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // Adjust padding
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder( // Optional: style when focused
             borderRadius: BorderRadius.circular(30),
             borderSide: const BorderSide(color: Colors.teal, width: 1.5),
          ),
        ),
        onSubmitted: (_) => _handleSearch(), // Trigger search on keyboard submit
      ),
    );
  }

Widget _buildProfileIcon() {
  return Row(
    mainAxisSize: MainAxisSize.min, // Take minimum space needed
    children: [
      // --- Profile Icon Button ---
      if (userId.isNotEmpty) // Only show profile if userId is available
        IconButton(
          icon: const Icon(Icons.person_outline, size: 28, color: Colors.white),
          tooltip: 'Profile',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserProfilePage(userId: userId)),
          ),
        ),

      // --- Map Icon Button ---
      IconButton(
        icon: const Icon(Icons.location_on_outlined, size: 28, color: Colors.white), // Changed icon
        tooltip: 'Find Stores',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        ),
      ),

      // --- Add Product Icon Button ---
      // Consider user roles before showing InsertProducts
      // For now, assume any logged-in user can access it
if (userId.isNotEmpty && (_isUserCompany ?? false)) // Check state variable
  IconButton(
    icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.white),
    tooltip: 'Add Product',
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InsertProducts()),
    ),
  ),

      // --- Camera / Classification Icon Button ---
      IconButton(
        icon: const Icon(Icons.camera_alt_outlined, size: 28, color: Colors.white), // Consistent icon
        tooltip: 'Classify Skin Type', // Updated tooltip
        // The onPressed callback for THIS button:
        onPressed: () async { // <-- ASYNC HERE
          // Navigate to ClassificationPage and wait for a result
          final result = await Navigator.push<String?>( // <-- AWAIT and specify result type String?
            context,
            MaterialPageRoute(builder: (context) => const ClassificationPage()),
          );

          // Check if we got a result back (user didn't just press back button)
          // AND if the result indicates oily skin
          if (result != null && result == 'hypersebaceous') {
            debugPrint("Classification result: $result. Setting category to Oily Skin.");
            // Update the selected category in MainMenu's state
            // Check if the widget is still mounted before calling setState
            if (mounted) {
              setState(() {
                selectedCategory = 'Oily Skin'; // Assuming 'Oily Skin' is an exact match in your categories list
              });
              // Optional: Show a confirmation message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Skin type classified as Oily. Filter updated.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else if (result != null) {
            debugPrint("Classification result: $result. No filter change needed.");
            // Optional: Show feedback for other results if desired
            // if (mounted) {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //      SnackBar(content: Text('Skin type classified as $result.')),
            //   );
            // }
          } else {
            debugPrint("Classification cancelled or no result returned.");
          }
        }, // End of onPressed for Camera Button
      ), // End of Camera IconButton

      const SizedBox(width: 8), // Add some padding to the right edge
    ], // End of Row children
  ); // End of Row
} // End of _buildProfileIcon method
  Widget _buildFilterBar() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterDropdown(
              value: selectedCategory,
              items: categories,
              onChanged: (v) => setState(() => selectedCategory = v!),
              hint: 'Category',
            ),
            const SizedBox(width: 12),
            _buildFilterDropdown(
              value: selectedSort,
              items: sortOptions,
              onChanged: (v) => setState(() => selectedSort = v!),
              hint: 'Sort By',
            ),
            const SizedBox(width: 12),
            _buildFilterDropdown(
              value: selectedBrand,
              items: brands,
              onChanged: (v) => setState(() => selectedBrand = v!),
              hint: 'Brand',
            ),
             const SizedBox(width: 12),
            _buildFilterDropdown(
              value: selectedStock,
              items: stockStatus,
              // ***** IMPORTANT: setState triggers rebuild *****
              // This rebuild will cause _buildProductStream's builder
              // to re-run and apply the new STOCK FILTER based on selectedStock
              onChanged: (v) => setState(() => selectedStock = v!),
              hint: 'Stock',
            ),
            // Price Range dropdown is present but its filtering logic is not yet implemented
            // const SizedBox(width: 12),
            // _buildFilterDropdown(
            //   value: selectedPrice,
            //   items: priceRange,
            //   onChanged: (v) => setState(() => selectedPrice = v!),
            //   hint: 'Price',
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    // ... (Dropdown code remains the same)
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 150), // Use constraints
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Adjust padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // More rounded
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [ // Subtle shadow
           BoxShadow(
             color: Colors.grey.withOpacity(0.1),
             spreadRadius: 1,
             blurRadius: 2,
             offset: const Offset(0, 1),
           ),
        ]
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true, // Ensures hint is visible and respects width
          icon: const Icon(Icons.arrow_drop_down, size: 20, color: Colors.teal),
          style: const TextStyle(fontSize: 13, color: Colors.black87), // Style text
          items: items.map((String itemValue) {
            return DropdownMenuItem<String>(
              value: itemValue,
              child: Text(
                itemValue,
                style: const TextStyle(fontSize: 13), // Consistent font size
                overflow: TextOverflow.ellipsis, // Prevent long text overflow
              ),
            );
          }).toList(),
          onChanged: onChanged,
          hint: Text( // Display hint properly
             hint,
             style: TextStyle(fontSize: 13, color: Colors.grey[600]),
             overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // --- Product Section and Stream ---

  Widget _buildProductSection(String title, String productType) {
    // ... (Product section title/layout code remains the same)
        return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align title left
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          // Use Row for better alignment of title and "View All"
          child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                TextButton(
                  onPressed: () => _viewAllProducts(productType),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero), // Reduce padding
                  child: const Text(
                    'View All',
                    style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w500), // Use theme color
                  ),
                ),
             ],
          ),
        ),
        const SizedBox(height: 12), // Adjust spacing
        // _buildProductStream now handles all filtering and sorting
        _buildProductStream(productType),
      ],
    );
  }

  Widget _buildProductStream(String productType) {
    Query productsQuery = FirebaseFirestore.instance
        .collection('products')
        .where('keyWords', arrayContains: productType);

    return StreamBuilder<QuerySnapshot>(
      stream: productsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorWidget(snapshot.error!);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingIndicator();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(productType);
        }

        final allDocs = snapshot.data!.docs;
        List<QueryDocumentSnapshot> categoryFilteredDocs;
        List<QueryDocumentSnapshot> stockFilteredDocs;
        List<QueryDocumentSnapshot> sortedDocs; // Final list after sorting

        // --- 1. CATEGORY FILTERING ---
        if (selectedCategory == 'All') {
          categoryFilteredDocs = allDocs;
        } else {
          categoryFilteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final skinTypes = data?['keyWords']; // Using keyWords as example
            if (skinTypes is List) {
              try {
                final skinTypeList = List<String>.from(skinTypes.map((e) => e.toString()));
                return skinTypeList.contains(selectedCategory);
              } catch (e) { return false; }
            } else if (skinTypes is String) {
              return skinTypes == selectedCategory;
            }
            return false;
          }).toList();
        }

        // --- 2. STOCK FILTERING ---
        // Operate on the results of category filtering
        if (selectedStock == 'All') {
          stockFilteredDocs = categoryFilteredDocs;
        } else {
          stockFilteredDocs = categoryFilteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            // *** IMPORTANT ASSUMPTION: 'quantity' field exists and is a number ***
            final quantityNum = data['quantity'] as num?;
            // Treat null quantity as 0 for comparison purposes
            final quantity = quantityNum?.toInt() ?? 0;

            if (selectedStock == 'Low Stock') {
              // Show items with quantity less than or equal to the threshold
              return quantity <= lowStockThreshold;
            } else if (selectedStock == 'In Stock') {
              // Show items with quantity greater than the threshold
              return quantity > 0;
            }
             else if (selectedStock == 'Abundunt Stock') {
              // Show items with quantity greater than the threshold
              return quantity > lowStockThreshold;
            }
            return true; // Should not happen if selectedStock is validated, but default to true
          }).toList();
        }

        // --- Handle Empty List After Filtering ---
        if (stockFilteredDocs.isEmpty) {
           // Provide a more specific message based on active filters
           String emptyMsg = "No $productType found";
           if (selectedCategory != 'All') emptyMsg += " for $selectedCategory";
           if (selectedStock != 'All') emptyMsg += " with ${selectedStock.toLowerCase()} status";
           emptyMsg += ".";

           return Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
             child: Center(
               child: Text(
                 emptyMsg,
                 textAlign: TextAlign.center,
                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
               ),
             ),
           );
        }


        // --- 3. SORTING LOGIC ---
        // Operate on the results of stock filtering
        sortedDocs = List.from(stockFilteredDocs); // Create a mutable copy

        int comparePrices(QueryDocumentSnapshot a, QueryDocumentSnapshot b, {bool ascending = true}) {
           final dataA = a.data() as Map<String, dynamic>? ?? {};
           final dataB = b.data() as Map<String, dynamic>? ?? {};
           final priceA = (dataA['price'] as num?)?.toDouble() ?? (ascending ? double.maxFinite : 0.0);
           final priceB = (dataB['price'] as num?)?.toDouble() ?? (ascending ? double.maxFinite : 0.0);
           return ascending ? priceA.compareTo(priceB) : priceB.compareTo(priceA);
        }

        if (selectedSort == 'Price: Low to High') {
          sortedDocs.sort((a, b) => comparePrices(a, b, ascending: true));
        } else if (selectedSort == 'Price: High to Low') {
          sortedDocs.sort((a, b) => comparePrices(a, b, ascending: false));
        }
        // Add other sort options like 'Popularity' if needed, potentially using a 'rating' or 'sales' field


        // --- Pass the final filtered AND sorted list to the list builder ---
        return _buildProductList(sortedDocs);
      },
    );
  }

  // _buildProductList receives the final filtered and sorted list
  Widget _buildProductList(List<QueryDocumentSnapshot> docs) {
     if (docs.isEmpty) {
       // This state should be handled within the StreamBuilder after filtering.
       // Returning an empty container or minimal message here.
       return const SizedBox(height: 250, child: Center(child: Text("No products match the selected filters.")));
     }

    return SizedBox(
      height: 250, // Match loading indicator height
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final productId = doc.id;

          // Extract data safely
          final imageUrl = data['imageUrl'] as String? ?? 'https://via.placeholder.com/150?text=No+Image';
          final title = data['name'] as String? ?? 'Unknown Product';
          final description = data['description'] as String? ?? 'No description.';
          final priceNum = data['price'] as num?;
          final price = priceNum?.toDouble() ?? 0.0;
          final companyId = data['companyId'] as String? ?? '';
          final isBookmarked = data['isBookmarked'] as bool? ?? false;
          // We don't necessarily need to display quantity here, but it was used for filtering
          // final quantity = (data['quantity'] as num?)?.toInt() ?? 0;

          List<Map<String, dynamic>> reviews = [];
          if (data['reviews'] is List) {
            try {
              reviews = List<Map<String, dynamic>>.from(
                (data['reviews'] as List).whereType<Map<String, dynamic>>()
              );
            } catch (e) {
              debugPrint('Error parsing reviews for product $productId: $e');
            }
          }

          // Use the CardDiv widget
          return SizedBox(
             width: 180,
             child: CardDiv(
                key: ValueKey(productId),
                imageUrl: imageUrl,
                title: title,
                description: description,
                reviews: reviews,
                companyId: companyId,
                ID: productId,
                isBookmarked: isBookmarked,
                onBookmarkToggle: () => _toggleBookmark(productId),
                price: price,
                onTap: () {
                  debugPrint('Navigating to product detail with ID: $productId');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(
                        productId: productId,
                        imageUrl: imageUrl,
                        title: title,
                        description: description,
                        price: price,
                        reviews: reviews,
                      ),
                    ),
                  );
                },
             ),
          );
        },
      ),
    );
  }


  // --- Other Helper Widgets and Methods (unchanged) ---

  Widget _buildImageCarousel() {
    // ... (Image Carousel code remains the same)
        final List<String> carouselImages = [
       'https://picsum.photos/id/1060/800/400?blur=2',
       'https://picsum.photos/id/1040/800/400',
       'https://picsum.photos/id/10/800/400',
    ];

    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: carouselImages.length, // Use the length of the image list
        controller: PageController(viewportFraction: 0.92, initialPage: 1), // Start in middle, slight peek
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Card( // Wrap in Card for elevation/styling
              elevation: 4.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias, // Clip the image to the card shape
              child: Image.network(
                carouselImages[index], // Use image from the list
                fit: BoxFit.cover,
                // Add loading and error builders for network images
                loadingBuilder: (context, child, loadingProgress) {
                   if (loadingProgress == null) return child;
                   return Center(child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      strokeWidth: 2,
                   ));
                },
                errorBuilder: (context, error, stackTrace) {
                   return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50));
                },
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildWideBanner() {
    // ... (Wide Banner code remains the same)
        if (wideImageUrl.isEmpty) return const SizedBox.shrink(); // Don't build if URL is empty

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjust margin
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200], // Placeholder color
        boxShadow: [ // Add shadow
           BoxShadow(
             color: Colors.grey.withOpacity(0.2),
             spreadRadius: 1,
             blurRadius: 4,
             offset: const Offset(0, 2),
           )
        ]
      ),
      child: ClipRRect( // Clip the image to rounded corners
         borderRadius: BorderRadius.circular(12),
         child: Image.network(
            wideImageUrl,
            fit: BoxFit.cover,
            width: double.infinity, // Ensure it takes full width
            // Add loading/error builders similar to the carousel
             loadingBuilder: (context, child, loadingProgress) {
               if (loadingProgress == null) return child;
               return const Center(child: CircularProgressIndicator(strokeWidth: 2));
             },
             errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text("Banner Ad", style: TextStyle(color: Colors.grey)));
             },
         ),
      ),
    );
  }

  Widget _buildErrorWidget(dynamic error) {
    // ... (Error widget code remains the same)
        debugPrint("Firestore Error: $error"); // Log the full error
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center( // Center the error message
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center, // Center vertically
           crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
           children: [
             const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
             const SizedBox(height: 16),
             Text(
               'Error Loading Products',
               style: Theme.of(context).textTheme.titleMedium?.copyWith( // Adjusted style
                 color: Colors.black87,
                 fontWeight: FontWeight.w500,
               ),
             ),
             const SizedBox(height: 8),
             Text(
               _parseFirebaseError(error),
               textAlign: TextAlign.center,
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
             ),
             const SizedBox(height: 16),
             ElevatedButton.icon( // Add a retry button maybe?
                onPressed: () => setState(() {}), // Basic retry: force rebuild
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
             )
           ],
         ),
      ),
    );
  }
Future<void> _fetchUserCompanyStatus() async {
  if (userId.isEmpty || !mounted) {
    if (mounted) setState(() => _isUserCompany = false);
    return;
  }
  try {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    bool isCompany = false; // Default to false
    if (userDoc.exists && userDoc.data() != null) {
      isCompany = userDoc.data()!['isCompany'] ?? false; // Check field, default to false
    }
    if (mounted) {
      setState(() => _isUserCompany = isCompany);
    }
  } catch (e) {
    debugPrint("Error fetching user company status: $e");
    if (mounted) {
      setState(() => _isUserCompany = false); // Default to false on error
    }
  }
}
  String _parseFirebaseError(dynamic error) {
    // ... (Error parsing code remains the same)
        if (error is FirebaseException) {
      // Provide user-friendly messages for common errors
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to access these products. Please check your login status or contact support.';
        case 'unavailable':
          return 'Could not connect to the database. Please check your internet connection and try again.';
        case 'unauthenticated':
           return 'You need to be logged in to view products.';
        case 'not-found':
           return 'The requested data could not be found.';
         // Add more specific Firestore error codes as needed
        default:
          // For less common errors, show a generic message or the code itself for debugging
          return 'An unexpected error occurred (${error.code}). Please try again later.';
          // return error.message ?? 'An unknown Firestore error occurred.'; // Can be too technical
      }
    }
    // Handle non-Firebase errors
    return 'Failed to load data due to an unexpected issue. Please try again.';
  }

  Widget _buildEmptyState(String productType) {
    // ... (Empty state code remains the same - generic message for when initial fetch is empty)
        return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16), // More padding
      child: Center(
        child: Column( // Use column for icon + text
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.production_quantity_limits, size: 40, color: Colors.grey[400]), // Changed icon slightly
             const SizedBox(height: 16),
             Text(
               'No ${productType}s available right now.', // Generic message for initial load
               textAlign: TextAlign.center,
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                 color: Colors.grey[600],
               ),
             ),
             const SizedBox(height: 8),
             Text(
                "Check back later or try adjusting the filters.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
             ),
           ],
        ),
      ),
    );
  }

  void _toggleBookmark(String productId) {
    // ... (Bookmark toggle placeholder remains the same)
     debugPrint("Toggle bookmark for product ID: $productId (Implementation needed)");
     setState(() {
     });
  }


  void _viewAllProducts(String productType) {
    // ... (View All placeholder remains the same)
     debugPrint("Navigate to view all '$productType' products (Implementation needed)");
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Navigation for 'View All $productType' not implemented yet."), duration: const Duration(seconds: 2),)
     );
  }
}

// --- Loading Indicator Widget ---
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    // ... (Loading Indicator remains the same)
     return const SizedBox( // Give it a fixed height matching the list view
       height: 250, // Match _buildProductList height
       child: Center(
         child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal), // Use theme color
         ),
       ),
    );
  }
}


// --- Dummy Page for Navigation Placeholders ---
class AllProductsPage extends StatelessWidget {
  final String productType;
  const AllProductsPage({super.key, required this.productType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("All $productType")),
      body: Center(child: Text("List of all $productType products will be shown here.")),
    );
  }
}