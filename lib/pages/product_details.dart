import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

// Import the CartService (adjust the path based on your project structure)
import 'package:rayanpharma/widgets/cart_service.dart'; // <--- ADJUST THIS PATH

class ProductDetailPage extends StatefulWidget {
  // Data passed to this page
  final String productId;
  final String imageUrl;
  final String title;
  final String description;
  final double price;
  final List<Map<String, dynamic>>? reviews; // Existing reviews data
  final double? initialAverageRating; // Pass initial average rating if available

  const ProductDetailPage({
    Key? key,
    required this.productId,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.price,
    this.reviews, // Reviews are optional when creating the page
    this.initialAverageRating, // Optional initial rating
  }) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  // --- State Variables ---

  // Quantity Selector
  int _quantityToAdd = 1;

  // Stock Management
  int? _stockQuantity;
  bool _isLoadingStock = true;

  // Cart Management
  final CartService _cartService = CartService();

  // Checkout Process
  bool _isCheckingOut = false;

  // Review Management
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 0; // 0 means no rating selected
  late List<Map<String, dynamic>> _currentReviews;
  double _currentAverageRating = 0.0; // Store and update average rating locally
  bool _isSubmittingReview = false; // Loading state for review submission
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _productOwnerId;

  // --- Lifecycle Methods ---

  @override
  void initState() {
    super.initState();
    // Initialize reviews list safely
    _currentReviews = List<Map<String, dynamic>>.from(widget.reviews ?? []);
    _currentAverageRating = widget.initialAverageRating ?? _calculateAverageRating(_currentReviews); // Use initial or calculate
    // Fetch the stock quantity when the page loads
    _fetchProductDetails();
  }

  @override
  void dispose() {
    // Clean up controllers
    _commentController.dispose();
    super.dispose();
  }

  // --- Data Fetching ---

