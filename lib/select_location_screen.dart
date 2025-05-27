import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart'; // Add this import

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  String? selectedLocation;

  final List<String> locations = [
    'La Paz',
    'Jaro 1',
    'Jaro 2',
    'Mandurriao',
    'Lapuz',
    'City Proper 1',
    'City Proper 2',
    'Molo',
    'Arevalo',
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left: Selection Card
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      'Select Location',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0070C0),
                        letterSpacing: 1,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 8),
                    // Back link
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Color(0xFF0070C0), size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Back to Previous Page',
                            style: TextStyle(
                              color: Color(0xFF0070C0),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    // Card
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 2-column grid of radio buttons
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < 5; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: RadioListTile<String>(
                                          title: Text(locations[i], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                          value: locations[i],
                                          groupValue: selectedLocation,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedLocation = value;
                                            });
                                          },
                                          contentPadding: EdgeInsets.zero,
                                          activeColor: Color(0xFF0070C0),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              // Right column
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var i = 5; i < locations.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: RadioListTile<String>(
                                          title: Text(locations[i], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                          value: locations[i],
                                          groupValue: selectedLocation,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedLocation = value;
                                            });
                                          },
                                          contentPadding: EdgeInsets.zero,
                                          activeColor: Color(0xFF0070C0),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          // Next button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: selectedLocation == null ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginScreen(
                                      selectedRole: 'district',
                                      selectedDistrict: selectedLocation!,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF0070C0),
                                padding: EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 2,
                                textStyle: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: Text('Next', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Right: Illustration
              if (screenWidth > 800)
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Image.asset(
                      'assets/location_illustration.png',
                      height: 280,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
