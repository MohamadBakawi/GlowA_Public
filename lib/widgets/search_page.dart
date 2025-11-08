import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// Ensure this import path is correct for your CardDiv widget
// Assuming CardDiv is in 'package:rayanpharma/widgets/card_div.dart' based on original code
import 'package:rayanpharma/widgets/card_div.dart'; // Replace with your actual path if different

// --- Data Class for Product ---
class Product {
  final String id;
  final String name; // Original name for display
  final String searchName; // Lowercase name for searching
  final String description;
  final String imageUrl;
  final double price;
  final List<String> keywords; // Still useful for secondary client-side filtering if needed
  final String category;
  final double rating;
  final String companyId;

  Product({
    required this.id,
    required this.name,
    required this.searchName, // Add searchName to constructor
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.keywords,
    required this.category,
    required this.rating,
    required this.companyId,
  });

  // Factory constructor to create a Product from Firestore data
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    // Helper function to safely get list of strings (lowercase for consistent matching)
    List<String> _getListStrings(dynamic value) {
      if (value is List) {
        // Filter out non-string elements and convert to lowercase
        return value.whereType<String>().map((s) => s.toLowerCase()).toList();
      }
      return [];
    }

    // Get original name, provide default
    String originalName = data['name'] as String? ?? 'No Name';
    // Get searchName, OR if missing, derive from originalName and lowercase it
    String searchNameValue = data['searchName'] as String? ?? originalName.toLowerCase();

    // Default values provide resilience against missing/null data in Firestore
    return Product(
      id: doc.id,
      name: originalName, // Use the original name
      searchName: searchNameValue, // Use the dedicated searchName field
      description: data['description'] as String? ?? 'No Description',
      imageUrl:
          data['imageUrl'] as String? ?? 'https://via.placeholder.com/150', // Default image
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      keywords: _getListStrings(data['keyWords']), // Keep keywords for potential future use
      category: data['category'] as String? ?? 'Uncategorized',
      rating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      companyId: data['companyId'] as String? ?? data['owner'] as String? ?? '',
    );
  }
}

// --- Search Results Page ---
class SearchResultsPage extends StatefulWidget {
  final String searchString;
  final String? initialFilterCategory;

  const SearchResultsPage({
    super.key,
    required this.searchString,
    this.initialFilterCategory,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  // State Variables
  bool _isLoading = true;
  String? _error;
  List<Product> _allMatchingProducts = []; // Holds ALL products matching Firestore query
  List<Product> _filteredProducts = []; // Holds products after applying secondary filters

  // Filter State
  double _priceRangeMax = 1000;
  double _selectedPriceMax = 1000;
  final List<String> _availableCategories = [
    'All', 'Ointments', 'Face Creams', 'Shampoos', 'Electronics', 'Fashion', 'Home', 'Beauty'
  ]; // TODO: Fetch dynamically
  final Set<String> _selectedCategories = {};
  int _selectedRatingMin = 0; // 0 = Any rating

  @override
  void initState() {
    super.initState();
    if (widget.initialFilterCategory != null &&
        _availableCategories.contains(widget.initialFilterCategory)) {
      _selectedCategories.add(widget.initialFilterCategory!);
    } else if (widget.initialFilterCategory == null) {
       // Default to 'All' if no specific category is passed
       _selectedCategories.add('All');
    }
    _fetchAndFilterProducts();
  }

  // --- Core Data Fetching using Firestore Query ---
  Future<void> _fetchAndFilterProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _allMatchingProducts = []; // Clear previous results
      _filteredProducts = [];
    });

