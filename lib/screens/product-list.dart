import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:toolshare/screens/product-details.dart';
import 'dart:math';

class ProductList extends StatefulWidget {
  const ProductList({super.key});

  @override
  State<ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  String? _selectedCategory;
  double _selectedRadius = 50;
  bool _limitByDistance = true;
  Position? _currentPosition;

  final List<String> _categories = [
    'All',
    'Kitchen Appliances',
    'Cleaning Appliances',
    'Tools & DIY',
    'Laundry & Ironing',
    'Garden Equipment',
    'Heating & Cooling',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() {});
    }
  }

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371;
    final dLat = _deg2rad(lat2 - lat1), dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  bool _isWithinRadius(Map<String, dynamic> d) {
    if (_currentPosition == null) return false;
    final lat = d['latitude'], lon = d['longitude'];
    if (lat == null || lon == null) return false;
    return _calculateDistanceKm(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lon,
        ) <=
        _selectedRadius;
  }

  bool _isVisible(Map<String, dynamic> d) {
    final now = DateTime.now();
    // 1) availability window
    final fromTs = d['availableFrom'] as Timestamp?;
    final toTs = d['availableTo'] as Timestamp?;
    if (fromTs != null && toTs != null) {
      final from = fromTs.toDate(), to = toTs.toDate();
      if (now.isBefore(from) || now.isAfter(to)) return false;
    }
    // 2) reservation window
    final rFromTs = d['reservedFrom'] as Timestamp?;
    final rToTs = d['reservedTo'] as Timestamp?;
    if (rFromTs != null && rToTs != null) {
      final rFrom = rFromTs.toDate(), rTo = rToTs.toDate();
      if (!now.isBefore(rFrom) && !now.isAfter(rTo)) return false;
    }

    if (d['neverAvailable'] == true) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Products')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              runSpacing: 10,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _selectedCategory ?? 'All',
                  items:
                      _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value == 'All' ? null : value;
                    });
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Max Distance:'),
                    Slider(
                      value: _selectedRadius,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: '${_selectedRadius.toStringAsFixed(0)} km',
                      onChanged:
                          _limitByDistance
                              ? (v) => setState(() => _selectedRadius = v)
                              : null,
                    ),
                    Checkbox(
                      value: !_limitByDistance,
                      onChanged: (v) {
                        setState(() {
                          _limitByDistance = !(v ?? false);
                        });
                      },
                    ),
                    const Text('No limit'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('products')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) return const Center(child: Text('Error'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

                var docs =
                    snap.data!.docs.where((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      if (!_isVisible(d)) return false;
                      if (_selectedCategory != null &&
                          d['category'] != _selectedCategory)
                        return false;
                      if (_currentPosition != null && _limitByDistance)
                        if (!_isWithinRadius(d)) return false;
                      return true;
                    }).toList();

                if (docs.isEmpty)
                  return const Center(child: Text('No products found.'));

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3 / 4,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final dist = _getDistanceFromUser(d);
                    return GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetails(product: docs[i]),
                            ),
                          ),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (d['imageUrl'] != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.network(
                                  d['imageUrl'],
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${(d['price'] ?? 0).toStringAsFixed(2)} €',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                  if (dist != null)
                                    Text(
                                      '${dist.toStringAsFixed(1)} km away',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  SizedBox(height: 20),
                                  Text(d['category'] ?? ''),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double? _getDistanceFromUser(Map<String, dynamic> data) {
    if (_currentPosition == null) return null;
    return _calculateDistanceKm(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      data['latitude'],
      data['longitude'],
    );
  }
}
