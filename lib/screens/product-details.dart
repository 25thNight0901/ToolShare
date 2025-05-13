import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toolshare/screens/reservation.dart';

class ProductDetails extends StatefulWidget {
  final QueryDocumentSnapshot product;

  const ProductDetails({super.key, required this.product});

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  void _showReservationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ReservationBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.product.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text(data['title'] ?? 'Product Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  data['imageUrl'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              data['title'] ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              data['description'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text('Category: ${data['category'] ?? 'Unknown'}'),
            Text('Price: ${data['price']?.toStringAsFixed(2) ?? '0.00'} €'),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _showReservationModal,
                child: const Text('Reserve'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
