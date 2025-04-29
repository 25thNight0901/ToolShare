import 'package:flutter/material.dart';
import 'package:toolshare/screens/addProduct.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  void _openAddProductForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddProduct(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ToolShare'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.home),
                  iconSize: 40,
                  tooltip: 'Go to Home',
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                  iconSize: 40,
                  tooltip: 'Search product',
                ),
                IconButton(
                  onPressed: () => _openAddProductForm(context),
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 40,
                  tooltip: 'Add product',
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.person),
                  iconSize: 40,
                  tooltip: 'User profile',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
