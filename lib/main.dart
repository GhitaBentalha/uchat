import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uchat/pages/signup.dart';
import 'pages/signin.dart';
import 'pages/home.dart'; // Import your home page (you'll need to create it)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: const SignUp() // Set the SignUp screen as the entry point
        );
  }
}
