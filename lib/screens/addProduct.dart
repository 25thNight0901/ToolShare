import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddProduct extends StatefulWidget {
  const AddProduct({super.key});

  @override
  State<AddProduct> createState() => _AddProductState();
}

class _AddProductState extends State<AddProduct> {
  final _productTitelController = TextEditingController();
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
  double? _logitude;
  Position? _location;

  final List<String> _categories = [
    'Kitchen Appliances',
    'Cleaning Aplliances',
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
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    final position = await Geolocator.getCurrentPosition();
    _latitude = position.latitude;
    _logitude = position.longitude;
  }

  Future<void> _getLocationFromAddress() async {
    final fullAdress =
        "${_streetController.text},${_streetNrController.text}, ${_postcodeController.text}, ${_cityController.text}";
    try {
      List<Location> locations = await locationFromAddress(fullAdress);
      if (locations.isNotEmpty) {
        _latitude = locations.first.latitude;
        _logitude = locations.first.longitude;
      }
    } catch (e) {
      print("Error in geocoding; $e");
    }
  }

  void _submit() async {
    final productTitel = _productTitelController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);

    if (productTitel.isEmpty ||
        description.isEmpty ||
        price == null ||
        price <= 0 ||
        _image == null) {
      Navigator.of(context).pop();
      Future.delayed(const Duration(milliseconds: 100), () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all the fields and add an image.'),
          ),
        );
      });
      return;
    }

    if (!_useCurrentLocation &&
        (_streetController.text.isEmpty ||
            _streetNrController.text.isEmpty ||
            _postcodeController.text.isEmpty ||
            _cityController.text.isEmpty)) {
      Navigator.of(context).pop();
      Future.delayed(const Duration(milliseconds: 100), () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in the full address.')),
        );
      });
      return;
    }

    if (_useCurrentLocation) {
      await _getCurrentLocation();
    } else {
      await _getLocationFromAddress();
    }

    print('submitted');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Product',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          _image != null ? FileImage(_image!) : null,
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
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _productTitelController,
                decoration: const InputDecoration(
                  labelText: 'Product Title',
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (€)',
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  border: OutlineInputBorder(),
                ),
                value: _selectedCategory,
                items:
                    _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Current Location'),
                      value: true,
                      groupValue: _useCurrentLocation,
                      onChanged:
                          (val) => setState(() => _useCurrentLocation = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Choose Address'),
                      value: false,
                      groupValue: _useCurrentLocation,
                      onChanged:
                          (val) => setState(() => _useCurrentLocation = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!_useCurrentLocation) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _streetController,
                        decoration: const InputDecoration(
                          labelText: 'Street Name',
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _streetNrController,
                        decoration: const InputDecoration(
                          labelText: 'Street Number',
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _postcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Postcode',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