    try {
      final firestore = FirebaseFirestore.instance;
      // Normalize search term ONCE for the Firestore query
      final searchTermLower = widget.searchString.toLowerCase().trim();

      // --- Firestore Query Construction ---
      Query query = firestore.collection('products');

      // Apply search term filter using 'searchName' field (case-insensitive "starts with")
      if (searchTermLower.isNotEmpty) {
        print("Firestore Query: Searching 'searchName' starting with '$searchTermLower'");
        // This creates a range query: finds strings >= searchTermLower and < searchTermLower + high_unicode_char
        // Effectively a "starts with" query that works with Firestore indexes.
        query = query
            .where('searchName', isGreaterThanOrEqualTo: searchTermLower)
            .where('searchName',
                isLessThan: searchTermLower + '\uf8ff'); // \uf8ff is a very high Unicode character
      } else {
        print("Firestore Query: Fetching all products (no search term).");
        // No search term, fetch potentially all (or apply other base filters if needed)
        // Consider adding .limit() here if fetching all is too much
      }
      // --- End Firestore Query Construction ---


      // --- Fetch Data from Firestore ---
      // NOTE: This query is now potentially much more efficient than fetching all docs!
      QuerySnapshot querySnapshot = await query.get();
      print("Fetched ${querySnapshot.docs.length} products matching Firestore query.");
      // --- End Fetch Data ---


      // Map Firestore docs to Product objects
      List<Product> fetchedProducts = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();

      _allMatchingProducts = fetchedProducts; // Store results from Firestore query

      // --- Determine Max Price from Fetched Results ---
      if (_allMatchingProducts.isNotEmpty) {
        final maxPrice = _allMatchingProducts
            .map((p) => p.price)
            .reduce((a, b) => a > b ? a : b);
        _priceRangeMax = (maxPrice / 100).ceil() * 100.0;
        if (_selectedPriceMax > _priceRangeMax || _selectedPriceMax == 1000) { // Reset if default or out of new range
            _selectedPriceMax = _priceRangeMax;
        }
      } else {
        _priceRangeMax = 1000; // Default back if no products found
        _selectedPriceMax = 1000;
      }
      // --- End Max Price Calculation ---


      // --- REMOVED Client-Side Search Filtering ---
      // The primary search filtering is now done by the Firestore query itself.
      // We no longer need the `allFetchedProducts.where(...)` block here.
      // print("Client-side search filtering is no longer performed here.");
      // --- End REMOVED Client-Side Search Filtering ---


      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Now apply the secondary client-side filters (price, category, rating)
        // to the results obtained from the Firestore query.
        _applySecondaryFilters();
      });
    } catch (e, stackTrace) {
      print('Error fetching/filtering products: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        // Check for specific Firestore errors if needed (e.g., permission denied)
        if (e is FirebaseException && e.code == 'permission-denied') {
             _error = 'Error: Permission denied accessing product data.';
        } else if (e is FirebaseException && e.message != null && e.message!.contains('indexes')) {
             _error = 'Error: Missing Firestore index. Please create the required index in your Firebase console.';
             print("Firestore Index Error Hint: The query likely requires a composite index. Check the error message in the console for a link to create it.");
        }
        else {
             _error = 'Failed to load products. Please try again.';
        }
        _isLoading = false;
      });
    }
  }

  // --- Apply secondary filters (Price, Category, Rating) ---
  // This runs AFTER the initial Firestore query results are fetched
  void _applySecondaryFilters() {
    if (!mounted) return;

    List<Product> tempFiltered = List.from(_allMatchingProducts); // Start with Firestore-matched products

    // Apply Price Filter
    tempFiltered =
        tempFiltered.where((p) => p.price <= _selectedPriceMax).toList();

    // Apply Category Filter
    if (_selectedCategories.isNotEmpty && !_selectedCategories.contains('All')) {
      tempFiltered = tempFiltered
          .where((p) => _selectedCategories.contains(p.category))
          .toList();
    }

    // Apply Rating Filter
    if (_selectedRatingMin > 0) {
      tempFiltered =
          tempFiltered.where((p) => p.rating >= _selectedRatingMin).toList();
    }

    // Optional: Apply Keyword Filter (Client-Side - if needed as secondary check)
    // final searchTermLower = widget.searchString.toLowerCase().trim();
    // if (searchTermLower.isNotEmpty) {
    //   tempFiltered = tempFiltered.where((product) {
    //     // Check if any keyword CONTAINS the search term (already lowercase)
    //     return product.keywords.any((keyword) => keyword.contains(searchTermLower));
    //   }).toList();
    // }


    // TODO: Add Sorting Logic if needed
    // tempFiltered.sort((a, b) => a.price.compareTo(b.price));

    setState(() {
      _filteredProducts = tempFiltered; // Update the list displayed in the grid
      print("Applied secondary filters. Displaying ${_filteredProducts.length} products.");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.searchString.isNotEmpty
            ? 'Results for "${widget.searchString}"'
            : 'Browse Products'),
        backgroundColor: Colors.teal,
        elevation: 1,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Filter Panel ---
          Container(
            width: 230,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: FiltersPanel(
              priceRangeMax: _priceRangeMax,
              selectedPriceMax: _selectedPriceMax,
              availableCategories: _availableCategories,
              selectedCategories: _selectedCategories,
              selectedRatingMin: _selectedRatingMin,
              onPriceChanged: (value) {
                if (!mounted) return;
                setState(() => _selectedPriceMax = value);
                _applySecondaryFilters();
              },
              onCategorySelected: (category) {
                if (!mounted) return;
                setState(() {
                  if (category == 'All') {
                    _selectedCategories.clear();
                    _selectedCategories.add('All');
                  } else {
                    _selectedCategories.remove('All');
                    if (_selectedCategories.contains(category)) {
                      _selectedCategories.remove(category);
                    } else {
                      _selectedCategories.add(category);
                    }
                    if (_selectedCategories.isEmpty) {
                      _selectedCategories.add('All'); // Default back to all if empty
                    }
                  }
                });
                _applySecondaryFilters();
              },
              onRatingSelected: (rating) {
                if (!mounted) return;
                setState(() => _selectedRatingMin = rating);
                _applySecondaryFilters();
              },
            ),
          ),

          // --- Product Grid ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to display loading, error, or grid content
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding( // Added padding for better spacing
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _fetchAndFilterProducts,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              )
            ],
          ),
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _allMatchingProducts.isEmpty && widget.searchString.isNotEmpty
                  ? 'No products found starting with "${widget.searchString}".' // Updated message
                  : _allMatchingProducts.isEmpty && widget.searchString.isEmpty
                      ? 'No products found.' // Message when search is empty and db is empty/filtered out
                      : 'No products match the selected filters.', // Message when filters yield no results
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // --- Display the Grid ---
    // Consider using LayoutBuilder for responsive crossAxisCount
    return GridView.builder(
      key: PageStorageKey('searchResultsGrid'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // Adjust crossAxisCount based on screen size for responsiveness
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 :
                         MediaQuery.of(context).size.width > 800 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        // Adjust aspect ratio based on CardDiv's expected content height vs width
        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 0.75 : 0.7,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        // Use the ProductCard wrapper which internally uses CardDiv
        // CRITICAL: Ensure ProductCard passes product.name (NOT product.searchName) to CardDiv's title

    return CardDiv(
      imageUrl: product.imageUrl,
      title: product.name, // CardDiv should display this
      description: product.description, // Pass if CardDiv shows it
      ID: product.id, // Essential for actions
      // Pass rating if CardDiv shows stars
      // rating: product.rating,
      reviews: const [], // Placeholder: Fetch/pass actual reviews if needed
      companyId: product.companyId, // Pass if needed (e.g., for seller link)
      price: product.price, // CardDiv should display this
      isBookmarked: false, // Placeholder: Implement real bookmark logic
      onBookmarkToggle: () {
          // TODO: Implement bookmark toggle logic (e.g., using Provider/Riverpod and Firestore)
          print("Bookmark toggle for ${product.id}");
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bookmark for ${product.name} Toggled (Demo)'), duration: const Duration(seconds: 1))
          );
      },
      onTap: () {
        // TODO: Implement navigation to a Product Detail Page
         print("Navigate to details for ${product.id}");
        // Example Navigation:
        /*
        Navigator.push(
          context,
          MaterialPageRoute(
            // Assuming you have a ProductDetailPage that takes productId
            builder: (context) => ProductDetailPage(productId: product.id),
          ),
        );
        */
      },
    );
      },
    );
  }
}

