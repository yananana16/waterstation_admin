import 'package:flutter/material.dart';
import 'login_screen.dart';
// Add import for SelectLocationScreen
import 'select_location_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  _RoleSelectionScreenState createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;

  void _navigateToLogin() {
    if (selectedRole != null) {
      if (selectedRole == 'district') {
        // Navigate to SelectLocationScreen for District President
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SelectLocationScreen()),
        );
      } else {
        // Navigate to LoginScreen for other roles
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen(selectedRole: selectedRole!)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a role to proceed.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: screenWidth > 800
          ? Row(
              children: [
                // Left side: Welcome message and image
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            "Let's keep the water business flowing smoothly.",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 40),
                          Image.asset(
                            'assets/welcome_admin.png',
                            height: 300,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Right side: Role selection and logo
                Expanded(
                  flex: 1,
                  child: _buildRoleSelection(context, screenWidth),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 40),
                        Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Let's keep the water business flowing smoothly.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 30),
                        Image.asset(
                          'assets/welcome_admin.png',
                          height: 250,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  _buildRoleSelection(context, screenWidth),
                ],
              ),
            ),
    );
  }

  Widget _buildRoleSelection(BuildContext context, double screenWidth) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: screenWidth > 800
            ? BorderRadius.only(
                topLeft: Radius.circular(30),
                bottomLeft: Radius.circular(30),
              )
            : BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 1,
                child: Image.asset(
                  'assets/logo.png',
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
                      fontSize: screenWidth > 800 ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    'Where safety meets efficiency.',
                    style: TextStyle(
                      fontSize: screenWidth > 800 ? 16 : 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Select your role:',
                  style: TextStyle(
                    fontSize: screenWidth > 800 ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),
                RadioListTile(
                  title: Text('Federated President'),
                  value: 'federated',
                  groupValue: selectedRole,
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value as String?;
                    });
                  },
                ),
                RadioListTile(
                  title: Text('District President'),
                  value: 'district',
                  groupValue: selectedRole,
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value as String?;
                    });
                  },
                ),
                RadioListTile(
                  title: Text('CHO / LGU'),
                  value: 'cho_lgu',
                  groupValue: selectedRole,
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value as String?;
                    });
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: _navigateToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 800 ? 60 : 40,
                vertical: screenWidth > 800 ? 18 : 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Next',
              style: TextStyle(
                fontSize: screenWidth > 800 ? 20 : 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
