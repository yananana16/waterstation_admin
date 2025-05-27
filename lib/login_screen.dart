import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import
import 'package:firebase_auth/firebase_auth.dart'; // Add Firebase Auth import
import 'role_selection_screen.dart'; // Import RoleSelectionScreen
import 'admin_dashboard.dart'; // Import Admin Dashboard
import 'district_admin_dashboard.dart'; // Import District Admin Dashboard
import 'select_location_screen.dart';
import 'lgu_dashboard.dart'; // Add this import

class LoginScreen extends StatefulWidget {
  final String selectedRole; // Pass the selected role from the previous screen
  final String? selectedDistrict; // Add this line
  const LoginScreen({
    super.key,
    required this.selectedRole,
    this.selectedDistrict, // Add this line
  });

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

    if (widget.selectedRole == 'federated') {
      try {
        // Authenticate user
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: enteredUsername,
          password: enteredPassword,
        );

        if (userCredential.user != null) {
          String uid = userCredential.user!.uid;

          // Check if the user is admin and federated president in users collection (docId == uid)
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final userData = userDoc.data() as Map<String, dynamic>? ?? {};
          if (userDoc.id == uid && userData['role'] == 'admin' && userData['federated_president'] == true) {
            setState(() {
              _isLoading = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
            return;
          }

          // Check if the user exists in the "station_owners" collection using the userId field
          QuerySnapshot stationOwnerQuery = await FirebaseFirestore.instance
              .collection('station_owners')
              .where('userId', isEqualTo: uid)
              .where('federated_president', isEqualTo: true)
              .where('status', isEqualTo: 'approved')
              .limit(1)
              .get();

          if (stationOwnerQuery.docs.isNotEmpty) {
            setState(() {
              _isLoading = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
            return;
          } else {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Account not found or not a federated president.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Authentication failed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } else {
      // For other roles, use Firebase Auth
      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: enteredUsername,
          password: enteredPassword,
        );
        if (widget.selectedRole == 'district') {
          String uid = userCredential.user!.uid;

          // Check users collection for district admin
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final userData = userDoc.data() as Map<String, dynamic>? ?? {};
          if (userDoc.id == uid &&
              userData['role'] == 'admin' &&
              userData['district_president'] == true &&
              (widget.selectedDistrict == null || userData['districtName'] == widget.selectedDistrict)) {
            setState(() {
              _isLoading = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DistrictAdminDashboard(
                  selectedDistrict: widget.selectedDistrict,
                ),
              ),
            );
            return;
          }

          // Check station_owners collection for district admin
          QuerySnapshot stationOwnerQuery = await FirebaseFirestore.instance
              .collection('station_owners')
              .where('userId', isEqualTo: uid)
              .where('districtName', isEqualTo: widget.selectedDistrict)
              .where('district_president', isEqualTo: true)
              .where('status', isEqualTo: 'approved')
              .limit(1)
              .get();

          if (stationOwnerQuery.docs.isNotEmpty) {
            // Get the station_owner doc ID
            String stationOwnerDocId = stationOwnerQuery.docs.first.id;

            // Check districts collection for matching customUID
            QuerySnapshot districtQuery = await FirebaseFirestore.instance
                .collection('districts')
                .where('customUID', isEqualTo: stationOwnerDocId)
                .limit(1)
                .get();

            if (districtQuery.docs.isNotEmpty) {
              setState(() {
                _isLoading = false;
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DistrictAdminDashboard(
                    selectedDistrict: widget.selectedDistrict,
                  ),
                ),
              );
            } else {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('District record not found or not linked to this account.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          } else {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Account not found or not approved for this district.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        } else if (widget.selectedRole == 'cho_lgu') {
          setState(() {
            _isLoading = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LguDashboard()),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Invalid username or password.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
                  // Left side: Back button and login form
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
                          GestureDetector(
                            onTap: () {
                              if (widget.selectedRole == 'district') {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SelectLocationScreen()),
                                );
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(Icons.arrow_back, color: Colors.blue, size: 18),
                                SizedBox(width: 5),
                                Text(
                                  'Back to Previous Page',
                                  style: TextStyle(
                                    fontSize: screenWidth > 800 ? 16 : 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: screenWidth > 800 ? 40 : 20),
                          Text(
                            'Log in',
                            style: TextStyle(
                              fontSize: screenWidth > 800 ? 48 : 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: screenWidth > 800 ? 40 : 20),
                          // Optionally display the selected district for district role
                          if (widget.selectedRole == 'district' && widget.selectedDistrict != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                'District: ${widget.selectedDistrict}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                fontSize: 16,
                                color: Colors.blue, // Set label text color to blue
                              ),
                              prefixIcon: Icon(Icons.person, color: Colors.blue),
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
                                color: Colors.blue, // Set label text color to blue
                              ),
                              prefixIcon: Icon(Icons.lock, color: Colors.blue),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.blue,
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
                                  color: Colors.blue,
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

                  // Right side: Logo and illustration
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
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
                        Image.asset(
                          'assets/welcome_admin.png', // Replace with the appropriate illustration
                          height: screenWidth > 800 ? 320 : 200,
                        ),
                      ],
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
