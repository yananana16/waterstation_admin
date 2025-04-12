import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'auth_service.dart';
import 'login_screen.dart';

class DistrictAdminDashboard extends StatefulWidget {
  const DistrictAdminDashboard({super.key});

  @override
  _DistrictAdminDashboardState createState() => _DistrictAdminDashboardState();
}

class _DistrictAdminDashboardState extends State<DistrictAdminDashboard> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;

  final List<String> _pageTitles = [
    "Dashboard Overview",
    "Water Stations",
    "Compliance Documents",
  ];

  late String districtID;

  @override
  void initState() {
    super.initState();
    _getDistrictID();
    _loadSelectedIndex();  // Load the selected index from SharedPreferences
  }

  Future<void> _getDistrictID() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          districtID = userDoc['districtID'] ?? '';
        });
      }
    }
  }

  // Load the selected page index from SharedPreferences
  Future<void> _loadSelectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedIndex = prefs.getInt('selectedIndex') ?? 0;  // Default to 0 if not found
    });
  }

  // Save the selected page index to SharedPreferences
  Future<void> _saveSelectedIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('selectedIndex', index);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _saveSelectedIndex(index);  // Save the selected index when it's changed
  }

  void _logout(BuildContext context) async {
    await _authService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: Colors.blueAccent,
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.water_drop, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                const Text("District Admin Panel", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, thickness: 1, height: 30),
                _buildSidebarItem(Icons.dashboard, "Dashboard", 0),
                _buildSidebarItem(Icons.local_drink, "Water Stations", 1),
                _buildSidebarItem(Icons.article, "Compliance Documents", 2),
                const Spacer(),
                _buildSidebarItem(Icons.logout, "Logout", -1),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blueAccent[700],
                  child: Text(
                    _pageTitles[_selectedIndex],
                    style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                // Body
                Expanded(
                  child: Center(
                    child: _getSelectedPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return Material(
      color: isSelected ? Colors.blueAccent[700] : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (index == -1) {
            _logout(context);
          } else {
            _onItemTapped(index);
          }
        },
        child: ListTile(
          leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
          title: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 14),
          ),
          tileColor: isSelected ? Colors.blueAccent[800] : Colors.transparent,
          hoverColor: Colors.blueAccent[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        ),
      ),
    );
  }

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text("Dashboard Overview"));
      case 1:
        return _buildWaterStationsPage();
      case 2:
        return _buildCompliancePage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildWaterStationsPage() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users')
        .where('districtID', isEqualTo: districtID)
        .where('compliance_approved', isEqualTo: true)
        .where('status', isEqualTo: 'approved')
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data!.docs.isEmpty) {
        return const Center(child: Text("No registered water stations yet."));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: snapshot.data!.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String stationName = data['stationName'] ?? "Unknown";
          String ownerName = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}";
          String contact = data['phone'] ?? 'N/A';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text("Station: $stationName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Owner: $ownerName", style: const TextStyle(fontSize: 14)),
                  Text("phone: $contact", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}
  Widget _buildCompliancePage() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .where('districtID', isEqualTo: districtID)
        .where('compliance_approved', isEqualTo: false)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: snapshot.data!.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String customUID = data['customUID'] ?? "unknown";
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text("Station: ${data['stationName'] ?? 'Unknown'}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Owner: ${data['firstName'] ?? 'Unknown'} ${data['lastName'] ?? ''}",
                  style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.visibility),
              onTap: () => _showComplianceModal(context, customUID, data['stationName'], doc.id),
            ),
          );
        }).toList(),
      );
    },
  );
}

void _showComplianceModal(BuildContext context, String customUID, String stationName, String docId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.storage.from('compliance_docs').list(path: 'uploads/$customUID/');

  if (response.isEmpty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Compliance Documents for $stationName", style: const TextStyle(fontSize: 16)),
        content: const Text("No documents uploaded.", style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(fontSize: 14)))
        ],
      ),
    );
    return;
  }

  Map<String, List<String>> categorizedFiles = {
    "Bacteriological": [],
    "Physical-Chemical": [],
    "Other Documents": []
  };

  for (var file in response) {
    String filePath = 'uploads/$customUID/${file.name}';
    String publicUrl = supabase.storage.from('compliance_docs').getPublicUrl(filePath);

    if (file.name.contains("bacteriological")) {
      categorizedFiles["Bacteriological"]!.add(publicUrl);
    } else if (file.name.contains("physical")) {
      categorizedFiles["Physical-Chemical"]!.add(publicUrl);
    } else {
      categorizedFiles["Other Documents"]!.add(publicUrl);
    }
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Compliance Documents for $stationName", style: const TextStyle(fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: categorizedFiles.entries.map((entry) {
            return entry.value.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${entry.key}:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 5),
                      ...entry.value.map((url) => TextButton(
                            onPressed: () => launchUrl(Uri.parse(url)),
                            child: Text(url.split('/').last, style: const TextStyle(color: Colors.blue, fontSize: 14)),
                          )),
                      const SizedBox(height: 10),
                    ],
                  )
                : const SizedBox();
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FirebaseFirestore.instance.collection('users').doc(docId).update({'compliance_approved': true});
            Navigator.pop(context);
          },
          child: const Text("Accept", style: TextStyle(color: Colors.green, fontSize: 14)),
        ),
        TextButton(
          onPressed: () {
            FirebaseFirestore.instance.collection('users').doc(docId).update({'status': "submit_req"});
            Navigator.pop(context);
          },
          child: const Text("Decline", style: TextStyle(color: Colors.red, fontSize: 14)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(fontSize: 14)),
        )
      ],
    ),
  );
}
}