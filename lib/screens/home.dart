import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _registerUser() async {
    try {
      String email = _emailController.text;
      String password = _passwordController.text;

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User registered and logged in!')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: const Icon(Icons.handyman),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 180),
            Text(
              'Welcome to ToolShare!',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Text(
              'Sign up',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: SizedBox(
                width: screenWidth * 0.7,
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined),
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: SizedBox(
                width: screenWidth * 0.7,
                child: TextField(
                  obscureText: true,
                  controller: _passwordController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.password),
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _registerUser();
              },
              child: const Text(
                'Sign up',
                style: TextStyle(color: Colors.black, fontSize: 20),
              ),
              // input velden
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text(
                'Login',
                style: TextStyle(color: Colors.black, fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
