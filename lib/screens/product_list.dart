import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  int _selectedIndex = 0;

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

  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool _isVisible(Map<String, dynamic> d) {
    final now = DateTime.now();
    final fromTs = d['availableFrom'] as Timestamp?;
    final toTs = d['availableTo'] as Timestamp?;
    if (fromTs != null && toTs != null) {
      final from = fromTs.toDate(), to = toTs.toDate();
      if (now.isBefore(from) || now.isAfter(to)) return false;
    }
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
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ToggleButtons(
              isSelected: [_selectedIndex == 0, _selectedIndex == 1],
              onPressed: (index) {
                setState(() {
                  _selectedIndex = index;
                  _selectedCategory = null;
                });
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: Colors.blue,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Your Products'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Your Reservations'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_selectedIndex == 0)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: DropdownButton<String>(
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
            ),
          Expanded(
            child:
                _selectedIndex == 0
                    ? _buildProductList()
                    : _buildReservationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('products')
              .where('uid', isEqualTo: _currentUserId)
              .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return const Center(child: Text('Error'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs =
            snap.data!.docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              if (!_isVisible(d)) return false;
              if (_selectedCategory != null &&
                  d['category'] != _selectedCategory) {
                return false;
              }
              return true;
            }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No products found.'));
        }

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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${(d['price'] ?? 0).toStringAsFixed(2)} €',
                            style: const TextStyle(color: Colors.green),
                          ),
                          const SizedBox(height: 20),
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
    );
  }

  Widget _buildReservationList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('reservations')
              .where('userId', isEqualTo: _currentUserId)
              .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError)
          return const Center(child: Text('Error loading reservations.'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final reservations = snap.data!.docs;

        if (reservations.isEmpty) {
          return const Center(child: Text('No reservations found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reservations.length,
          itemBuilder: (ctx, i) {
            final reservation = reservations[i];
            final data = reservation.data() as Map<String, dynamic>;
            final productId = data['productId'] as String?;

            if (productId == null) return const SizedBox.shrink();

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('products')
                      .doc(productId)
                      .get(),
              builder: (ctx, productSnap) {
                if (!productSnap.hasData) return const SizedBox.shrink();
                final product = productSnap.data!;
                if (!product.exists) return const SizedBox.shrink();

                final pData = product.data() as Map<String, dynamic>;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  leading:
                      pData['imageUrl'] != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              pData['imageUrl'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          )
                          : const Icon(Icons.image_not_supported),
                  title: Text(pData['title'] ?? 'No Title'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${(pData['price'] ?? 0).toStringAsFixed(2)} €'),
                      if (data['reservedFrom'] != null &&
                          data['reservedTo'] != null)
                        Text(
                          'From: ${_formatDate(data['reservedFrom'])} - To: ${_formatDate(data['reservedTo'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDate(Timestamp ts) {
    final date = ts.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
