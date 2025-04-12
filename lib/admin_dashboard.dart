import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}



class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  bool isFederatedPresident = false; // Track if user is federated president

  // Check if user is federated president
  Future<void> _checkIfFederatedPresident() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['federated_president'] == true) {
          setState(() {
            isFederatedPresident = true;
          });
        } else {
          setState(() {
            isFederatedPresident = false;
          });
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        setState(() {
          isFederatedPresident = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkIfFederatedPresident();
  }

  final List<String> _pageTitles = [
    "Dashboard Overview",
    "Water Stations",
    "District Management", // Switched from "Users"
    "Compliance Documents",
    "Users", // Switched from "District Management"
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                const Text("Admin Panel", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, thickness: 1, height: 30),
                _buildSidebarItem(Icons.dashboard, "Dashboard", 0),
                _buildSidebarItem(Icons.local_drink, "Water Stations", 1),
                _buildSidebarItem(Icons.location_city, "Districts", 2), // Switched to index 2
                _buildSidebarItem(Icons.article, "Compliance", 3),
                _buildSidebarItem(Icons.people, "Users", 4), // Switched to index 4
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
        return _buildRegisteredStationsPage();
      case 2:  // Districts page
        return _buildDistrictManagementPage();
      case 3:
        return _buildCompliancePage();
      case 4:  // Users page
        return _buildUsersPage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildUsersPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                title: Text(data['stationName'] ?? "No Name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(data['email'] ?? "No Email", style: const TextStyle(fontSize: 14)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRegisteredStationsPage() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'station_owner')
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
              trailing: const Icon(Icons.location_on, color: Colors.blue),
              onTap: () {
                // Optionally, navigate to a details page or open a map with the station location
                _showStationDetails(context, data);
              },
            ),
          );
        }).toList(),
      );
    },
  );
}

// Function to show station details in a modal
void _showStationDetails(BuildContext context, Map<String, dynamic> data) async {
  String districtID = data['districtID'] ?? 'Unknown';
  String districtName = "Loading...";

  if (districtID != "Unknown") {
    try {
      DocumentSnapshot districtDoc = await FirebaseFirestore.instance.collection('districts').doc(districtID).get();
      if (districtDoc.exists) {
        districtName = districtDoc['districtName'] ?? 'Unknown District';
      } else {
        districtName = "Unknown District";
      }
    } catch (e) {
      districtName = "Error fetching district";
    }
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("${data['stationName'] ?? 'Unknown'} Details", style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Owner: ${data['firstName']} ${data['lastName']}", style: const TextStyle(fontSize: 14)),
          Text("Contact: ${data['phone'] ?? 'N/A'}", style: const TextStyle(fontSize: 14)),
          Text("District: $districtName", style: const TextStyle(fontSize: 14)),  // ✅ District Name fetched from Firestore
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(fontSize: 14))),
      ],
    ),
  );
}



 Widget _buildDistrictManagementPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('districts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String districtName = data['districtName'] ?? 'No Name';
            String presidentName = data['customUID'] ?? 'Not Assigned';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                title: Text(districtName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text("President: $presidentName", style: const TextStyle(fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _assignPresident(context, data),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _assignPresident(BuildContext context, Map<String, dynamic> districtData) async {
  final String districtID = districtData['districtID'] ?? '';
  String? selectedUID;
  String? selectedUserID; // This stores the Firestore document ID of the user

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Assign District President", style: TextStyle(fontSize: 16)),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'station_owner')
              .where('status', isEqualTo: 'approved')
              .where('districtID', isEqualTo: districtID) // Filter users in the same district
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            List<QueryDocumentSnapshot> users = snapshot.data!.docs;
            if (users.isEmpty) {
              return const Text("No approved station owners available in this district.");
            }

            return StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select District President",
                        border: OutlineInputBorder(),
                      ),
                      items: users.map((user) {
                        var userData = user.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: user.id, // Store user document ID
                          child: Text(userData['stationName'] ?? 'Unnamed User'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedUserID = value;
                          selectedUID = users.firstWhere((user) => user.id == value)['customUID'];
                        });
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              if (selectedUID != null && selectedUserID != null) {
                // Update the district's customUID
                await FirebaseFirestore.instance.collection('districts').doc(districtID).update({
                  'customUID': selectedUID,
                });

                // Update the user as district president
                await FirebaseFirestore.instance.collection('users').doc(selectedUserID).update({
                  'district_president': true,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("District President Assigned Successfully!")),
                );
              }
            },
            child: const Text("Assign", style: TextStyle(fontSize: 14)),
          ),
        ],
      );
    },
  );
}


Widget _buildCompliancePage() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'station_owner')
        .where('status', isEqualTo: 'pending_approval')
        .where('compliance_approved', isEqualTo: true)
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
          String stationName = data['stationName'] ?? 'Unknown';
          String docId = doc.id;  // Assuming the document ID is required here
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text("Station: $stationName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Owner: ${data['firstName'] ?? ''} ${data['lastName'] ?? ''}", style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.visibility),
              onTap: () => _showComplianceModal(context, stationName, docId, customUID),
            ),
          );
        }).toList(),
      );
    },
  );
}


  void _showComplianceModal(BuildContext context, String stationName, String docId, String customUID) async {
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
          onPressed: () async {
            // Approve Button
            await FirebaseFirestore.instance.collection('users').doc(docId).update({
              'status': 'approved',
              'compliance_approved': true,
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Station Approved")));
          },
          child: const Text("Approve", style: TextStyle(fontSize: 14)),
        ),
        TextButton(
          onPressed: () async {
            // Reject Button
            await FirebaseFirestore.instance.collection('users').doc(docId).update({
              'status': 'submit_req',
              'compliance_approved': false,
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Station Rejected")));
          },
          child: const Text("Reject", style: TextStyle(fontSize: 14)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}

}