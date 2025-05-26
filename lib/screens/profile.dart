import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String? _email = '';
  double _balance = 0.0;

  Future<void> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      _email = user.email;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _addMoney() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String? email = user.email;
      if (email == null) return;

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('balances')
              .where('email', isEqualTo: email)
              .get();

      double newBalance = 100.0;

      if (querySnapshot.docs.isEmpty) {
        // Step 2: If no document found, add new one with 100
        await FirebaseFirestore.instance.collection('balances').add({
          'email': email,
          'balance': newBalance,
        });
      } else {
        // Step 3: If document exists, update balance
        final doc = querySnapshot.docs.first;
        final currentBalance = (doc.data()['balance'] as num).toDouble();
        newBalance = currentBalance + 100.0;

        await doc.reference.update({'balance': newBalance});
      }

      // Step 4: Update local state
      setState(() {
        _balance = newBalance;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile Page')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Email: ${_email ?? 'Loading...'}',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text('Balance: $_balance', style: TextStyle(fontSize: 18)),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  textStyle: TextStyle(fontSize: 18),
                ),
                onPressed: _logout,
                child: Text('Logout'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  textStyle: TextStyle(fontSize: 18),
                ),
                onPressed: _addMoney,
                child: Text('Add Money'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
