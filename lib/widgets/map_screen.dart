import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const MapScreen({super.key, this.initialData});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  LatLng _center = const LatLng(33.8938, 35.5018); // Coordinates for Delhi
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Initialize the location if provided
    if (widget.initialData != null && widget.initialData!['location'] != null) {
      String locationString = widget.initialData!['location'];
      List<String> coordinates = locationString.split(', ');
      if (coordinates.length == 2) {
        double latitude = double.parse(coordinates[0].split(': ')[1]);
        double longitude = double.parse(coordinates[1].split(': ')[1]);
        _selectedLocation = LatLng(latitude, longitude);
        _center = _selectedLocation!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: const Color(0xFF2F8D46),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 13.0,
          onTap: (tapPosition, point) {
            setState(() {
              _selectedLocation = point;
            });
            _showConfirmDialog(point); // Show confirmation dialog instead of saving immediately
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          if (_selectedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        tooltip: 'Get Location',
        backgroundColor: const Color(0xFF2F8D46),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.'),
        ),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _center = LatLng(position.latitude, position.longitude);
      _mapController.move(_center, 13.0);
    });
  }

  // Show a dialog with Cancel and OK buttons.
  void _showConfirmDialog(LatLng point) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Location'),
          content: Text(
              'Selected coordinates: (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})'),
          actions: [
            TextButton(
              onPressed: () {
                // Cancel: Clear the selected location and dismiss the dialog.
                setState(() {
                  _selectedLocation = null;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _returnToCreateVacancies(point);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Return to CreateVacancies screen passing the coordinates and initial data.
  void _returnToCreateVacancies(LatLng point) {
    final result = {
      ...?widget.initialData,
      'location': point, // Pass the LatLng object directly
    };
    Navigator.pop(context, result);
  }
}
