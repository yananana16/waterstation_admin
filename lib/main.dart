import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ygrdgnohxkwbkuftieil.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlncmRnbm9oeGt3Ymt1ZnRpZWlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE3NTUyOTgsImV4cCI6MjA1NzMzMTI5OH0.j7jVz-Zx4KcEKxBPHbqRNyMxQmwDsQaEq3xiK4afgxc', 
  );

  await dotenv.load();

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(   
        apiKey: dotenv.env['API_KEY'] ?? '',
        authDomain: dotenv.env['AUTH_DOMAIN'] ?? '',
        projectId: dotenv.env['PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['STORAGE_BUCKET'] ?? '',
        messagingSenderId: dotenv.env['MESSAGING_SENDER_ID'] ?? '',
        appId: dotenv.env['APP_ID'] ?? '',
      ),
    );
    print("✅ Firebase Initialized Successfully");

    // Firebase connectivity check
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      print("✅ Connected to Firebase Auth. User: ${firebaseUser.uid}");
    } else {
      print("ℹ️ No Firebase user signed in.");
    }
  } catch (e) {
    print("❌ Firebase Initialization Failed: $e");
  }

  // Supabase connectivity check
  try {
    final supabaseClient = Supabase.instance.client;
    final session = supabaseClient.auth.currentSession;
    if (session != null) {
      print("✅ Connected to Supabase. Session user: ${session.user.id}");
    } else {
      print("ℹ️ No Supabase session found.");
    }
    // Optionally, try a simple query (uncomment if you have a table):
    // final response = await supabaseClient.from('your_table').select().limit(1).execute();
    // print("Supabase test query: ${response.data}");
  } catch (e) {
    print("❌ Supabase connectivity check failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Water Station Admin',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RoleSelectionScreen(), // Set RoleSelectionScreen as the initial screen
    );
  }
}

