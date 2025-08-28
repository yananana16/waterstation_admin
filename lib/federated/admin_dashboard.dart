import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, EmailAuthProvider, FirebaseAuthException;
import 'package:flutter/material.dart';
import 'district_management_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth_service.dart';
import '../login_screen.dart'; // <-- Add this import if RoleSelectionScreen is defined in this file
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'compliance_page.dart';
import 'change_password_dialog.dart'; // <-- Add this import
import 'compliance_files_viewer.dart'; // <-- Add this import

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
// <-- Add this line
  LatLng? _mapSelectedLocation;
  final MapController _mapController = MapController(); // <-- Add this line
  final TextEditingController _searchController = TextEditingController(); // <-- Add this line
  String _searchQuery = ""; // <-- Add this line

  // --- Pagination and filter state ---
  int _registeredStationsCurrentPage = 0;
  String? _registeredStationsDistrictFilter;

  // Add state for compliance report details navigation from Water Stations page
  bool _showComplianceReportDetails = false;
  Map<String, dynamic>? _selectedComplianceStationData;
  String? _selectedComplianceStationDocId;
  String _complianceReportTitle = "";

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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        child: SizedBox(
          width: 340, // Make dialog width shorter
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  child: const Icon(Icons.logout, color: Colors.blueAccent, size: 38),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Logout Confirmation",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Are you sure you want to logout?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("Logout"),
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("Cancel"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (shouldLogout == true) {
      await _authService.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
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
            decoration: BoxDecoration(
              color: const Color(0xFFD6E8FD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo, App Name, Tagline
                Container(
                  width: double.infinity,
                  color: const Color(0xFFD6E8FD), // Match sidebar background
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [

                    ],
                  ),
                ),
                // User Info
                Container(
                  width: double.infinity,
                  color: const Color(0xFFD6E8FD),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Color(0xFF004687)),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Admin",
                        style: TextStyle(fontSize: 20, color: Color(0xFF004687), fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        FirebaseAuth.instance.currentUser?.email ?? "user@gmail.com",
                        style: const TextStyle(fontSize: 13, color: Color(0xFF004687)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Navigation Items
                const Divider(color: Color(0xFF004687), thickness: 1, height: 10),
                _sidebarNavItem("Dashboard", 0),
                _sidebarNavItem("Water Stations", 1),
                _sidebarNavItem("District Presidents", 2),
                _sidebarNavItem("Compliance", 3),
                _sidebarNavItem("Profile", 4),
                const Spacer(),
                // Log out button
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: 160,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Color(0xFF004687)),
                      label: const Text("Log out", style: TextStyle(color: Color(0xFF004687))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        side: const BorderSide(color: Color(0xFFD6E8FD)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _logout(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // --- Top Bar: logo, tagline, icons ---
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E8FD), // <-- Match sidebar background
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 32),
                      // Logo and tagline

                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Color(0xFF1976D2), size: 28),
                        onPressed: () {
                          setState(() {
                            _showSettingsPage = true;
                            _showNotificationsPage = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Color(0xFF1976D2), size: 28),
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
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                // --- Main Page Content ---
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
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

  // Sidebar navigation item builder (matches image style)
  Widget _sidebarNavItem(String label, int index) {
    bool isSelected = _selectedIndex == index;
    IconData icon;
    switch (label) {
      case "Dashboard":
        icon = Icons.dashboard;
        break;
      case "Water Stations":
        icon = Icons.local_drink;
        break;
      case "District Presidents":
        icon = Icons.location_city;
        break;
      case "Compliance":
        icon = Icons.article;
        break;
      case "Profile":
        icon = Icons.person;
        break;
      default:
        icon = Icons.circle;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Color(0xFF004687) : Colors.blueGrey, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Color(0xFF004687) : Colors.blueGrey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
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
        return const CompliancePage();
      case 4:  // Profile page
        return _buildProfilePage(); // Changed from _buildUsersPage to _buildProfilePage
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildDashboardOverview() {
    return Column(
      children: [
        // Top header bar (date, time)
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                "Monday, May 5, 2025",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              const Icon(Icons.access_time, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                "11:25 AM PST",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        // Welcome message
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            "Hello, User!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
        ),
        // Main content row: Map and Compliance Overview
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // District map card
                Container(
                  width: 480, // Increased from 340
                  height: 520, // Increased from 370
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Map image (replace with your asset or widget)
                      Expanded(
                        child: Image.asset(
                          'assets/district_map.png', // <-- Use your colored district map asset here
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Legend
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Legend:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _legendDot(Colors.green),
                                const SizedBox(width: 8),
                                const Text("Good", style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 18),
                                _legendDot(Colors.orange),
                                const SizedBox(width: 8),
                                const Text("Moderate Concern", style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 18),
                                _legendDot(Colors.amber),
                                const SizedBox(width: 8),
                                const Text("High Concern", style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 18),
                                _legendDot(Colors.red),
                                const SizedBox(width: 8),
                                const Text("Critical", style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Compliance Overview card with summary cards on top
                Expanded(
                  child: Container(
                    height: 520, // Match map card height for alignment
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary cards row (moved here)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _SummaryCard(title: "Pending Compliance Approval", value: "45"),
                              const SizedBox(width: 24),
                              _SummaryCard(title: "Compliant Stations", value: "285"),
                              const SizedBox(width: 24),
                              _SummaryCard(title: "Non-Compliant Stations", value: "178"),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _complianceOverviewItem(
                            "Jaro 1 & 2 and City Proper 1 & 2",
                            "Good",
                            Colors.green,
                            "Maintain good practices. Continue regular testing and permit renewals.",
                          ),
                          _complianceOverviewItem(
                            "Mandurriao and La Paz",
                            "Moderate Concern",
                            Colors.orange,
                            "Some issues detected. Do spot checks, conduct refreshers, and monitor closely.",
                          ),
                          _complianceOverviewItem(
                            "Molo and Lapuz",
                            "High Concern",
                            Colors.amber,
                            "Several failures. Schedule inspections, send reminders, and assist WRS with compliance.",
                          ),
                          _complianceOverviewItem(
                            "Arevalo",
                            "Critical",
                            Colors.red,
                            "Urgent action needed. Deploy teams, provide support, and launch a full compliance drive.",
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
    );
  }

  Widget _complianceOverviewItem(String title, String status, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 2),
            child: Text(
              description,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredStationsPage() {
    // --- Remove local state, use class fields instead ---

    return StatefulBuilder(
      builder: (context, setState) {
        // --- Remove local state, use class fields instead ---
        const int rowsPerPage = 8;

        // Show compliance report details if requested
        if (_showComplianceReportDetails &&
            _selectedComplianceStationData != null &&
            _selectedComplianceStationDocId != null) {
          return Column(
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildComplianceReportDetailsFromData(_selectedComplianceStationData!),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ComplianceFilesViewer(
                              stationOwnerDocId: _selectedComplianceStationDocId!,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            // --- Replace search and filter UI ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Search pill (left)
                  SizedBox(
                    width: 800,
                    child: Container(
                      margin: const EdgeInsets.only(left: 220), // <-- Reduced left margin from 222 to 170
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: "Search",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Filter pill (right)
                  SizedBox(
                    width:700,
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('districts').get(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        final districts = docs.map((doc) => doc['districtName']?.toString() ?? '').where((d) => d.isNotEmpty).toList();
                        return Container(
                          margin: const EdgeInsets.only(right: 500), // <-- Added right margin to move filter left
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _registeredStationsDistrictFilter,
                                    hint: const Text("Filter"),
                                    isExpanded: true,
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text("Filter"),
                                      ),
                                      ...districts.map((district) => DropdownMenuItem<String>(
                                            value: district,
                                            child: Text(district),
                                          )),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _registeredStationsDistrictFilter = value;
                                        _registeredStationsCurrentPage = 0;
                                      });
                                    },
                                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                                    icon: const SizedBox.shrink(), // Remove default icon
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Icon(Icons.filter_alt, color: Colors.blue[800]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Table-based Station List
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
                    // --- Filter by selected district ---
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                      final ownerName = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                      final district = (data['districtName'] ?? '').toString().toLowerCase();
                      final matchesSearch = _searchQuery.isEmpty ||
                          stationName.contains(_searchQuery) ||
                          ownerName.contains(_searchQuery) ||
                          district.contains(_searchQuery);
                      final matchesDistrict = _registeredStationsDistrictFilter == null || _registeredStationsDistrictFilter!.isEmpty
                          ? true
                          : (data['districtName'] ?? '') == _registeredStationsDistrictFilter;
                      return matchesSearch && matchesDistrict;
                    }).toList();

                    // --- Pagination logic ---
                    final totalRows = filteredDocs.length;
                    final totalPages = (totalRows / rowsPerPage).ceil();
                    final startIdx = _registeredStationsCurrentPage * rowsPerPage;
                    final endIdx = (startIdx + rowsPerPage) > totalRows ? totalRows : (startIdx + rowsPerPage);
                    final pageDocs = filteredDocs.sublist(
                      startIdx < totalRows ? startIdx : 0,
                      endIdx < totalRows ? endIdx : totalRows,
                    );

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              width: 1200, // <-- Increase table container width for more space
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.blueGrey.shade100, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFD6E8FD)),
                                dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.blueAccent.withOpacity(0.08);
                                    }
                                    return Colors.white;
                                  },
                                ),
                                columnSpacing: 64, // <-- Increase column spacing for wider columns
                                horizontalMargin: 32, // <-- Increase horizontal margin for more padding
                                dividerThickness: 1.2,
                                columns: const [
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'Name of Station',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'Owner',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'District',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'Address',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'Actions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                rows: pageDocs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
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
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), // <-- More horizontal padding
                                          child: Text(
                                            stationName,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                          child: Text(ownerName, style: const TextStyle(fontSize: 14)),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                          child: Text(district, style: const TextStyle(fontSize: 14)),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                          width: 320, // <-- Make address column wider
                                          child: Text(
                                            address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
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
                                                setState(() {
                                                  _showComplianceReportDetails = true;
                                                  _selectedComplianceStationData = data;
                                                  _selectedComplianceStationDocId = doc.id;
                                                  _complianceReportTitle = stationName;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        // --- Pagination controls ---
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _registeredStationsCurrentPage > 0
                                    ? () => setState(() {
                                        _registeredStationsCurrentPage--;
                                      })
                                    : null,
                              ),
                              Text(
                                'Page ${totalPages == 0 ? 0 : (_registeredStationsCurrentPage + 1)} of $totalPages',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: (_registeredStationsCurrentPage < totalPages - 1)
                                    ? () => setState(() {
                                        _registeredStationsCurrentPage++;
                                      })
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // ...existing code...
          ],
        );
      },
    );
  }

  Widget _buildDistrictManagementPage() {
    return DistrictManagementPage(
      setState: setState,
      onHeaderAction: (showSettings, showNotifications) {
        setState(() {
          _showSettingsPage = showSettings;
          _showNotificationsPage = showNotifications;
        });
      },
    );
  }

  // New: Build compliance report details from Firestore data (copied from compliance_page.dart)
  Widget _buildComplianceReportDetailsFromData(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.blueAccent, size: 32),
                onPressed: () {
                  setState(() {
                    _showComplianceReportDetails = false;
                    _selectedComplianceStationData = null;
                    _selectedComplianceStationDocId = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text(
                "Compliance Report Details",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Station Name
          Text(
            data['stationName'] ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 16),
          // Details Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black54, width: 1),
              borderRadius: BorderRadius.circular(2),
              color: Colors.white,
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.black26, width: 1),
              ),
              children: [
                TableRow(
                  children: [
                    _detailCell(Icons.person, "Store Owner", "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim()),
                    _detailCell(Icons.home, "Address", data['address']),
                  ],
                ),
                TableRow(
                  children: [
                    _detailCell(Icons.email, "Email", data['email']),
                    _detailCell(Icons.calendar_today, "Date of Compliance", data['dateOfCompliance']),
                  ],
                ),
                TableRow(
                  children: [
                    _detailCell(Icons.phone, "Contact Number", data['phone']),
                    _detailCell(Icons.info, "Status", data['status']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCell(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value?.toString() ?? '',
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final user = FirebaseAuth.instance.currentUser;
    // Fetch admin_name and contact from Firestore (users collection)
    return FutureBuilder<DocumentSnapshot>(
      future: user != null
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
          // ignore: null_argument_to_non_null_type
          : Future.value(null),
      builder: (context, snapshot) {
        String adminName = "";
        String contact = "";
        String email = user?.email ?? "";
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          adminName = data['admin_name']?.toString() ?? "";
          contact = data['contact']?.toString() ?? "";
        }
        final TextEditingController nameController = TextEditingController(text: adminName);
        final TextEditingController contactController = TextEditingController(text: contact);
        final TextEditingController emailController = TextEditingController(text: email);

        // Track edit state
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
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
                                enabled: true,
                              ),
                              const SizedBox(height: 24),
                              _profileField(
                                label: "Contact Number:",
                                controller: contactController,
                                enabled: true,
                              ),
                              const SizedBox(height: 24),
                              _profileField(
                                label: "Email:",
                                controller: emailController,
                                enabled: false, // Disable email input
                              ),
                              const SizedBox(height: 40),
                              SizedBox(
                                width: 250,
                                height: 45,
                                child: ElevatedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          setState(() {
                                            isSaving = true;
                                          });
                                          if (user != null) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(user.uid)
                                                .update({
                                              'admin_name': nameController.text.trim(),
                                              'contact': contactController.text.trim(),
                                            });
                                          }
                                          setState(() {
                                            isSaving = false;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Profile updated successfully')),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text("Save Changes", style: TextStyle(fontSize: 16, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // --- Change Password Button ---
                              SizedBox(
                                width: 250,
                                height: 45,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.lock, color: Colors.blueAccent),
                                  label: const Text("Change Password", style: TextStyle(fontSize: 16, color: Colors.blueAccent)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.blueAccent),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => ChangePasswordDialog(), // <-- Use new class
                                    );
                                  },
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
          },
        );
      },
    );
  }

  Widget _profileField({required String label, required TextEditingController controller, bool enabled = true}) {
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
                    enabled: enabled,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                if (enabled)
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

// Summary card widget
// ignore: unused_element
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 130, // Increased height to prevent overflow
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Set box background to 0xFFE3F2FD
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8), // Reduced horizontal padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1976D2), // Text color blue
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              color: Color(0xFF1976D2), // Text color blue
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }
}

// Chart placeholder widget
// ignore: unused_element
class _ChartPlaceholder extends StatelessWidget {
  final String title;

  const _ChartPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1976D2)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.bar_chart, size: 60, color: Colors.blueAccent.withOpacity(0.4)),
            ),
          ),
        ),
      ],
    );
  }
}