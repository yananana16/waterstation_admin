import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'admin_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'district_admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String errorMessage = "";
  bool isLoading = false; // Variable to track loading state

  void _login() async {
  setState(() {
    isLoading = true; // Show loading indicator
  });

  try {
    // Sign in the user with email and password
    User? user = await _authService.signIn(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (user != null) {
      // Fetch the user from Firestore based on UID
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid) // Use UID for direct document fetch
          .get();

      if (userDoc.exists) {
        // Check if the 'federated_president' and 'district_president' fields are true
        bool isFederatedPresident = userDoc['federated_president'] ?? false;
        bool isDistrictPresident = userDoc['district_president'] ?? false;

        print('Is Federated President: $isFederatedPresident');
        print('Is District President: $isDistrictPresident');

        if (isFederatedPresident && isDistrictPresident) {
          // If both roles are true, show a choice for federated or district login
          _showRoleSelectionDialog();
        } else if (isFederatedPresident) {
          // If the user is a federated president, navigate to Admin Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminDashboard()),
          );
        } else if (isDistrictPresident) {
          // If the user is a district president, navigate to District Admin Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DistrictAdminDashboard()),
          );
        } else {
          setState(() {
            errorMessage = "You are not authorized to access the admin dashboard.";
          });
        }
      } else {
        setState(() {
          errorMessage = "User does not exist in the database.";
        });
      }
    } else {
      setState(() {
        errorMessage = "Invalid email or password.";
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = "An error occurred. Please try again later.";
    });
    print('Error: $e');
  } finally {
    setState(() {
      isLoading = false; // Hide loading indicator once done
    });
  }
}

// Function to show a dialog to choose between federated or district login
void _showRoleSelectionDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Choose Login Type'),
        content: Text('You have both roles. Please choose one:'),
        actions: [
          TextButton(
            onPressed: () {
              // Navigate to Federated Admin Dashboard
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AdminDashboard()),
              );
            },
            child: Text('Federated Login'),
          ),
          TextButton(
            onPressed: () {
              // Navigate to District Admin Dashboard
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => DistrictAdminDashboard()),
              );
            },
            child: Text('District Login'),
          ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Login'),
        backgroundColor: Colors.blue, // Blue color for the theme
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Add a logo or icon
                Icon(
                  Icons.water_drop,
                  size: 100,
                  color: Colors.blueAccent,
                ),
                SizedBox(height: 20),

                // Email TextField
                SizedBox(
                  width: 350, // Limit the width of the input field
                  child: TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.blue[50], // Light blue background
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                SizedBox(height: 20),

                // Password TextField
                SizedBox(
                  width: 350, // Limit the width of the input field
                  child: TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.blue[50], // Light blue background
                    ),
                    obscureText: true,
                  ),
                ),
                SizedBox(height: 20),

                // Error message display
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      errorMessage,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Loading indicator if isLoading is true
                if (isLoading)
                  CircularProgressIndicator(
                    color: Colors.blue, // Blue color for the loading indicator
                  ),

                // Login Button
                if (!isLoading)
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Button color
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white, // Text color white
                      ),
                    ),
                  ),
                SizedBox(height: 20),

                // Optional: Add a "Forgot Password" text
                GestureDetector(
                  onTap: () {
                    // Add functionality for "Forgot Password"
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
