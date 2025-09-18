import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import
import 'package:firebase_auth/firebase_auth.dart'; // Add Firebase Auth import/ Import RoleSelectionScreen
import 'federated/admin_dashboard.dart'; // Import Admin Dashboard
import 'district/district_admin_dashboard.dart'; // Import District Admin Dashboard
import 'LGU/lgu_dashboard.dart'; // Add this import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; // Add loading state

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    final enteredUsername = _usernameController.text.trim();
    final enteredPassword = _passwordController.text.trim();

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: enteredUsername,
        password: enteredPassword,
      );
      if (userCredential.user != null) {
        String uid = userCredential.user!.uid;
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};

        // Determine role and route accordingly
        if (userDoc.id == uid && userData['federated_president'] == true && userData['role'] == 'admin') {
          setState(() { _isLoading = false; });
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
          return;
        }
        if (userDoc.id == uid && userData['role'] == 'admin' && userData['district_president'] == true) {
          setState(() { _isLoading = false; });
          Navigator.push(context, MaterialPageRoute(builder: (context) => DistrictAdminDashboard()));
          return;
        }
        if (userDoc.id == uid && userData['role'] == 'cho_lgu') {
          setState(() { _isLoading = false; });
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LguDashboard()));
          return;
        }

        // If not found in users, check station_owners for district admin
        QuerySnapshot stationOwnerQuery = await FirebaseFirestore.instance
            .collection('station_owners')
            .where('userId', isEqualTo: uid)
            .where('district_president', isEqualTo: true)
            .where('status', isEqualTo: 'approved')
            .limit(1)
            .get();

        if (stationOwnerQuery.docs.isNotEmpty) {
          var stationOwnerDoc = stationOwnerQuery.docs.first;
          String stationOwnerDocId = stationOwnerDoc.id;
          QuerySnapshot districtQuery = await FirebaseFirestore.instance
              .collection('districts')
              .where('customUID', isEqualTo: stationOwnerDocId)
              .limit(1)
              .get();
          if (districtQuery.docs.isNotEmpty) {
            setState(() { _isLoading = false; });
            Navigator.push(context, MaterialPageRoute(builder: (context) => DistrictAdminDashboard()));
            return;
          } else {
            setState(() { _isLoading = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('District record not found or not linked to this account.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
        }

        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account not found or not authorized for any role.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Invalid username or password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 1200), // Limit the maximum width
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left side: Logo and illustration
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors:[
                            Color(0xFFF9FBFF), // near white
                            Color(0xFFEAF3FF), // light blue
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Positioned(
                              top: 1,
                              child: Image.asset(
                                'assets/logo.png', // Match the logo from role_selection_screen
                                height: screenWidth > 800 ? 220 : 150,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: screenWidth > 800 ? 150 : 100),
                                Text(
                                  'H2OGO',
                                  style: TextStyle(
                                    fontSize: screenWidth > 800 ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  'Where safety meets efficiency.',
                                  style: TextStyle(
                                    fontSize: screenWidth > 800 ? 14 : 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 40),
                        // Image.asset(
                        //   'assets/welcome_admin.png', // Replace with the appropriate illustration
                        //   height: screenWidth > 800 ? 320 : 200,
                        // ),
                      ],
                    ),
                  ),
                  ),
                  // Right side: Back button and login form
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth > 800 ? 40.0 : 20.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WELCOME',
                            style: TextStyle(
                              fontSize: screenWidth > 800 ? 50 : 20,
                              color: Color(0xFF0066B2),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Log in to your account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: screenWidth > 800 ? 40 : 20),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF0066B2), // Set label text color to blue
                              ),
                              prefixIcon: Icon(Icons.person, color: Color(0xFF0066B2)),
                              filled: true,
                              fillColor: Color(0xFFEAF3FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF0066B2), // Set label text color to blue
                              ),
                              prefixIcon: Icon(Icons.lock, color: Color(0xFF0066B2)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Color(0xFF0066B2),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Color(0xFFEAF3FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                // Handle password reset logic
                              },
                              child: Text(
                                'Forgot Password? Reset',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0066B2),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: screenWidth > 800 ? 40 : 20),
                          ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth > 800 ? 50 : 30,
                                vertical: screenWidth > 800 ? 18 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: screenWidth > 800 ? 20 : 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

