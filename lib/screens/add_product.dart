import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  bool _useCurrentLocation = true;
  File? _image;
  String? _selectedCategory;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  DateTimeRange? _availabilityRange;
  bool _neverAvailable = false;

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

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _availabilityRange = DateTimeRange(
      start: today,
      end: today.add(const Duration(days: 7)),
    );
  }

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
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final querySnapshot =
              await FirebaseFirestore.instance
                  .collection('addresses')
                  .where('uid', isEqualTo: user.uid)
                  .get();

          if (querySnapshot.docs.isNotEmpty) {
            final doc = querySnapshot.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            _latitude = data['latitude'];
            _longitude = data['longitude'];
          }
        }
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
            const SnackBar(content: Text('Product saved successfully!')),
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

    return true;
  }

  Future<String> _uploadProductImage() async {
    final imageId = const Uuid().v4();
    final fileExtension = _image!.path.split('.').last;
    final ref = FirebaseStorage.instance
        .ref()
        .child('product_images')
        .child('$imageId.$fileExtension');
    await ref.putFile(_image!);
    return await ref.getDownloadURL();
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
      'availableFrom':
          _neverAvailable
              ? null
              : Timestamp.fromDate(_availabilityRange!.start),
      'availableTo':
          _neverAvailable ? null : Timestamp.fromDate(_availabilityRange!.end),
      'neverAvailable': _neverAvailable,
      'userEmail': user?.email,
      'uid': user?.uid,
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAvailabilityPicker() {
    return IgnorePointer(
      ignoring: _neverAvailable,
      child: Opacity(
        opacity: _neverAvailable ? 0.5 : 1,
        child: ListTile(
          title: Text(
            'Available from: ${_formatDate(_availabilityRange!.start)}\n'
            'Available to:   ${_formatDate(_availabilityRange!.end)}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _availabilityRange,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary:
                          Colors.blueAccent, // header background & selected day
                      onPrimary: Colors.white, // selected day text
                      surface: Colors.blue.shade50, // dialog background
                      onSurface: Colors.black, // default days text
                    ),
                    datePickerTheme: DatePickerThemeData(
                      rangeSelectionBackgroundColor: Colors.blueAccent
                          .withOpacity(0.2),
                      rangeSelectionOverlayColor: MaterialStateProperty.all(
                        Colors.blueAccent.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _availabilityRange = picked);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: Stack(
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
                    _buildAvailabilityPicker(),
                    _buildNeverAvailableToggle(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
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
      ),
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
      constraints: const BoxConstraints(maxWidth: 500),
      child: SizedBox(
        width: screenWidth * 0.7,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: labelText,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(double screenWidth) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SizedBox(
        width: screenWidth * 0.7,
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Category',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          value: _selectedCategory,
          items:
              _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
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
            activeColor: Colors.blueAccent,
            groupValue: _useCurrentLocation,
            onChanged: (val) => setState(() => _useCurrentLocation = val!),
          ),
        ),
        Expanded(
          child: RadioListTile<bool>(
            title: const Text('Home Address'),
            value: false,
            activeColor: Colors.blueAccent,
            groupValue: _useCurrentLocation,
            onChanged: (val) => setState(() => _useCurrentLocation = val!),
          ),
        ),
      ],
    );
  }

  Widget _buildNeverAvailableToggle() {
    return SwitchListTile(
      title: const Text('Never available'),
      value: _neverAvailable,
      activeColor: Colors.blueAccent,
      onChanged: (v) => setState(() => _neverAvailable = v),
      subtitle: const Text('This item will not appear in the listing.'),
    );
  }
}
