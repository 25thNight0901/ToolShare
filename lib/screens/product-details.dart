import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toolshare/screens/reservation.dart'; // ReservationBottomSheet location

class ProductDetails extends StatefulWidget {
  final QueryDocumentSnapshot product;

  const ProductDetails({super.key, required this.product});

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  @override
  Widget build(BuildContext context) {
    final data = widget.product.data() as Map<String, dynamic>;

    final String title = data['title'] ?? 'Product Details';
    final String? imageUrl = data['imageUrl'];
    final String description = data['description'] ?? '';
    final String category = data['category'] ?? 'Unknown';
    final double price =
        (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0;
    final String userEmail = data['userEmail'] ?? 'Unavailable';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text('Category: $category'),
            const SizedBox(height: 4),
            Text('Price: ${price.toStringAsFixed(2)} € per day'),
            const SizedBox(height: 8),
            Text(
              'Posted by: $userEmail',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder:
                        (_) => ReservationBottomSheet(
                          productRef: widget.product.reference,
                          title: title,
                          pricePerDay: price,
                        ),
                  );
                },
                child: const Text('Reserve'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
