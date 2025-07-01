import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'create_post_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA-CTQUjgD8FqUKKKFyBCH-HwzAz2TMQAU",
      appId: "1:586513429846:web:84fe7df6c83debdb4d92f7",
      messagingSenderId: "586513429846",
      projectId: "appmovil2-19f0f",
    ),
  );

  // Supabase initialization
  await Supabase.initialize(
    url: 'https://pibmeiawsijihynofbrt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpYm1laWF3c2lqaWh5bm9mYnJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTc1OTgsImV4cCI6MjA2Mzg3MzU5OH0.LXowIex23igbXXJgUoPIwoZSOQyZ1_sxCOPfE8ADP0M',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turismo Ciudadano',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/create': (context) => const CreatePostPage(),
      },
    );
  }
}

/// Esta clase detecta si el usuario ya está logueado o no
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb_auth.User?>(
      stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          return const HomePage(); // Usuario ya logueado
        } else {
          return const LoginPage(); // Usuario no logueado
        }
      },
    );
  }
}
