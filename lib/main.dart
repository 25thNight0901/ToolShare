import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:toolshare/screens/dashboard.dart';
import 'package:toolshare/screens/home.dart';
import 'package:toolshare/screens/login.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToolShare',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const Home(),
        '/home': (context) => const Home(),
        '/login': (context) => const Login(),
        '/dashboard': (context) => const Dashboard(),
      },
    );
  }
}