  /// Fetches the current stock quantity from Firestore for this product.
// Rename this function
Future<void> _fetchProductDetails() async { // Renamed
  if (!mounted) return;

  setState(() {
    _isLoadingStock = true; // Keep using this flag for loading state
    _productOwnerId = null; // Reset owner ID while loading
  });

  try {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .get();

    int fetchedStock = 0;
    String? fetchedOwnerId; // Variable to hold owner ID

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data()!;
      fetchedStock = (data['quantity'] as num?)?.toInt() ?? 0;
      // --- Fetch Owner ID ---
      fetchedOwnerId = data['owner'] as String?; // Get owner field
      // --- End Fetch Owner ID ---

    } else {
      if (kDebugMode) print("Product document ${widget.productId} not found.");
    }

    if (!mounted) return;

    setState(() {
      _stockQuantity = fetchedStock;
      _productOwnerId = fetchedOwnerId; // Set the owner ID state
      _isLoadingStock = false;

      // Adjust quantity selector based on fetched stock (logic remains the same)
      if (_stockQuantity! <= 0) {
        _quantityToAdd = 0;
      } else if (_quantityToAdd > _stockQuantity!) {
        _quantityToAdd = _stockQuantity!;
      } else if (_quantityToAdd == 0 && _stockQuantity! > 0) {
        _quantityToAdd = 1;
      }
    });

  } catch (e) {
    if (kDebugMode) print("Error fetching product details for ${widget.productId}: $e");
    if (!mounted) return;
    setState(() {
      _stockQuantity = 0;
      _productOwnerId = null; // Reset on error
      _isLoadingStock = false;
      _quantityToAdd = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error loading product information.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // --- Cart Actions ---

  /// Handles adding the selected quantity of the product to the cart.
  void _addToCart() {
      if (_currentUser != null && _currentUser!.uid == _productOwnerId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You cannot add your own product to the cart."),
        backgroundColor: Colors.orangeAccent,
      ),
    );
    return; // Prevent adding to cart
  }
     // ... (Keep existing _addToCart logic - no changes needed here) ...
    if (_isLoadingStock || _stockQuantity == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Stock information still loading...')),
       );
      return;
    }

    if (_stockQuantity! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is currently out of stock.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_quantityToAdd <= 0) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a quantity greater than zero.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int currentInCart = _cartService.getQuantityInCart(widget.productId);
    int potentialTotalQuantity = currentInCart + _quantityToAdd;

    if (potentialTotalQuantity > _stockQuantity!) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Cannot add $_quantityToAdd. Only $_stockQuantity total available (you have $currentInCart in cart).'),
             duration: const Duration(seconds: 4),
             backgroundColor: Colors.orange,
           ),
         );
         return;
    }

    _cartService.addItem(
      productId: widget.productId,
      title: widget.title,
      price: widget.price,
      imageUrl: widget.imageUrl,
      quantity: _quantityToAdd,
      availableStock: _stockQuantity!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} x$_quantityToAdd added to cart.'),
        backgroundColor: Colors.teal,
      ),
    );

     setState(() {}); // Update AppBar badge
  }


  // --- Checkout Action ---

  /// Handles the checkout process: updates Firestore and prints a bill.
   // --- Checkout Action ---

  /// Handles the checkout process: updates product stock, creates/updates sales records, and prints a bill.
  Future<void> _checkout() async {
    // ... (Keep existing _checkout logic - no changes needed here) ...
    if (_cartService.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_isCheckingOut) return;
    if (!mounted) return;

    final buyer = FirebaseAuth.instance.currentUser;

    setState(() { _isCheckingOut = true; });

    FirebaseFirestore firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();
    List<Map<String, dynamic>> billItemsDetails = [];
    double calculatedGrandTotal = 0;
    List<String> failedSaleRecordProductIds = [];

    for (var cartItem in _cartService.items.values) {
      final productRef = firestore.collection('products').doc(cartItem.productId);
      final saleDocRef = firestore.collection('sales').doc(cartItem.productId);

      String? ownerId;
      GeoPoint? ownerLocation;

      try {
        final productSnapshot = await productRef.get();
        if (!productSnapshot.exists || productSnapshot.data() == null) {
          if (kDebugMode) print("Checkout Error: Product ${cartItem.productId} not found. Skipping.");
          failedSaleRecordProductIds.add(cartItem.productId);
          continue;
        }
        final productData = productSnapshot.data()!;
        ownerId = productData['owner'] as String?;

        if (ownerId != null) {
          final userRef = firestore.collection('users').doc(ownerId);
          final userSnapshot = await userRef.get();
          if (userSnapshot.exists && userSnapshot.data() != null) {
             ownerLocation = userSnapshot.data()!['location'] as GeoPoint?;
          } else if (kDebugMode) {
             print("Checkout Warning: Owner document ${ownerId} not found.");
          }
        } else {
           if (kDebugMode) print("Checkout Warning: Product ${cartItem.productId} missing owner ID.");
           failedSaleRecordProductIds.add(cartItem.productId); // Mark sale record as potentially incomplete
        }

        batch.update(productRef, {'quantity': FieldValue.increment(-cartItem.quantity)});

        final saleData = {
          'productId': cartItem.productId,
          'title': cartItem.title,
          'priceAtSale': cartItem.price,
          'imageUrl': cartItem.imageUrl,
          'ownerId': ownerId,
          'ownerLocation': ownerLocation,
          'quantitySold': FieldValue.increment(cartItem.quantity),
          'lastSaleTimestamp': FieldValue.serverTimestamp(),
          'lastBuyerId': buyer?.uid,
        };

        batch.set(saleDocRef, saleData, SetOptions(merge: true));

        billItemsDetails.add({
         'id': cartItem.productId,
         'name': cartItem.title,
         'qty': cartItem.quantity,
         'price_per_item': cartItem.price,
         'item_total': cartItem.lineTotal,
        });
        calculatedGrandTotal += cartItem.lineTotal;

      } catch (e) {
         if (kDebugMode) print("Error processing item ${cartItem.productId} during checkout prep: $e");
         failedSaleRecordProductIds.add(cartItem.productId);
         continue;
      }
    }

    try {
      if (billItemsDetails.isNotEmpty) {
          await batch.commit();

          print("\n==================================");
          print("         R E C E I P T          ");
          print("==================================");
          print("Date: ${DateTime.now().toLocal()}");
          print("----------------------------------");
          print("Items Purchased:");
          for (var billItem in billItemsDetails) {
             print(
                 "- ${billItem['name']} (ID: ${billItem['id']})\n"
                 "    Qty: ${billItem['qty']} @ \$${billItem['price_per_item'].toStringAsFixed(2)} ea. = \$${billItem['item_total'].toStringAsFixed(2)}"
             );
          }
          print("----------------------------------");
          print("GRAND TOTAL: \$${calculatedGrandTotal.toStringAsFixed(2)}");
            if (failedSaleRecordProductIds.isNotEmpty) {
              print("----------------------------------");
              print("Note: Sale record update may be incomplete for product ID(s): ${failedSaleRecordProductIds.join(', ')}");
            }
          print("==================================");
          print("Thank you for your purchase!");
          print("==================================\n");

           if (mounted) {
              _cartService.clearCart();
              String successMessage = 'Checkout successful! Stock updated.';
              if(failedSaleRecordProductIds.isNotEmpty){
                 successMessage += ' Some sale records potentially incomplete.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMessage),
                  backgroundColor: failedSaleRecordProductIds.isEmpty ? Colors.green : Colors.orangeAccent,
                ),
              );
               await _fetchProductDetails(); // Refresh stock display
                if(mounted && _stockQuantity != null && _stockQuantity! > 0) {
                    setState(() { _quantityToAdd = 1; });
                } else if (mounted) {
                     setState(() { _quantityToAdd = 0; });
                }
           }
      } else {
          if (kDebugMode) print("Checkout failed: No items could be processed.");
           if(mounted){
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Checkout failed: Could not process any cart items.'),
                  backgroundColor: Colors.red,
                ),
             );
           }
      }

    } catch (e) {
      if (kDebugMode) print("Error during checkout batch commit: $e");
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Checkout failed during final update: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
      }
    } finally {
       if (mounted) {
           setState(() { _isCheckingOut = false; });
       }
    }
  }


  // --- Review Actions ---

  /// Calculates the average rating based on a list of reviews.
  double _calculateAverageRating(List<Map<String, dynamic>> reviews) {
    if (reviews.isEmpty) return 0.0;
    // Sum ratings safely, treating null or non-numeric ratings as 0
    final totalRating = reviews
        .map((review) => (review['rating'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a + b);
    return totalRating / reviews.length;
  }


  /// Submits a new review and updates the average rating using a Firestore Transaction.
  Future<void> _submitReview() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a review'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_isSubmittingReview) return; // Prevent double submission

    final comment = _commentController.text.trim();
    if (comment.isEmpty || _selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment and select a rating (1-5 stars).'), backgroundColor: Colors.redAccent),
      );
      return;
    }

     if (mounted) FocusScope.of(context).unfocus(); // Hide keyboard

     setState(() { _isSubmittingReview = true; });

    // Prepare the new review data (without timestamp - Firestore adds it via FieldValue)
    final newReviewData = {
      'userId': _currentUser!.uid,
      'userName': _currentUser!.displayName ?? 'Anonymous User', // Use display name or fallback
      'rating': _selectedRating,
      'comment': comment,
      'userAvatar': _currentUser!.photoURL, // Include user avatar URL if available
    };

    final productDocRef = FirebaseFirestore.instance.collection('products').doc(widget.productId);

    try {
      // Use a Firestore transaction for atomic update
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Get the current product document within the transaction
        final productSnapshot = await transaction.get(productDocRef);

        if (!productSnapshot.exists) {
          throw Exception("Product not found!"); // Or handle appropriately
        }

        // 2. Get current reviews (or empty list) from the snapshot data
        final Map<String, dynamic> data = productSnapshot.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> existingReviewsRaw = data['reviews'] as List<dynamic>? ?? [];
        // Convert to the expected type for calculation
        final List<Map<String, dynamic>> existingReviews = existingReviewsRaw
            .whereType<Map<String, dynamic>>() // Ensure correct type
            .toList();


        // 3. Prepare the list of reviews *including the new one* for calculation
        // Important: Create a temporary map for the new review *without* the server timestamp
        // because we can't easily use FieldValue inside the local calculation.
        final localNewReviewForCalc = Map<String, dynamic>.from(newReviewData);
        localNewReviewForCalc.remove('timestamp'); // Remove server timestamp for local calc
        // Add other fields that might be needed if not already present (like rating which is present)

        final allReviewsForCalc = [...existingReviews, localNewReviewForCalc];

        // 4. Calculate the new average rating based on the combined list
        final double newAverageRating = _calculateAverageRating(allReviewsForCalc);
        final int newReviewCount = allReviewsForCalc.length;


        // 5. Update the product document within the transaction
        transaction.update(productDocRef, {
          // Add the new review data (including the server timestamp FieldValue) to the array
          'reviews': FieldValue.arrayUnion([newReviewData]),
          // Update the averageRating field
          'averageRating': newAverageRating,
           // Optionally, update a review count field for efficiency if you have one
           'reviewCount': newReviewCount,
        });
      });

      // --- Transaction Successful ---

      // For immediate UI update, create a display version of the review
      // We use the local data and *approximate* the timestamp with client time
      // (The actual server timestamp will be in Firestore)
      final displayReview = Map<String, dynamic>.from(newReviewData);
      displayReview['timestamp'] = Timestamp.now(); // Use client time for immediate display

      if(mounted){
          setState(() {
            _currentReviews.insert(0, displayReview); // Add to beginning for UI
            _currentAverageRating = _calculateAverageRating(_currentReviews); // Recalculate local average for UI
            _commentController.clear();
            _selectedRating = 0;
            _isSubmittingReview = false; // Turn off loading indicator
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      if (kDebugMode) print("Error submitting review transaction: $e");
      if(mounted){
          setState(() { _isSubmittingReview = false; }); // Turn off loading on error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting review: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  // --- Build Method (UI Definition) ---

  @override
  Widget build(BuildContext context) {
    // Use the locally managed _currentAverageRating for display
    final averageRating = _currentAverageRating;
    final bool stockAvailable = !_isLoadingStock && _stockQuantity != null && _stockQuantity! > 0;
    final bool canSelectMore = stockAvailable && _quantityToAdd < _stockQuantity!;
    final bool canSelectLess = stockAvailable && _quantityToAdd > 1;
    final bool canAddToCart = stockAvailable && _quantityToAdd > 0 && !_isCheckingOut; // Disable during checkout
    final bool canCheckout = _cartService.itemCount > 0 && !_isCheckingOut;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.teal,
        centerTitle: true,
         actions: [
           // ... (Keep existing AppBar actions - Cart Icon/Badge) ...
           Padding(
             padding: const EdgeInsets.only(right: 8.0),
             child: Center(
               child: Stack(
                 alignment: Alignment.topRight,
                 children: [
                   IconButton(
                     icon: const Icon(Icons.shopping_cart_outlined),
                     tooltip: 'View Cart',
                     onPressed: () {
                       // TODO: Navigate to Cart Page here
                       if (kDebugMode) print("Cart items: ${_cartService.totalQuantity}");
                       ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Cart has ${_cartService.totalQuantity} total items.'))
                       );
                     },
                   ),
                   if (_cartService.totalQuantity > 0)
                     Positioned(
                       right: 4,
                       top: 4,
                       child: Container(
                         padding: const EdgeInsets.all(2),
                         decoration: const BoxDecoration(
                           color: Colors.redAccent,
                           shape: BoxShape.circle,
                         ),
                         constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                         child: Text(
                           _cartService.totalQuantity.toString(),
                           style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                           textAlign: TextAlign.center,
                         ),
                       ),
                     ),
                 ],
               ),
             ),
           ),
         ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Product Image and Core Details ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Container
                  Container(
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: MediaQuery.of(context).size.width * 0.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade200,
                    ),
                     child: ClipRRect( // Apply clipping to the image itself
                       borderRadius: BorderRadius.circular(12),
                       child: Image.network(
                         widget.imageUrl,
                         fit: BoxFit.cover,
                         errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                          loadingBuilder: (context, child, loadingProgress) {
                             if (loadingProgress == null) return child;
                             return Center(child: CircularProgressIndicator(
                               value: loadingProgress.expectedTotalBytes != null
                                   ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                   : null,
                                strokeWidth: 2,
                             ));
                          },
                       ),
                     ),
                  ),
                  const SizedBox(width: 16),
                  // Text Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "\$${widget.price.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // --- Stock Display ---
                        _isLoadingStock
                            ? const SizedBox(height: 20, child: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text("Loading stock...")]))
                            : Text(
                                _stockQuantity! > 0 ? 'In Stock ($_stockQuantity)' : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _stockQuantity! > 0 ? Colors.blue.shade800 : Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                         const SizedBox(height: 12),
                         // Average Rating Display (using _currentAverageRating)
                          if (!_isLoadingStock && averageRating > 0) // Show only if rating exists
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber.shade700, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                    // Display the locally tracked average rating
                                    '${averageRating.toStringAsFixed(1)} (${_currentReviews.length})',
                                     style: const TextStyle(fontSize: 14)
                                 ),
                              ],
                            )
                          else if (!_isLoadingStock && _currentReviews.isEmpty)
                            const Text('No reviews yet', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Product Description ---
               Text(
                 'Description',
                 style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
               ),
              const SizedBox(height: 8),
               Text(
                 widget.description,
                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
               ),
              const SizedBox(height: 24),

              // --- Quantity Selector Row ---
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                   Text("Quantity:", style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Decrease quantity',
                    onPressed: canSelectLess ? () => setState(() => _quantityToAdd--) : null,
                    color: canSelectLess ? Colors.black : Colors.grey,
                  ),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(_quantityToAdd.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Increase quantity',
                    onPressed: canSelectMore ? () => setState(() => _quantityToAdd++) : null,
                    color: canSelectMore ? Colors.black : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Action Buttons (Add to Cart & Checkout) ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Add to Cart', style: TextStyle(fontSize: 16)),
                    onPressed: canAddToCart ? _addToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                       shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8.0) ),
                       disabledBackgroundColor: Colors.teal.withOpacity(0.5),
                       disabledForegroundColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: _isCheckingOut
                       ? Container(width: 20, height: 20, margin: const EdgeInsets.only(right: 8), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                       : const Icon(Icons.payment_outlined),
                    label: Text(_isCheckingOut ? 'Processing...' : 'Proceed to Checkout', style: const TextStyle(fontSize: 16)),
                    onPressed: canCheckout ? _checkout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                       shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8.0) ),
                      disabledBackgroundColor: Colors.orange.withOpacity(0.5),
                      disabledForegroundColor: Colors.white70,
                    ),
                  ),
                  // Removed separate loading indicator, integrated into button
                ],
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 1),
              const SizedBox(height: 16),

              // --- Ratings & Reviews Section ---
              Text(
                'Ratings & Reviews (${_currentReviews.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_currentReviews.isNotEmpty)
                 Row(
                  children: [
                    // Display the locally tracked average rating
                    Text(averageRating.toStringAsFixed(1), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.black87)),
                    const SizedBox(width: 8),
                    ...List.generate(5, (index) {
                      double ratingValue = index + 1.0;
                      IconData starIcon;
                      if (averageRating >= ratingValue) starIcon = Icons.star_rounded;
                      else if (averageRating > index && averageRating < ratingValue) starIcon = Icons.star_half_rounded;
                      else starIcon = Icons.star_border_rounded;
                      return Icon(starIcon, color: Colors.amber.shade700, size: 24);
                    }),
                  ],
                )
              else
                 const Text('No reviews yet. Be the first!'),

              const SizedBox(height: 20),

              // --- Add Review Section ---
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Write a Review',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.amber.shade700,
                                size: 32,
                              ),
                              tooltip: '${index+1} Star${index == 0 ? '' : 's'}',
                              onPressed: _isSubmittingReview ? null : () => setState(() => _selectedRating = index + 1),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        enabled: !_isSubmittingReview, // Disable when submitting
                        decoration: InputDecoration(
                          hintText: 'Share your experience...',
                          labelText: 'Your Comment',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _isSubmittingReview ? Colors.grey : Colors.teal, width: 1.5),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                           enabledBorder: OutlineInputBorder(
                             borderSide: BorderSide(color: Colors.grey.shade400),
                             borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmittingReview ? null : _submitReview, // Disable button when submitting
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            disabledBackgroundColor: Colors.teal.withOpacity(0.5),
                            disabledForegroundColor: Colors.white70,
                          ),
                          child: _isSubmittingReview
                             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                             : const Text('Submit Review', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Existing Reviews List ---
               if (_currentReviews.isNotEmpty) ...[
                 Text('Recent Reviews', style: Theme.of(context).textTheme.titleMedium),
                 const SizedBox(height: 8),
                 ListView.separated(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: _currentReviews.length,
                   separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
                   itemBuilder: (context, index) {
                     final review = _currentReviews[index];
                     final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
                     final comment = review['comment'] as String? ?? '';
                     final userName = review['userName'] as String? ?? 'Anonymous';
                     final userAvatarUrl = review['userAvatar'] as String?;
                     final timestamp = review['timestamp'] as Timestamp?; // Read timestamp
                     String timeAgo = ''; // Placeholder for formatted time
                      if (timestamp != null) {
                         // Simple time ago logic (replace with timeago package for better formatting)
                         final difference = DateTime.now().difference(timestamp.toDate());
                         if (difference.inDays > 1) timeAgo = '${difference.inDays}d ago';
                         else if (difference.inHours > 1) timeAgo = '${difference.inHours}h ago';
                         else if (difference.inMinutes > 1) timeAgo = '${difference.inMinutes}m ago';
                         else timeAgo = 'Just now';
                      }


                     return ListTile(
                       leading: CircleAvatar(
                         radius: 20,
                         backgroundColor: Colors.grey.shade300,
                         backgroundImage: (userAvatarUrl != null && userAvatarUrl.isNotEmpty)
                             ? NetworkImage(userAvatarUrl) : null,
                         child: (userAvatarUrl == null || userAvatarUrl.isEmpty)
                             ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?') : null,
                       ),
                       title: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                           if (timeAgo.isNotEmpty) Text(timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                         ],
                       ),
                       subtitle: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Row(
                               mainAxisSize: MainAxisSize.min,
                               children: List.generate(5, (starIndex) {
                                 return Icon(
                                   starIndex < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                   color: Colors.amber.shade700,
                                   size: 16,
                                 );
                               }),
                             ),
                             if (comment.isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.only(top: 4.0),
                                 child: Text(comment, style: const TextStyle(fontSize: 14)),
                               ),
                           ],
                         ),
                       contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                       dense: true,
                     );
                   },
                 ),
               ],
              const SizedBox(height: 30), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}