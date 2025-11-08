import 'package:flutter/foundation.dart'; // For kDebugMode

//----------------------------------------------------
// 1. Define the structure for an item in the cart
//----------------------------------------------------
class CartItem {
  final String productId;
  final String title;
  final double price;
  final String imageUrl;
  int quantity; // Quantity of this specific item IN THE CART

  CartItem({
    required this.productId,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.quantity,
  });

  // Helper method to calculate the total price for this cart item line
  double get lineTotal => price * quantity;
}

//----------------------------------------------------
// 2. Define the Cart Service (Singleton)
//    Manages the cart state in memory.
//----------------------------------------------------
class CartService {
  // Private constructor for singleton pattern
  CartService._internal();

  // The single instance of CartService
  static final CartService _instance = CartService._internal();

  // Factory constructor to provide access to the single instance
  factory CartService() {
    return _instance;
  }

  // The core data structure: A map where the key is the productId
  // and the value is the CartItem object.
  final Map<String, CartItem> _items = {};

  // --- Public Getters ---

  /// Returns an unmodifiable view of the cart items.
  /// Use this to iterate over items for display or checkout.
  Map<String, CartItem> get items => Map.unmodifiable(_items);

  /// Returns the number of unique product types in the cart.
  int get itemCount => _items.length;

  /// Calculates the total number of individual items across all products in the cart.
  int get totalQuantity {
    // Use fold to sum up quantities of all items in the map's values
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Calculates the total price of all items in the cart.
  double get totalPrice {
    // Use fold to sum up the lineTotal for each item
    return _items.values.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  // --- Public Methods ---

  /// Adds a specified quantity of a product to the cart.
  /// If the item already exists, it increases the quantity.
  /// Respects the available stock limit.
  void addItem({
    required String productId,
    required String title,
    required double price,
    required String imageUrl,
    required int quantity,
    required int availableStock, // Crucial for checking limits
  }) {
    if (quantity <= 0) {
       if (kDebugMode) print("CartService: Attempted to add non-positive quantity for $productId.");
       return; // Don't add if quantity is zero or less
    }
    if (availableStock <= 0) {
        if (kDebugMode) print("CartService: Attempted to add $productId but it's out of stock.");
        // Optionally: throw an exception or return a status code/message
        return; // Cannot add if stock is zero
    }


    if (_items.containsKey(productId)) {
      // Item already exists, update quantity
      final existingItem = _items[productId]!;
      final newTotalQuantity = existingItem.quantity + quantity;

      // Check against available stock
      if (newTotalQuantity > availableStock) {
         if (kDebugMode) print("CartService Warning: Cart quantity for $productId capped at available stock ($availableStock). Requested total: $newTotalQuantity");
         existingItem.quantity = availableStock; // Cap at available stock
         // Optionally: return a status indicating quantity was adjusted
      } else {
          existingItem.quantity = newTotalQuantity;
          if (kDebugMode) print("CartService: Updated quantity for $productId to ${existingItem.quantity}.");
      }
    } else {
      // New item, add it to the cart
      // Check quantity against available stock before adding
      int quantityToAdd = quantity;
      if (quantity > availableStock) {
          if (kDebugMode) print("CartService Warning: Initial add for $productId capped at available stock ($availableStock). Requested: $quantity");
          quantityToAdd = availableStock; // Cap at available stock
          // Optionally: return a status indicating quantity was adjusted
      }

       _items[productId] = CartItem(
         productId: productId,
         title: title,
         price: price,
         imageUrl: imageUrl,
         quantity: quantityToAdd,
       );
        if (kDebugMode) print("CartService: Added new item $productId with quantity $quantityToAdd.");
    }

    // Optional: Notify listeners if using a state management solution like Provider/Riverpod
  }

  /// Removes a product entirely from the cart, regardless of its quantity.
  void removeItem(String productId) {
    if (_items.containsKey(productId)) {
      _items.remove(productId);
       if (kDebugMode) print("CartService: Removed item $productId from cart.");
       // Optional: Notify listeners
    } else {
        if (kDebugMode) print("CartService: Attempted to remove non-existent item $productId.");
    }
  }

  /// Updates the quantity of an item already in the cart.
  /// If the new quantity is <= 0, the item is removed.
  /// Checks against available stock.
  void updateItemQuantity({
    required String productId,
    required int newQuantity,
    required int availableStock // Needed to check limits
  }) {
    if (_items.containsKey(productId)) {
      if (newQuantity <= 0) {
        removeItem(productId); // Remove if quantity drops to 0 or less
      } else {
          int finalQuantity = newQuantity;
          // Check stock limit before updating
          if (newQuantity > availableStock) {
              if (kDebugMode) print("CartService Warning: Quantity update for $productId capped at available stock ($availableStock). Requested: $newQuantity");
              finalQuantity = availableStock; // Cap at available stock
          }
          _items[productId]!.quantity = finalQuantity;
          if (kDebugMode) print("CartService: Manually updated quantity for $productId to $finalQuantity.");
          // Optional: Notify listeners
      }
    } else {
        if (kDebugMode) print("CartService: Attempted to update quantity for non-existent item $productId.");
    }
  }

  /// Removes all items from the cart.
  void clearCart() {
    _items.clear();
    if (kDebugMode) print("CartService: Cart cleared.");
    // Optional: Notify listeners
  }

  /// Returns the quantity of a specific product currently in the cart.
  /// Returns 0 if the item is not in the cart.
  int getQuantityInCart(String productId) {
    return _items[productId]?.quantity ?? 0;
  }
}