// --- Filters Panel Widget (StateLESS) ---
// (No changes needed here, it receives state from parent)
class FiltersPanel extends StatelessWidget {
  final double priceRangeMax;
  final double selectedPriceMax;
  final List<String> availableCategories;
  final Set<String> selectedCategories; // This is the correct variable passed in
  final int selectedRatingMin;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<int> onRatingSelected;

  const FiltersPanel({
    super.key,
    required this.priceRangeMax,
    required this.selectedPriceMax,
    required this.availableCategories,
    required this.selectedCategories, // Passed via constructor
    required this.selectedRatingMin,
    required this.onPriceChanged,
    required this.onCategorySelected,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView( // Ensures filters scroll if they exceed height
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Price Range (Max)', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: selectedPriceMax.clamp(0, priceRangeMax),
                  min: 0,
                  max: priceRangeMax,
                   // Make divisions reasonable, avoid too many/few
                  divisions: (priceRangeMax / 25).round().clamp(1, 100),
                  label: '\$${selectedPriceMax.toStringAsFixed(0)}',
                  onChanged: onPriceChanged,
                  activeColor: Colors.teal,
                ),
              ),
              Text('\$${selectedPriceMax.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)), // Made price label slightly bolder
            ],
          ),

          const SizedBox(height: 24),
          const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
          // Using Wrap is good for variable number of categories
          Wrap(
            spacing: 4.0, // Horizontal spacing between chips
            runSpacing: 0.0, // Vertical spacing between lines
            children: availableCategories.map((category) {
              // Use ChoiceChip for single/multi-select appearance
              // ***** FIX HERE *****
              final bool isSelected = (category == 'All' && selectedCategories.contains('All')) || // Use selectedCategories
                                      (category != 'All' && selectedCategories.contains(category) && !selectedCategories.contains('All')); // Use selectedCategories
              // ***** END FIX *****
              return ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                   // The parent's onCategorySelected handles the logic of adding/removing
                   onCategorySelected(category);
                },
                selectedColor: Colors.teal[100],
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.teal[900] : Colors.black87,
                ),
                backgroundColor: Colors.grey[200],
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.teal : Colors.grey.shade400)),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Text('Minimum Rating', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<int>(
            title: const Text("Any Rating"),
            value: 0,
            groupValue: selectedRatingMin,
            onChanged: (value) => onRatingSelected(value ?? 0),
            dense: true,
            activeColor: Colors.teal,
            contentPadding: EdgeInsets.zero,
          ),
          ...List.generate(5, (index) {
            int ratingValue = 5 - index; // Generate 5, 4, 3, 2, 1
            return RadioListTile<int>(
              // Visual representation of stars
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (starIndex) => Icon(
                    starIndex < ratingValue ? Icons.star : Icons.star_border,
                    size: 18,
                    color: Colors.amber,
                  ),
                  // Add "& Up" text only for ratings 1 through 4
                )..addAll(ratingValue < 5 ? [const SizedBox(width: 4), Text('& Up', style: TextStyle(fontSize: 12, color: Colors.grey[600]))] : []),
              ),
              value: ratingValue,
              groupValue: selectedRatingMin,
              onChanged: (value) => onRatingSelected(value ?? 0),
              dense: true,
              activeColor: Colors.teal,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }
}

// --- Dummy CardDiv Widget ---
// Added a placeholder CardDiv so the code is runnable for testing layout/structure.
// Replace this with your actual CardDiv import and implementation.
