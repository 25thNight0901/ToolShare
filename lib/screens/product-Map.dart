import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:toolshare/screens/product-details.dart';

class ProductMap extends StatefulWidget {
  const ProductMap({super.key});

  @override
  State<ProductMap> createState() => _ProductMapState();
}

class _ProductMapState extends State<ProductMap> {
  LatLng _center = LatLng(51.5074, -0.1278);
  final List<double> _radiusOptions = [1000, 5000, 10000, 25000, 50000];
  double _radius = 1000;
  int _radiusIndex = 0;
  List<Marker> _products = [];
  final MapController _mapcontroller = MapController();

  double getZoomlevel(double radius) {
    switch (radius.toInt()) {
      case 1000:
        return 14;
      case 5000:
        return 12;
      case 10000:
        return 11;
      case 25000:
        return 10;
      case 50000:
      default:
        return 9;
    }
  }

  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });
      _mapcontroller.move(_center, getZoomlevel(_radius));
    } catch (e) {
      print("error getting location: $e");
    }
  }

  void _searchProducts() async {
    final distance = Distance();
    final snapshot =
        await FirebaseFirestore.instance.collection('products').get();

    final markers =
        snapshot.docs
            .map((doc) {
              final data = doc.data();
              final lat = data['latitude'];
              final lon = data['longitude'];

              final productLocation = LatLng(lat, lon);
              final isWithinRadius =
                  distance.as(LengthUnit.Meter, _center, productLocation) <=
                  _radius;
              if (isWithinRadius) {
                return Marker(
                  point: productLocation,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProductDetails(product: doc),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                );
              } else {
                return null;
              }
            })
            .whereType<Marker>()
            .toList();

    setState(() {
      _products = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final zoomLevel = getZoomlevel(_radius);
    return Scaffold(
      appBar: AppBar(title: Text('Products Nearby')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Text("Radius: ${(_radius / 1000).toStringAsFixed(0)}km"),
                Slider(
                  value: _radiusIndex.toDouble(),
                  min: 0,
                  max: (_radiusOptions.length - 1).toDouble(),
                  divisions: _radiusOptions.length - 1,
                  label: "${(_radiusOptions[_radiusIndex] / 1000).round()} km",
                  onChanged: (value) {
                    setState(() {
                      _radiusIndex = value.round();
                      _radius = _radiusOptions[_radiusIndex];
                    });

                    final newZoom = getZoomlevel(_radius);
                    _mapcontroller.move(_center, newZoom);
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: FlutterMap(
              mapController: _mapcontroller,
              options: MapOptions(center: _center, zoom: getZoomlevel(_radius)),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'come.example.app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _center,
                      useRadiusInMeter: true,
                      radius: _radius,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(markers: _products),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.search),
              label: Text("Search"),
              onPressed: _searchProducts,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
