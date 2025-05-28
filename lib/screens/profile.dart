import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String? _email = '';
  double _balance = 0.0;

  bool _isLoading = false;

  double _latitude = 0;
  double _longitude = 0;

  final _streetController = TextEditingController();
  final _streetNrController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController();

  Future<void> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      _email = user.email;
    });

    _loadAddress();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('balances')
              .where('uid', isEqualTo: user.uid)
              .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;

        final dynamic balanceData = data['balance'];

        if (balanceData != null) {
          if (balanceData is num) {
            _balance = balanceData.toDouble();
          } else if (balanceData is String) {
            _balance = double.tryParse(balanceData) ?? 0.0;
          } else {
            _balance = 0.0;
          }
        }
      }
    }
  }

  Future<void> _loadAddress() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String uid = user.uid;

      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('addresses')
              .where('uid', isEqualTo: uid)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;

        final String? streetName = data['streetName'] as String?;
        final String? streetNumber = data['streetNumber'] as String?;
        final String? postCode = data['postcode'] as String?;
        final String? city = data['city'] as String?;

        if (streetName != null &&
            streetNumber != null &&
            postCode != null &&
            city != null) {
          setState(() {
            _streetController.text = streetName;
            _streetNrController.text = streetNumber;
            _postcodeController.text = postCode;
            _cityController.text = city;
          });
        }
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _addMoney() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String uid = user.uid;

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('balances')
              .where('uid', isEqualTo: uid)
              .get();

      double newBalance = 100.0;

      if (querySnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('balances').add({
          'uid': uid,
          'balance': newBalance,
        });
      } else {
        final doc = querySnapshot.docs.first;
        final currentBalance = (doc.data()['balance'] as num).toDouble();
        newBalance = currentBalance + 100.0;

        await doc.reference.update({'balance': newBalance});
      }

      setState(() {
        _balance = newBalance;
      });
    }
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
      print("Error in geocoding: $e");
    }
  }

  bool _isFormValid() {
    if (_streetController.text.isEmpty ||
        _streetNrController.text.isEmpty ||
        _postcodeController.text.isEmpty ||
        _cityController.text.isEmpty) {
      _showErrorSnackBar('Please fill in the full address.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
    });

    if (_isFormValid()) {
      await _getLocationFromAddress();

      try {
        await _saveAddressToFirestore();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address saved successfully!')),
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

  Future<void> _saveAddressToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('addresses')
              .where('uid', isEqualTo: user.uid)
              .get();

      if (querySnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('addresses').add({
          'uid': user.uid,
          'latitude': _latitude,
          'longitude': _longitude,
          'streetName': _streetController.text,
          'streetNumber': _streetNrController.text,
          'postcode': _postcodeController.text,
          'city': _cityController.text,
        });
      } else {
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        final bool isChanged =
            data['latitude'] != _latitude ||
            data['longitude'] != _longitude ||
            data['streetName'] != _streetController.text ||
            data['streetNumber'] != _streetNrController.text ||
            data['postcode'] != _postcodeController.text ||
            data['city'] != _cityController.text;

        if (isChanged) {
          await FirebaseFirestore.instance
              .collection('addresses')
              .doc(doc.id)
              .update({
                'uid': user.uid,
                'latitude': _latitude,
                'longitude': _longitude,
                'streetName': _streetController.text,
                'streetNumber': _streetNrController.text,
                'postcode': _postcodeController.text,
                'city': _cityController.text,
              });
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: Text('Profile Page')),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Email: ${_email ?? 'Loading...'}',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    Text('Balance: $_balance', style: TextStyle(fontSize: 18)),
                    SizedBox(height: 20),
                    _buildAddressFields(screenWidth),
                    SizedBox(height: 20),
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
                              : const Text('Save Address'),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addMoney,
                      child: Text('Add Money'),
                    ),
                    SizedBox(height: 50),
                    ElevatedButton(onPressed: _logout, child: Text('Logout')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressFields(double screenWidth) {
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
}
