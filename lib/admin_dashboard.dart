import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart'; // <-- Add this import if RoleSelectionScreen is defined in this file
import 'package:fl_heatmap/fl_heatmap.dart'; 
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  bool isFederatedPresident = false; // Track if user is federated president
  bool _isLoading = false; // <-- Add this line
  bool _showSettingsPage = false; // <-- Add this line
  bool _showNotificationsPage = false; // <-- Add this line
  String? _selectedDistrictForOwners; // <-- Add this line
  LatLng? _mapSelectedLocation;
  final MapController _mapController = MapController(); // <-- Add this line
  final TextEditingController _searchController = TextEditingController(); // <-- Add this line
  String _searchQuery = ""; // <-- Add this line

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
            MaterialPageRoute(builder: (context) => const LoginScreen(selectedRole: 'admin')),
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
    "Profile", // Changed from "Users" to "Profile"
  ];

  void _onItemTapped(int index) async {
    setState(() {
      _isLoading = true;
      _showSettingsPage = false;
      _showNotificationsPage = false; // <-- Close notifications on navigation
    });
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _selectedIndex = index;
      _isLoading = false;
    });
  }

  void _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.only(top: 32, left: 24, right: 24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        title: const Text(
          "Logout Confirmation",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            "Are you sure you want to do logout?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Confirm"),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              minimumSize: const Size(120, 40),
              side: const BorderSide(color: Colors.blueAccent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await _authService.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? "Admin Panel";
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
                // Admin panel logo and info (updated to match provided image)
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Admin",
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  "admin@gmail.com",
                  style: TextStyle(fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(color: Colors.white24, thickness: 1, height: 30),
                _buildSidebarItem(Icons.dashboard, "Dashboard", 0),
                _buildSidebarItem(Icons.local_drink, "Water Stations", 1),
                _buildSidebarItem(Icons.location_city, "Districts", 2),
                _buildSidebarItem(Icons.article, "Compliance", 3),
                const Spacer(),
                _buildSidebarItem(Icons.person, "Profile", 4), // Move Profile above Logout
                _buildSidebarItem(Icons.logout, "Logout", -1),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Body
                      Expanded(
                        child: Center(
                          child: _showNotificationsPage
                              ? _buildNotificationsPage()
                              : _showSettingsPage
                                  ? _buildSettingsPage()
                                  : _getSelectedPage(),
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
        return _buildDashboardOverview();
      case 1:
        return _buildRegisteredStationsPage();
      case 2:  // Districts page
        return _buildDistrictManagementPage();
      case 3:
        return _buildCompliancePage();
      case 4:  // Profile page
        return _buildProfilePage(); // Changed from _buildUsersPage to _buildProfilePage
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildDashboardOverview() {
    return Column(
      children: [
        // Header Section
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE3F2FD),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Dashboard Overview",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blueAccent),
                    onPressed: () {
                      setState(() {
                        _showSettingsPage = true;
                        _showNotificationsPage = false;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.blueAccent),
                        onPressed: () {
                          setState(() {
                            _showNotificationsPage = true;
                            _showSettingsPage = false;
                          });
                        },
                      ),
                      // Notification badge
                      Positioned(
                        right: 8,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 5,
                            minHeight: 2,
                          ),
                          child: const Text(
                            '3', // <-- Set your new notification count here
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Statistics Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth >= 800;
              return isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatisticCard("Pending Compliance Approvals", "45"),
                        const SizedBox(width: 16),
                        _buildStatisticCard("Number of Compliant Station", "285"),
                        const SizedBox(width: 16),
                        _buildStatisticCard("Non-Compliant Stations", "178"),
                      ],
                    )
                  : Column(
                      children: [
                        _buildStatisticCard("Pending Compliance Approvals", "45"),
                        const SizedBox(height: 16),
                        _buildStatisticCard("Number of Compliant Station", "285"),
                        const SizedBox(height: 16),
                        _buildStatisticCard("Non-Compliant Stations", "178"),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Heatmap and District Station Counts
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth >= 800;
                return isDesktop
                    ? Row(
                        children: [
                          // Heatmap Section
                          Expanded(
                            flex: 2,
                            child: _buildHeatmapSection(),
                          ),
                          const SizedBox(width: 20),
                          // District Station Counts
                          Expanded(
                            child: _buildDistrictStationCounts(),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // Heatmap Section
                          _buildHeatmapSection(),
                          const SizedBox(height: 20),
                          // District Station Counts
                          _buildDistrictStationCounts(),
                        ],
                      );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapSection() {
    // Sample data: rows = districts, columns = months
    final List<String> districts = [
      "La Paz", "Jaro 1", "Jaro 2", "Mandurriao", "City Proper 1", "City Proper 2", "Molo", "Lapuz", "Arevalo"
    ];
    final List<String> months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    // Random/simulated compliance rates (0-100)
    final List<List<double>> complianceRates = [
      [90, 85, 80, 95, 88, 92, 87, 90, 93, 89, 91, 94],
      [70, 75, 78, 80, 82, 85, 88, 90, 92, 91, 89, 87],
      [60, 65, 68, 70, 72, 75, 78, 80, 82, 81, 79, 77],
      [95, 92, 90, 93, 94, 96, 97, 98, 99, 97, 95, 94],
      [80, 82, 84, 86, 88, 90, 92, 94, 96, 95, 93, 91],
      [50, 55, 58, 60, 62, 65, 68, 70, 72, 71, 69, 67],
      [85, 87, 89, 91, 93, 95, 97, 99, 98, 96, 94, 92],
      [75, 77, 79, 81, 83, 85, 87, 89, 91, 90, 88, 86],
      [65, 67, 69, 71, 73, 75, 77, 79, 81, 80, 78, 76],
    ];

    Color getCellColor(double value) {
      if (value >= 90) return const Color(0xFF4CAF50); // Green
      if (value >= 80) return const Color(0xFF8BC34A); // Light Green
      if (value >= 70) return const Color(0xFFFFEB3B); // Yellow
      if (value >= 60) return const Color(0xFFFFA726); // Orange
      return const Color(0xFFF44336); // Red
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Heat Map for Monthly Compliance Submission/Failure Rates by District",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('District')),
                  ...months.map((m) => DataColumn(label: Text(m))).toList(),
                ],
                rows: List<DataRow>.generate(
                  districts.length,
                  (i) => DataRow(
                    cells: [
                      DataCell(Text(districts[i])),
                      ...List<DataCell>.generate(
                        months.length,
                        (j) => DataCell(
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: getCellColor(complianceRates[i][j]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              complianceRates[i][j].toInt().toString(),
                              style: const TextStyle(fontSize: 10, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Legends
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Text("Legends:", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            _legendBox(const Color(0xFF4CAF50)),
            const SizedBox(width: 2),
            _legendBox(const Color(0xFF8BC34A)),
            const SizedBox(width: 2),
            _legendBox(const Color(0xFFFFEB3B)),
            const SizedBox(width: 2),
            _legendBox(const Color(0xFFFFA726)),
            const SizedBox(width: 2),
            _legendBox(const Color(0xFFF44336)),
            const SizedBox(width: 10),
            const Text("90-100%", style: TextStyle(fontSize: 12)),
            const SizedBox(width: 18),
            const Text("80-89%", style: TextStyle(fontSize: 12)),
            const SizedBox(width: 18),
            const Text("70-79%", style: TextStyle(fontSize: 12)),
            const SizedBox(width: 18),
            const Text("60-69%", style: TextStyle(fontSize: 12)),
            const SizedBox(width: 18),
            const Text("< 60%", style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 28,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black12),
      ),
    );
  }

  Widget _buildDistrictStationCounts() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('station_owners').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Expanded(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Expanded(
            child: Center(child: Text('Error loading station owners: ${snapshot.error}')),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        // Count per districtName
        final Map<String, int> districtCounts = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final district = (data['districtName'] ?? '').toString();
          if (district.isEmpty) continue;
          districtCounts[district] = (districtCounts[district] ?? 0) + 1;
        }
        // Sort districts alphabetically
        final sortedDistricts = districtCounts.keys.toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Number of Water Refilling Station per District",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: sortedDistricts.map((district) {
                  return _buildDistrictStationCount(district, districtCounts[district] ?? 0);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatisticCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictStationCount(String district, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(district, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(count.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredStationsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE3F2FD),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_drink, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    "Water Refilling Stations",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blueAccent),
                    onPressed: () {
                      setState(() {
                        _showSettingsPage = true;
                        _showNotificationsPage = false;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.blueAccent),
                        onPressed: () {
                          setState(() {
                            _showNotificationsPage = true;
                            _showSettingsPage = false;
                          });
                        },
                      ),
                      Positioned(
                        right: 8,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 5,
                            minHeight: 2,
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Map Section with shadow and rounded corners
        Container(
          height: 280,
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.07),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('station_owners').get(),
              builder: (context, snapshot) {
                final center = _mapSelectedLocation ?? LatLng(10.7202, 122.5621);
                List<Marker> markers = [];
                if (snapshot.hasData) {
                  final docs = snapshot.data!.docs;
                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    double? lat, lng;
                    if (data['geopoint'] != null) {
                      final geo = data['geopoint'];
                      lat = geo.latitude?.toDouble();
                      lng = geo.longitude?.toDouble();
                    } else if (data['location'] != null && data['location'] is Map) {
                      lat = (data['location']['latitude'] as num?)?.toDouble();
                      lng = (data['location']['longitude'] as num?)?.toDouble();
                    } else {
                      lat = (data['latitude'] as num?)?.toDouble();
                      lng = (data['longitude'] as num?)?.toDouble();
                    }
                    final stationName = data['stationName'] ?? '';
                    if (lat != null && lng != null) {
                      markers.add(
                        Marker(
                          width: 44,
                          height: 44,
                          point: LatLng(lat, lng),
                          child: Tooltip(
                            message: stationName,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.15),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.location_on, color: Colors.blueAccent, size: 32),
                            ),
                          ),
                        ),
                      );
                    }
                  }
                }
                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _mapSelectedLocation != null ? 16.0 : 12.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                );
              },
            ),
          ),
        ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: "Search Water Stations...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.blue[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
        ),
        // Card-based Station List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('station_owners').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading station owners: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No station owners found.'));
                }
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                  final ownerName = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                  final district = (data['district'] ?? '').toString().toLowerCase();
                  return _searchQuery.isEmpty ||
                      stationName.contains(_searchQuery) ||
                      ownerName.contains(_searchQuery) ||
                      district.contains(_searchQuery);
                }).toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, idx) {
                    final data = filteredDocs[idx].data() as Map<String, dynamic>;
                    final stationName = data['stationName'] ?? '';
                    final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                    final district = data['districtName'] ?? '';
                    final address = data['address'] ?? '';
                    double? lat, lng;
                    if (data['geopoint'] != null) {
                      final geo = data['geopoint'];
                      lat = geo.latitude?.toDouble();
                      lng = geo.longitude?.toDouble();
                    } else if (data['location'] != null && data['location'] is Map) {
                      lat = (data['location']['latitude'] as num?)?.toDouble();
                      lng = (data['location']['longitude'] as num?)?.toDouble();
                    } else {
                      lat = (data['latitude'] as num?)?.toDouble();
                      lng = (data['longitude'] as num?)?.toDouble();
                    }
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.blue[50],
                              child: Icon(Icons.local_drink, color: Colors.blueAccent, size: 28),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    stationName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text("Owner: $ownerName", style: const TextStyle(fontSize: 13)),
                                  Text("District: $district", style: const TextStyle(fontSize: 13)),
                                  Text("Address: $address", style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.location_on, color: Colors.blueAccent),
                                  tooltip: "View on Map",
                                  onPressed: () {
                                    if (lat != null && lng != null) {
                                      setState(() {
                                        _mapSelectedLocation = LatLng(lat as double, lng as double);
                                      });
                                      _mapController.move(LatLng(lat, lng), 16.0);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.description, color: Colors.blueAccent),
                                  tooltip: "View Compliance Report",
                                  onPressed: () {
                                    // Handle compliance report view
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictManagementPage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE3F2FD),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Districts",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blueAccent),
                    onPressed: () {
                      setState(() {
                        _showSettingsPage = true;
                        _showNotificationsPage = false;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.blueAccent),
                        onPressed: () {
                          setState(() {
                            _showNotificationsPage = true;
                            _showSettingsPage = false;
                          });
                        },
                      ),
                      Positioned(
                        right: 8,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 5,
                            minHeight: 2,
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Container(
              width: 950,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FAFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "District Association President",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Fetch districts from Firestore
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('districts').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Error loading districts'));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(child: Text('No districts found.'));
                        }
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, idx) {
                            final data = docs[idx].data() as Map<String, dynamic>;
                            final districtName = data['districtName'] ?? 'Unknown';
                            final customUID = data['customUID'] ?? null;
                            return _districtRow(districtName, customUID);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _districtRow(String districtName, String? customUID) {
    return FutureBuilder<DocumentSnapshot?>(
      future: (customUID != null && customUID.isNotEmpty)
          ? FirebaseFirestore.instance.collection('station_owners').doc(customUID).get()
          : Future.value(null),
      builder: (context, snapshot) {
        String ownerDisplay = "Not assigned";
        TextStyle ownerStyle = const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        );
        if (customUID != null && customUID.isNotEmpty && snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            final firstName = data['firstName'] ?? '';
            final lastName = data['lastName'] ?? '';
            ownerDisplay = (firstName.toString() + ' ' + lastName.toString()).trim();
            if (ownerDisplay.isEmpty) ownerDisplay = "Not assigned";
          }
        } else {
          ownerStyle = const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.normal,
          );
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFFB6D6F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        districtName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ownerDisplay,
                        style: ownerStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ownerDisplay == "Not assigned" ? Colors.grey : Colors.blue[900],
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 36,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    setState(() {
                      _selectedDistrictForOwners = districtName;
                    });
                    await showDialog(
                      context: context,
                      builder: (context) => StationOwnersDialog(districtName: districtName),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF4B7ACF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Icon(Icons.people, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompliancePage() {
    bool showComplianceReport = false;
    String complianceTitle = "";
    bool isLoading = false;
    Map<String, dynamic>? selectedStationData;
    String _complianceStatusFilter = 'approved'; // <-- Add this line

    return StatefulBuilder(
      builder: (context, setState) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (showComplianceReport && selectedStationData != null) {
          return Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFE3F2FD),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      complianceTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.blueAccent),
                      onPressed: () {
                        setState(() {
                          showComplianceReport = false;
                          selectedStationData = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildComplianceReportDetailsFromData(selectedStationData!), // <-- Use new details builder
              ),
            ],
          );
        }

        return Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFE3F2FD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Compliance",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  Row(
                    children: [
                      // Status Filter Dropdown
                      DropdownButton<String>(
                        value: _complianceStatusFilter,
                        items: const [
                          DropdownMenuItem(
                            value: 'approved',
                            child: Text('Approved'),
                          ),
                          DropdownMenuItem(
                            value: 'pending_approval',
                            child: Text('Pending Approval'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _complianceStatusFilter = value!;
                          });
                        },
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        dropdownColor: Colors.white,
                        underline: Container(
                          height: 2,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.blueAccent),
                        onPressed: () {
                          setState(() {
                            _showSettingsPage = true;
                            _showNotificationsPage = false;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Colors.blueAccent),
                            onPressed: () {
                              setState(() {
                                _showNotificationsPage = true;
                                _showSettingsPage = false;
                              });
                            },
                          ),
                          Positioned(
                            right: 8,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 5,
                                minHeight: 2,
                              ),
                              child: const Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Approved or Pending Stations List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('station_owners')
                      .where('status', isEqualTo: _complianceStatusFilter)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading stations: ${snapshot.error}'));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          _complianceStatusFilter == 'approved'
                              ? 'No approved stations found.'
                              : 'No pending approval stations found.',
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, idx) {
                        final data = docs[idx].data() as Map<String, dynamic>;
                        final stationName = data['stationName'] ?? '';
                        final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                        final district = data['districtName'] ?? '';
                        final address = data['address'] ?? '';
                        return ListTile(
                          leading: Icon(
                            _complianceStatusFilter == 'approved'
                                ? Icons.check_circle
                                : Icons.hourglass_top,
                            color: _complianceStatusFilter == 'approved'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text(stationName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$ownerName\n$district\n$address'),
                          isThreeLine: true,
                          trailing: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                isLoading = true;
                              });
                              Future.delayed(const Duration(milliseconds: 300), () {
                                setState(() {
                                  isLoading = false;
                                  showComplianceReport = true;
                                  complianceTitle = stationName;
                                  selectedStationData = data;
                                });
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _complianceStatusFilter == 'approved'
                                  ? Colors.green
                                  : Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              "View Details",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // New: Build compliance report details from Firestore data
  Widget _buildComplianceReportDetailsFromData(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Compliance Report Details",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['stationName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Owner's Name: ${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"),
                    Text("Location: ${data['address'] ?? ''}"),
                    Text("Contact Number: ${data['phone'] ?? ''}"),
                    Text("Email: ${data['email'] ?? ''}"),
                    Text("Date of Compliance: ${data['dateOfCompliance'] ?? ''}"),
                    Text("Status: ${data['status'] ?? ''}"),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Section (Checklist)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Checklist:",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    _buildChecklistItem("Bacteriological Test Result", data['bacteriologicalTestStatus'] ?? 'Approved'),
                    _buildChecklistItem("Physical-Chemical Test Result", data['physicalChemicalTestStatus'] ?? 'Approved'),
                    _buildChecklistItem("Business Permit", data['businessPermitStatus'] ?? 'Approved'),
                    _buildChecklistItem("DTI", data['dtiStatus'] ?? 'Approved'),
                    _buildChecklistItem("Sanitary Permit", data['sanitaryPermitStatus'] ?? 'Approved'),
                    _buildChecklistItem("Mayor's Permit", data['mayorsPermitStatus'] ?? 'Approved'),
                    _buildChecklistItem("Fire Safety Certificate", data['fireSafetyStatus'] ?? 'Approved'),
                    _buildChecklistItem("Other Documents", data['otherDocumentsStatus'] ?? 'Approved'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final TextEditingController nameController = TextEditingController(text: "Alison T. Goazon");
    final TextEditingController contactController = TextEditingController(text: "0963 218 6769");
    final TextEditingController emailController = TextEditingController(text: "email@gmail.com");

    return Center(
      child: Container(
        width: 800,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section
                Column(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.person, size: 70, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Change Profile Picture", style: TextStyle(fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                          onPressed: () {
                            // Handle profile picture change
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 40),
                // Profile Details Section
                Expanded(
                  child: Column(
                    children: [
                      _profileField(
                        label: "User Name:",
                        controller: nameController,
                      ),
                      const SizedBox(height: 24),
                      _profileField(
                        label: "Contact Number:",
                        controller: contactController,
                      ),
                      const SizedBox(height: 24),
                      _profileField(
                        label: "Email:",
                        controller: emailController,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: 250,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () {
                            // Handle save changes
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text("Save Changes", style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileField({required String label, required TextEditingController controller}) {
    return Row(
      children: [
        Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFB6D6F6),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                  onPressed: () {
                    // Optionally focus the field or handle edit
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Settings Page UI
  Widget _buildSettingsPage() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE3F2FD),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.blueAccent),
                onPressed: () {
                  setState(() {
                    _showSettingsPage = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text(
                "Settings",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              // Spacer to push any future widgets to the right
              Expanded(child: Container()),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Settings Options
        Expanded(
          child: Center(
            child: SizedBox(
              width: 600,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _settingsTile(Icons.settings, "General System Settings"),
                  const SizedBox(height: 18),
                  _settingsTile(Icons.person, "User Management Settings"),
                  const SizedBox(height: 18),
                  _settingsTile(Icons.error_outline, "Compliance Settings"),
                  const SizedBox(height: 18),
                  _settingsTile(Icons.local_drink, "Water Stations Settings"),
                  const SizedBox(height: 18),
                  _settingsTile(Icons.account_circle, "Account/Profile Settings"),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String label) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Icon(icon, size: 32, color: Colors.blueAccent),
          const SizedBox(width: 24),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
        ],
      ),
    );
  }

  // Notifications Page UI
  Widget _buildNotificationsPage() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE3F2FD),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.blueAccent),
                onPressed: () {
                  setState(() {
                    _showNotificationsPage = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text(
                "Notifications",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              Expanded(child: Container()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Notifications List
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  _notificationItem(
                    icon: Icons.check_circle,
                    iconColor: Colors.blueAccent,
                    title: "New Compliance Submission Pending Approval",
                    time: "Today | 10:30 AM",
                    description:
                        "A new compliance report has been submitted by [Water Station Name] ([Station ID]) in [District Name]. Please review and approve it in the Compliance Approvals section.",
                    trailing: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(60, 36),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text("New", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  _divider(),
                  _notificationItem(
                    icon: Icons.lock,
                    iconColor: Colors.blueAccent,
                    title: "Non-Compliant Station",
                    time: "02 April, 2025 | 11:20 PM",
                    description:
                        "Water Station Aquasure in Molo has been non-compliant for 20 days and requires immediate attention. Review the details in the Non-Compliant Stations list.",
                  ),
                  _divider(),
                  _notificationItem(
                    icon: Icons.check_circle,
                    iconColor: Colors.blueAccent,
                    title: "Compliance Report Generation Failed",
                    time: "02 April, 2025 | 11:20 PM",
                    description:
                        "The scheduled generation of the Aquasure compliance report at 12:25 AM on March 20, 2025 has failed. Please check the system logs for details.",
                  ),
                  _divider(),
                  _notificationItem(
                    icon: Icons.check_circle,
                    iconColor: Colors.blueAccent,
                    title: "Compliance Rules Updated",
                    time: "02 April, 2025 | 06:20 PM",
                    description:
                        "The system's compliance rules and regulations have been updated on March 11 2025 by Admin. Review the changes in the Compliance Settings.",
                  ),
                  _divider(),
                  _notificationItem(
                    icon: Icons.check_circle,
                    iconColor: Colors.blueAccent,
                    title: "New District User Registered",
                    time: "03 April, 2025 | 11:20 AM",
                    description:
                        "A new district administrator account for [District Name] has been registered by [User who initiated registration, if applicable]. You may need to verify their access.",
                  ),
                  _divider(),
                  _notificationItem(
                    icon: Icons.check_circle,
                    iconColor: Colors.blueAccent,
                    title: "Scheduled System Maintenance Tomorrow at 12:30P.M",
                    time: "03 April, 2025 | 11:20 AM",
                    description:
                        "This is a reminder that scheduled system maintenance will occur tomorrow, [Date], at [Time] PST ([Local Time in Iloilo City]). The system may be temporarily unavailable",
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    required String description,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[200],
            radius: 24,
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing,
                    ]
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(thickness: 1, color: Colors.black26),
    );
  }
}

class StationOwnersDialog extends StatefulWidget {
  final String districtName;
  const StationOwnersDialog({Key? key, required this.districtName}) : super(key: key);

  @override
  State<StationOwnersDialog> createState() => _StationOwnersDialogState();
}

class _StationOwnersDialogState extends State<StationOwnersDialog> {
  Map<String, dynamic>? _currentPresident;
  String? _currentPresidentDocId;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadCurrentPresident();
  }

  Future<void> _loadCurrentPresident() async {
    // Get the district doc with customUID
    final districtQuery = await FirebaseFirestore.instance
        .collection('districts')
        .where('districtName', isEqualTo: widget.districtName)
        .limit(1)
        .get();
    if (districtQuery.docs.isEmpty) {
      setState(() {
        _currentPresident = null;
        _currentPresidentDocId = null;
      });
      return;
    }
    final districtDoc = districtQuery.docs.first;
    final customUID = districtDoc['customUID'];
    if (customUID == null || customUID == '') {
      setState(() {
        _currentPresident = null;
        _currentPresidentDocId = null;
      });
      return;
    }
    // Get the station owner doc
    final ownerDoc = await FirebaseFirestore.instance
        .collection('station_owners')
        .doc(customUID)
        .get();
    if (!ownerDoc.exists) {
      setState(() {
        _currentPresident = null;
        _currentPresidentDocId = null;
      });
      return;
    }
    final data = ownerDoc.data();
    if (data == null) {
      setState(() {
        _currentPresident = null;
        _currentPresidentDocId = null;
      });
      return;
    }
    setState(() {
      _currentPresident = {
        'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
        'email': data['email'] ?? '',
        'stationName': data['stationName'] ?? '',
      };
      _currentPresidentDocId = ownerDoc.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: const Color(0xFFF4FAFF),
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with icon and title
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4B7ACF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Station Owners in ${widget.districtName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Show current president
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFB6D6F6)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _currentPresident == null
                        ? const Text(
                            "Current President: Not assigned",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Current President: ${(_currentPresident!['name'] as String).isNotEmpty ? _currentPresident!['name'] : 'N/a'}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                              if ((_currentPresident!['stationName'] as String).isNotEmpty)
                                Text(
                                  _currentPresident!['stationName'],
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                              if ((_currentPresident!['email'] as String).isNotEmpty)
                                Text(
                                  (_currentPresident!['email'] as String).isNotEmpty
                                      ? _currentPresident!['email']
                                      : 'N/a',
                                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                ),
                              // Add Remove President button
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.remove_circle, size: 18, color: Colors.white),
                                  label: const Text("Remove President", style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Remove District President'),
                                        content: const Text('Are you sure you want to remove the current District Association President?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      // Remove president in district
                                      final districtQuery = await FirebaseFirestore.instance
                                          .collection('districts')
                                          .where('districtName', isEqualTo: widget.districtName)
                                          .limit(1)
                                          .get();
                                      if (districtQuery.docs.isNotEmpty) {
                                        final districtDoc = districtQuery.docs.first;
                                        await districtDoc.reference.update({'customUID': ''});
                                      }
                                      // Remove president flag and role in users
                                      if (_currentPresidentDocId != null) {
                                        final userQuery = await FirebaseFirestore.instance
                                            .collection('users')
                                            .where('customUID', isEqualTo: _currentPresidentDocId)
                                            .limit(1)
                                            .get();
                                        if (userQuery.docs.isNotEmpty) {
                                          final userDoc = userQuery.docs.first;
                                          await userDoc.reference.update({
                                            'district_president': false,
                                            'role': 'owner', // <-- set role to user when removed
                                          });
                                        }
                                      }
                                      setState(() {
                                        _currentPresident = null;
                                        _currentPresidentDocId = null;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('District president removed.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search station owner...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('station_owners')
                      .where('districtName', isGreaterThanOrEqualTo: '') // fetch all, filter in Dart
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading station owners: ${snapshot.error}'));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    // Exclude current president and filter by search
                    final filteredDocs = docs.where((doc) {
                      if (_currentPresidentDocId != null && doc.id == _currentPresidentDocId) {
                        return false;
                      }
                      final data = doc.data() as Map<String, dynamic>;
                      final ownerDistrict = (data['districtName'] ?? '').toString().trim().toLowerCase();
                      final dialogDistrict = widget.districtName.trim().toLowerCase();
                      if (ownerDistrict != dialogDistrict) return false;
                      if (_searchQuery.isEmpty) return true;
                      final name = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                      final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                      final email = (data['email'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) ||
                          stationName.contains(_searchQuery) ||
                          email.contains(_searchQuery);
                    }).toList();
                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text('No station owners found.', style: TextStyle(color: Colors.black54)));
                    }
                    return Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final doc = filteredDocs[idx];
                          final data = doc.data() as Map<String, dynamic>;
                          final stationName = data['stationName'] ?? '';
                          final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                          final email = data['email'] ?? '';
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            color: Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFB6D6F6),
                                child: Text(
                                  ownerName.isNotEmpty ? ownerName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                stationName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ownerName, style: const TextStyle(fontSize: 13)),
                                  Text(email, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                ],
                              ),
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Change District President'),
                                    content: Text(
                                      'Are you sure you want to set "$ownerName" as the District Association President for "${widget.districtName}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  // Find the district docId
                                  final districtQuery = await FirebaseFirestore.instance
                                      .collection('districts')
                                      .where('districtName', isEqualTo: widget.districtName)
                                      .limit(1)
                                      .get();
                                  if (districtQuery.docs.isNotEmpty) {
                                    final districtDoc = districtQuery.docs.first;
                                    final prevCustomUID = districtDoc['customUID'];
                                    // Demote previous president if exists and is different from new one
                                    if (prevCustomUID != null && prevCustomUID != '' && prevCustomUID != doc.id) {
                                      final prevUserQuery = await FirebaseFirestore.instance
                                          .collection('users')
                                          .where('customUID', isEqualTo: prevCustomUID)
                                          .limit(1)
                                          .get();
                                      if (prevUserQuery.docs.isNotEmpty) {
                                        final prevUserDoc = prevUserQuery.docs.first;
                                        await prevUserDoc.reference.update({
                                          'district_president': false,
                                          'role': 'user',
                                        });
                                      }
                                    }
                                    await districtDoc.reference.update({
                                      'customUID': doc.id,
                                    });

                                    // Set district president in users collection
                                    final userQuery = await FirebaseFirestore.instance
                                        .collection('users')
                                        .where('customUID', isEqualTo: doc.id)
                                        .limit(1)
                                        .get();
                                    if (userQuery.docs.isNotEmpty) {
                                      final userDoc = userQuery.docs.first;
                                      await userDoc.reference.update({
                                        'districtName': widget.districtName,
                                        'district_president': true,
                                        'role': 'admin', // <-- set role to admin when assigned
                                      });
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('District president updated successfully.'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    Navigator.of(context).pop(); // Close dialog after update
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('District not found.'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 10, top: 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}