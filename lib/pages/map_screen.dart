import 'dart:async';
import 'dart:math'; // For Point calculation in convex hull
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- State Variables ---
  final TextEditingController _searchController = TextEditingController();
  List<LatLng> _productLocations = []; // Locations for the searched product
  List<LatLng> _polygonPoints = []; // Hull points for the searched locations
  bool _isLoadingLocations = false; // Indicates loading search results
  LatLng _center = const LatLng(30, 0); // Default map center
  double _zoom = 2.0; // Default map zoom
  Map<LatLng, String> _locationToProductName = {}; // To store names for tooltips
  String? _searchFeedbackMessage; // To show messages like "No results found"

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Don't fetch all locations initially anymore
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the controller
    super.dispose();
  }

  // --- Data Fetching ---

  /// Fetches locations for a specific product name from the 'products' collection.
  Future<void> _searchProductLocations(String productName) async {
    if (productName.isEmpty) {
       if (mounted) {
          setState(() {
            _searchFeedbackMessage = "Please enter a product name.";
            _productLocations = []; // Clear previous results
            _polygonPoints = [];
          });
       }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingLocations = true;
      _productLocations = [];
      _polygonPoints = [];
      _locationToProductName = {};
      _searchFeedbackMessage = null; // Clear previous feedback
    });

    print("Searching locations for product name: '$productName'");

    try {
      // Query the 'products' collection for the specific name
      // NOTE: Firestore 'isEqualTo' is case-sensitive.
      // For case-insensitive, you'd need to store a lowercase version
      // of the name and query that field.
      final snapshot = await _firestore
          .collection('products')
          .where('name', isEqualTo: productName) // Exact match search
          .get();

      print("Firestore query returned ${snapshot.docs.length} documents for '$productName'.");

      if (snapshot.docs.isEmpty) {
        print("No products found with name: '$productName'");
        if (mounted) {
          setState(() {
             _isLoadingLocations = false;
             _searchFeedbackMessage = "No products found named '$productName'.";
          });
        }
        return;
      }

      final List<LatLng> rawLocations = [];
      final Map<LatLng, String> tempLocationNames = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id;
        final geoPoint = data['location'] as GeoPoint?;
        final fetchedProductName = data['name'] as String? ?? 'Unknown Product'; // Should match search term

        if (geoPoint != null) {
          print("Product ID: $docId - Found GeoPoint: Lat ${geoPoint.latitude}, Lng ${geoPoint.longitude}");
          final latLng = LatLng(geoPoint.latitude, geoPoint.longitude);
          rawLocations.add(latLng);
          tempLocationNames[latLng] = fetchedProductName;
        } else {
          print("Product ID: $docId - Warning: Product found but missing 'location'.");
        }
      }

      print("Raw locations collected for '$productName': ${rawLocations.length}");

      final uniqueLocations = rawLocations.toSet().toList();
      print("Unique locations for '$productName': ${uniqueLocations.length}");

      if (!mounted) return;

      _locationToProductName = {
         for (var loc in uniqueLocations) loc: tempLocationNames[loc] ?? 'Unknown Product'
      };

      setState(() {
        _productLocations = uniqueLocations;
        _isLoadingLocations = false; // Done loading

        if (_productLocations.isEmpty) {
           // This case handles if products were found but none had a location
           _searchFeedbackMessage = "Products found, but none have location data.";
        } else if (_productLocations.length >= 3) {
          _polygonPoints = _calculateConvexHull(_productLocations);
          print("Calculated polygon points: ${_polygonPoints.length}");
        } else {
          _polygonPoints = [];
          print("Not enough unique points (${_productLocations.length}) for polygon.");
          if (_productLocations.isNotEmpty) {
             // Optional feedback if polygon isn't drawn
             // _searchFeedbackMessage = "Showing ${_productLocations.length} location(s). Not enough to draw area.";
          }
        }
      });

      // Adjust map view AFTER setting state
      if (_productLocations.isNotEmpty) {
         _fitMapToPoints();
      }

    } catch (e) {
      print("Error searching product locations for '$productName': $e");
      if (!mounted) return;
      setState(() {
         _isLoadingLocations = false;
         _searchFeedbackMessage = "An error occurred during search.";
      });
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching locations: ${e.toString()}')),
        );
      }
    }
  }

  // --- Map Adjustments ---

  /// Adjusts the map camera to fit the currently loaded location points.
  void _fitMapToPoints() {
    if (_productLocations.isEmpty || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
             print("Widget disposed, skipping fitBounds.");
             return;
        }
        // Add delay for map initialization
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          try {
            if (_productLocations.length == 1) {
                print("Fitting map to single point: ${_productLocations.first}");
                _mapController.move(_productLocations.first, 13.0);
            } else {
                var bounds = LatLngBounds.fromPoints(_productLocations);
                print("Fitting map to bounds: $bounds");
                _mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(50.0),
                    )
                );
            }
          } catch (e) {
             print("Error during map move/fitCamera: $e.");
          }
       });
     });
  }

  // --- Convex Hull Calculation ---
  // (Keep _calculateConvexHull and _orientation functions as they are)
  List<LatLng> _calculateConvexHull(List<LatLng> points) {
    if (points.length < 3) return [];

    List<Point<double>> pts = points.map((p) => Point(p.longitude, p.latitude)).toList();
    pts.sort((a, b) {
      int cmp = a.y.compareTo(b.y);
      return cmp == 0 ? a.x.compareTo(b.x) : cmp;
    });
    Point<double> p0 = pts[0];
    pts.sublist(1).sort((a, b) {
      double angleA = atan2(a.y - p0.y, a.x - p0.x);
      double angleB = atan2(b.y - p0.y, b.x - p0.x);
      int cmp = angleA.compareTo(angleB);
      if (cmp == 0) {
        double distA = (a.x - p0.x) * (a.x - p0.x) + (a.y - p0.y) * (a.y - p0.y);
        double distB = (b.x - p0.x) * (b.x - p0.x) + (b.y - p0.y) * (b.y - p0.y);
        return distA.compareTo(distB);
      }
      return cmp;
    });
    List<Point<double>> hull = [pts[0], pts[1]];
    for (int i = 2; i < pts.length; i++) {
      Point<double> top = hull.removeLast();
      while (hull.isNotEmpty && _orientation(hull.last, top, pts[i]) <= 0) {
        top = hull.removeLast();
      }
      hull.add(top);
      hull.add(pts[i]);
    }
    return hull.map((p) => LatLng(p.y, p.x)).toList();
  }

  double _orientation(Point<double> p, Point<double> q, Point<double> r) {
    return (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
  }


  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Location Search'), // Updated title
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Enter Product Name",
                hintText: "Search for product locations...",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: "Search Locations",
                  onPressed: () {
                    // Trigger search when icon button is pressed
                    final searchTerm = _searchController.text.trim();
                    _searchProductLocations(searchTerm);
                     // Hide keyboard
                     FocusScope.of(context).unfocus();
                  },
                ),
              ),
              // Trigger search on keyboard submit action
              onSubmitted: (value) {
                 _searchProductLocations(value.trim());
                  FocusScope.of(context).unfocus();
              },
            ),
          ),

          // --- Loading Indicator or Feedback Message ---
          if (_isLoadingLocations)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchFeedbackMessage != null && _productLocations.isEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
               child: Center(
                   child: Text(
                      _searchFeedbackMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                   )
                ),
             ),

          // --- Map Area ---
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
                 // No onMapReady needed here as fitting happens after search
              ),
              children: [
                // Base Tile Layer
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.rayanpharma.app', // Replace with your actual package name
                ),

                // Show map layers only if NOT loading AND locations were found
                 if (!_isLoadingLocations && _productLocations.isNotEmpty)...[
                    // --- Polygon Layer ---
                    if (_polygonPoints.isNotEmpty)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _polygonPoints,
                            isFilled: true,
                            color: Colors.blue.withOpacity(0.3),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),

                    // --- Marker Cluster Layer ---
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 80,
                        size: const Size(40, 40),

                        markers: _productLocations.map((latLng) {
                          return Marker(
                            point: latLng,
                            width: 35,
                            height: 35,
                            child: Tooltip(
                              message: _locationToProductName[latLng] ?? 'Product Location',
                              child: Icon(
                                Icons.storefront,
                                color: Colors.orange.shade800,
                                size: 35,
                              ),
                            ),
                          );
                        }).toList(),
                        builder: (context, markers) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                 ]
                 // If not loading and no locations, the feedback message above handles it,
                 // so the map will just show the base layer.
              ],
            ),
          ),
        ],
      ),
    );
  }
}