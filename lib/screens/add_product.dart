import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

class AddProduct extends StatefulWidget {
  const AddProduct({super.key});

  @override
  State<AddProduct> createState() => _AddProductState();
}

class _AddProductState extends State<AddProduct> {
  final _productTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _streetController = TextEditingController();
  final _streetNrController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController();

  bool _useCurrentLocation = true;
  File? _image;
  String? _selectedCategory;
  double? _latitude;
  double? _longitude;
  bool _isAvailable = true;
  bool _isLoading = false;

  final List<String> _categories = [
    'Kitchen Appliances',
    'Cleaning Appliances',
    'Tools & DIY',
    'Laundry & Ironing',
    'Garden Equipment',
    'Heating & Cooling',
    'Other',
  ];

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  Future<void> _getCurrentLocation() async {
    if (await _checkLocationPermission()) {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    }
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _getLocationFromAddress() async {
    final fullAddress =
        "${_streetController.text}, ${_streetNrController.text}, ${_postcodeController.text}, ${_cityController.text}";
    try {
      final locations = await locationFromAddress(fullAddress);
      if (locations.isNotEmpty) {
        setState(() {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
        });
      }
    } catch (e) {
      print("Error in geocoding; $e");
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
    });

    final productTitle = _productTitleController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);

    if (_isFormValid(productTitle, description, price)) {
      if (_useCurrentLocation) {
        await _getCurrentLocation();
      } else {
        await _getLocationFromAddress();
      }

      try {
        final imageUrl = await _uploadProductImage();
        await _saveProductToFirestore(
          productTitle,
          description,
          price,
          imageUrl,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product saved successfully!'),
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
          );
        }
      } catch (e) {
        _showErrorSnackBar(e.toString());
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  bool _isFormValid(String title, String description, double? price) {
    if (title.isEmpty ||
        description.isEmpty ||
        price == null ||
        price <= 0 ||
        _image == null) {
      _showErrorSnackBar('Please fill in all the fields and add an image.');
      return false;
    }

    if (!_useCurrentLocation &&
        (_streetController.text.isEmpty ||
            _streetNrController.text.isEmpty ||
            _postcodeController.text.isEmpty ||
            _cityController.text.isEmpty)) {
      _showErrorSnackBar('Please fill in the full address.');
      return false;
    }

    return true;
  }

  Future<String> _uploadProductImage() async {
    final imageId = const Uuid().v4();
    final fileExtension =
        _image!.path.contains('.') ? _image!.path.split('.').last : 'jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('product_images')
        .child('$imageId.$fileExtension');
    await ref.putFile(_image!);
    final imageUrl = await ref.getDownloadURL();
    return imageUrl;
  }

  Future<void> _saveProductToFirestore(
    String title,
    String description,
    double? price,
    String imageUrl,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('products').add({
      'title': title,
      'description': description,
      'price': price,
      'category': _selectedCategory,
      'imageUrl': imageUrl,
      'latitude': _latitude,
      'longitude': _longitude,
      'createdAt': Timestamp.now(),
      'isAvailable': _isAvailable,
      "userEmail": user?.email,
    });
  }

  void _showErrorSnackBar(String message) {
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildImagePicker(),
                  const SizedBox(height: 20),
                  _buildTextField(
                    _productTitleController,
                    'Product Title',
                    screenWidth,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    _descriptionController,
                    'Description',
                    screenWidth,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    _priceController,
                    'Price (€)',
                    screenWidth,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _buildCategoryDropdown(screenWidth),
                  const SizedBox(height: 20),
                  _buildLocationOption(),
                  const SizedBox(height: 20),
                  _buildAddressFields(screenWidth),
                  const SizedBox(height: 20),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _isAvailable,
                          onChanged: (value) {
                            setState(() {
                              _isAvailable = value ?? true;
                            });
                          },
                        ),
                        const Text('Available for rental'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text('Save Product'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            backgroundImage: _image != null ? FileImage(_image!) : null,
            child:
                _image == null
                    ? const Icon(
                      Icons.camera_alt,
                      size: 30,
                      color: Colors.black54,
                    )
                    : null,
          ),
        ),
        if (_image != null)
          IconButton(
            onPressed: _removeImage,
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelText,
    double screenWidth, {
    TextInputType? keyboardType,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 500),
      child: SizedBox(
        width: screenWidth * 0.7,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: labelText,
            filled: true,
            fillColor: Colors.white,
            // Modified border for the TextField
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                8.0,
              ), // Ensures rounded corners
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                8.0,
              ), // Keeps rounded border even when focused
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                8.0,
              ), // Ensures rounded corners when enabled
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(double screenWidth) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 500),
      child: SizedBox(
        width: screenWidth * 0.7,
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Category',
            labelStyle: TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          value: _selectedCategory,
          items:
              _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
      ),
    );
  }

  Widget _buildLocationOption() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<bool>(
            title: const Text('Current Location'),
            value: true,
            groupValue: _useCurrentLocation,
            onChanged: (val) => setState(() => _useCurrentLocation = val!),
          ),
        ),
        Expanded(
          child: RadioListTile<bool>(
            title: const Text('Choose Address'),
            value: false,
            groupValue: _useCurrentLocation,
            onChanged: (val) => setState(() => _useCurrentLocation = val!),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressFields(double screenWidth) {
    if (!_useCurrentLocation) {
      return Column(
        children: [
          _buildTextField(_streetController, 'Street Name', screenWidth),
          const SizedBox(height: 10),
          _buildTextField(_streetNrController, 'Street Number', screenWidth),
          const SizedBox(height: 10),
          _buildTextField(_postcodeController, 'Postcode', screenWidth),
          const SizedBox(height: 10),
          _buildTextField(_cityController, 'City', screenWidth),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
