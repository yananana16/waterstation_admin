import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, EmailAuthProvider, FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart'; // <-- Add this import if RoleSelectionScreen is defined in this file
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
                Text(
                  userEmail, // <-- Show actual user email here
                  style: const TextStyle(fontSize: 13, color: Colors.white),
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
        // District Station Counts
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth >= 800;
                return isDesktop
                    ? Row(
                        children: [
                          // District Station Counts
                          Expanded(
                            child: _buildDistrictStationCounts(),
                          ),
                        ],
                      )
                    : Column(
                        children: [
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
            // Center the card list and limit width
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
    // --- Remove local state, use class fields instead ---

    return StatefulBuilder(
      builder: (context, setState) {
        // --- Remove local state, use class fields instead ---
        const int _rowsPerPage = 6;

        // Show compliance report details if requested
        if (_showComplianceReportDetails &&
            _selectedComplianceStationData != null &&
            _selectedComplianceStationDocId != null) {
          return Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFE3F2FD),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.blueAccent),
                      onPressed: () {
                        setState(() {
                          _showComplianceReportDetails = false;
                          _selectedComplianceStationData = null;
                          _selectedComplianceStationDocId = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _complianceReportTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // --- Remove View Files button and display files beside details ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Details (left)
                      Expanded(
                        flex: 1,
                        child: _buildComplianceReportDetailsFromData(_selectedComplianceStationData!),
                      ),
                      const SizedBox(width: 24),
                      // Files (right)
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
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
            // --- Add district filter dropdown here ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('districts').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  if (snapshot.hasError) {
                    return const SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: Text('Error loading districts')));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final districts = docs.map((doc) => doc['districtName']?.toString() ?? '').where((d) => d.isNotEmpty).toList();
                  return Row(
                    children: [
                      const Text("Filter by District:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _registeredStationsDistrictFilter,
                        hint: const Text("All Districts"),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text("All Districts"),
                          ),
                          ...districts.map((district) => DropdownMenuItem<String>(
                                value: district,
                                child: Text(district),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _registeredStationsDistrictFilter = value;
                            _registeredStationsCurrentPage = 0; // Reset to first page on filter change
                          });
                        },
                      ),
                    ],
                  );
                },
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
                    final totalPages = (totalRows / _rowsPerPage).ceil();
                    final startIdx = _registeredStationsCurrentPage * _rowsPerPage;
                    final endIdx = (startIdx + _rowsPerPage) > totalRows ? totalRows : (startIdx + _rowsPerPage);
                    final pageDocs = filteredDocs.sublist(
                      startIdx < totalRows ? startIdx : 0,
                      endIdx < totalRows ? endIdx : totalRows,
                    );

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Station Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Owner', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('District', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                    DataCell(Text(stationName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(ownerName)),
                                    DataCell(Text(district)),
                                    DataCell(
                                      SizedBox(
                                        width: 220, // Set your desired max width here
                                        child: Text(
                                          address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Row(
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
                                    )),
                                  ],
                                );
                              }).toList(),
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
                    "District Association Presidents",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Table format for districts
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
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('District Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('President', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final districtName = data['districtName'] ?? 'Unknown';
                              final customUID = data['customUID'] ?? null;
                              return DataRow(
                                cells: [
                                  DataCell(Text(districtName)),
                                  DataCell(
                                    FutureBuilder<DocumentSnapshot?>(
                                      future: (customUID != null && customUID.isNotEmpty)
                                          ? FirebaseFirestore.instance.collection('station_owners').doc(customUID).get()
                                          : Future.value(null),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 80,
                                            height: 16,
                                            child: LinearProgressIndicator(minHeight: 2),
                                          );
                                        }
                                        String ownerDisplay = "Not assigned";
                                        if (customUID != null && customUID.isNotEmpty && snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                          final ownerData = snapshot.data!.data() as Map<String, dynamic>?;
                                          if (ownerData != null) {
                                            final firstName = ownerData['firstName'] ?? '';
                                            final lastName = ownerData['lastName'] ?? '';
                                            ownerDisplay = (firstName.toString() + ' ' + lastName.toString()).trim();
                                            if (ownerDisplay.isEmpty) ownerDisplay = "Not assigned";
                                          }
                                        }
                                        return Text(
                                          ownerDisplay,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: ownerDisplay == "Not assigned" ? Colors.grey : Colors.blue[900],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.people, size: 18),
                                      label: const Text("Owners", style: TextStyle(fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        textStyle: const TextStyle(fontSize: 13),
                                      ),
                                      onPressed: () async {
                                        setState(() {
                                        });
                                        await showDialog(
                                          context: context,
                                          builder: (context) => StationOwnersDialog(districtName: districtName),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ));
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

  Widget _buildCompliancePage() {
    bool showComplianceReport = false;
    String complianceTitle = "";
    bool isLoading = false;
    Map<String, dynamic>? selectedStationData;
    String _complianceStatusFilter = 'approved'; // Add this line
    String? selectedStationOwnerDocId; // Track docId for details

    // --- Add state for district filter ---
    String? _selectedDistrictFilter;

    // --- Pagination state ---
    int _complianceCurrentPage = 0;
    const int _complianceRowsPerPage = 6;

    return StatefulBuilder(
      builder: (context, setState) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (showComplianceReport && selectedStationData != null && selectedStationOwnerDocId != null) {
          return Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFE3F2FD),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Move back button to the left of the station name
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.blueAccent),
                      onPressed: () {
                        setState(() {
                          showComplianceReport = false;
                          selectedStationData = null;
                          selectedStationOwnerDocId = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      complianceTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // --- Remove View Files button and display files beside details ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Details (left)
                      Expanded(
                        flex: 1,
                        child: _buildComplianceReportDetailsFromData(selectedStationData!),
                      ),
                      const SizedBox(width: 24),
                      // Files (right)
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ComplianceFilesViewer(
                              stationOwnerDocId: selectedStationOwnerDocId!,
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
                      // --- Replace DropdownButton with 2 filter buttons ---
                      ToggleButtons(
                        isSelected: [
                          _complianceStatusFilter == 'approved',
                          _complianceStatusFilter == 'district_approved',
                        ],
                        onPressed: (int idx) {
                          setState(() {
                            if (idx == 0) {
                              _complianceStatusFilter = 'approved';
                            } else if (idx == 1) {
                              _complianceStatusFilter = 'district_approved';
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.blueAccent,
                        color: Colors.blueAccent,
                        constraints: const BoxConstraints(minWidth: 120, minHeight: 40),
                        children: const [
                          Text('Approved', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Pending Approval', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.blueAccent),
                        onPressed: () {
                          // Handle settings
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // --- Add district filter dropdown here ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('districts').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  if (snapshot.hasError) {
                    return const SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: Text('Error loading districts')));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final districts = docs.map((doc) => doc['districtName']?.toString() ?? '').where((d) => d.isNotEmpty).toList();
                  return Row(
                    children: [
                      const Text("Filter by District:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedDistrictFilter,
                        hint: const Text("All Districts"),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text("All Districts"),
                          ),
                          ...districts.map((district) => DropdownMenuItem<String>(
                                value: district,
                                child: Text(district),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrictFilter = value;
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // --- Table-based Station List ---
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
                    // --- Filter by selected district ---
                    final filteredDocs = _selectedDistrictFilter == null || _selectedDistrictFilter!.isEmpty
                        ? docs
                        : docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final district = (data['districtName'] ?? '').toString();
                            return district == _selectedDistrictFilter;
                          }).toList();

                    // --- Pagination logic ---
                    final totalRows = filteredDocs.length;
                    final totalPages = (totalRows / _complianceRowsPerPage).ceil();
                    final startIdx = _complianceCurrentPage * _complianceRowsPerPage;
                    final endIdx = (startIdx + _complianceRowsPerPage) > totalRows ? totalRows : (startIdx + _complianceRowsPerPage);
                    final pageDocs = filteredDocs.sublist(
                      startIdx < totalRows ? startIdx : 0,
                      endIdx < totalRows ? endIdx : totalRows,
                    );

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text(
                          _complianceStatusFilter == 'approved'
                              ? 'No approved stations found.'
                              : 'No pending approval stations found.',
                        ),
                      );
                    }
                    // --- Table format ---
                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Station Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Owner', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('District', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: pageDocs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final stationName = data['stationName'] ?? '';
                                final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                                final district = data['districtName'] ?? '';
                                final address = data['address'] ?? '';
                                final status = data['status'] ?? '';
                                final stationOwnerDocId = doc.id;
                                Color statusColor;
                                switch ((status ?? '').toString().toLowerCase()) {
                                  case 'approved':
                                    statusColor = Colors.green;
                                    break;
                                  case 'district_approved':
                                    statusColor = Colors.orange;
                                    break;
                                  default:
                                    statusColor = Colors.grey;
                                }
                                return DataRow(
                                  cells: [
                                    DataCell(Text(stationName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(ownerName)),
                                    DataCell(Text(district)),
                                    DataCell(
                                      SizedBox(
                                        width: 220, // Set your desired max width here
                                        child: Text(
                                          address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        (status ?? '').toString().toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    )),
                                    DataCell(
                                      ElevatedButton(
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
                                              selectedStationOwnerDocId = stationOwnerDocId;
                                            });
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: statusColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text(
                                          "View Details",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
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
                                onPressed: _complianceCurrentPage > 0
                                    ? () => setState(() {
                                        _complianceCurrentPage--;
                                      })
                                    : null,
                              ),
                              Text(
                                'Page ${totalPages == 0 ? 0 : (_complianceCurrentPage + 1)} of $totalPages',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: (_complianceCurrentPage < totalPages - 1)
                                    ? () => setState(() {
                                        _complianceCurrentPage++;
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
          ],
        );
      },
    );
  }

  // New: Build compliance report details from Firestore data
  Widget _buildComplianceReportDetailsFromData(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_turned_in, color: Colors.blueAccent, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    "Compliance Report Details",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['stationName'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Owner: ",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}",
                                style: const TextStyle(color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Address: ",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                data['address'] ?? '',
                                style: const TextStyle(color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Contact: ",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              data['phone'] ?? '',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.email, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Email: ",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                data['email'] ?? '',
                                style: const TextStyle(color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Date of Compliance: ",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              data['dateOfCompliance'] ?? '',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Status: ",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                              decoration: BoxDecoration(
                                color: (data['status'] == 'approved')
                                    ? Colors.green
                                    : (data['status'] == 'pending_approval')
                                        ? Colors.orange
                                        : Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (data['status'] ?? '').toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
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
                                      builder: (context) => _ChangePasswordDialog(),
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

// --- Compliance Files Viewer Widget ---
class ComplianceFilesViewer extends StatefulWidget {
  final String stationOwnerDocId;
  const ComplianceFilesViewer({super.key, required this.stationOwnerDocId});

  @override
  State<ComplianceFilesViewer> createState() => _ComplianceFilesViewerState();
}

class _ComplianceFilesViewerState extends State<ComplianceFilesViewer> {
  List<FileObject> uploadedFiles = [];
  bool isLoading = true;
  // ignore: unused_field
  final Set<int> _expandedIndexes = {};
  Map<String, dynamic> complianceStatuses = {};
  Map<String, String> statusEdits = {}; // Track dropdown edits

  @override
  void initState() {
    super.initState();
    fetchComplianceFiles(widget.stationOwnerDocId);
    fetchComplianceStatuses(widget.stationOwnerDocId);
  }

  Future<void> fetchComplianceFiles(String docId) async {
    try {
      final response = await Supabase.instance.client.storage
          .from('compliance_docs')
          .list(path: 'uploads/$docId');
      setState(() {
        uploadedFiles = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchComplianceStatuses(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(docId)
          .get();
      if (doc.exists) {
        setState(() {
          complianceStatuses = doc.data() ?? {};
        });
      }
    } catch (e) {
      // ignore error, just leave complianceStatuses empty
    }
  }

  Future<void> updateStatus(String statusKey, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(widget.stationOwnerDocId)
          .set({statusKey: newStatus}, SetOptions(merge: true));
      setState(() {
        complianceStatuses[statusKey] = newStatus;
        statusEdits.remove(statusKey);
      });

      // After updating, check if all statuses are "partially"
      final doc = await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(widget.stationOwnerDocId)
          .get();
      final data = doc.data() ?? {};
      // Get all status fields (ending with _status)
      final statusValues = data.entries
          .where((e) => e.key.endsWith('_status'))
          .map((e) => (e.value ?? '').toString().toLowerCase())
          .toList();
      if (statusValues.isNotEmpty &&
          statusValues.every((s) => s == 'passed')) {
        // Update station_owners status to "district_approved"
        await FirebaseFirestore.instance
            .collection('station_owners')
            .doc(widget.stationOwnerDocId)
            .update({'status': 'approved'});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All statuses are "partially". Station marked as approved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  /// Returns a tuple: (categoryKey, displayLabel)
  (String, String) _extractCategoryKeyAndLabel(String fileName, String docId) {
    final prefix = '${docId}_';
    if (fileName.startsWith(prefix)) {
      final rest = fileName.substring(prefix.length);
      final categoryKey = rest.split('.').first.toLowerCase();
      final displayLabel = categoryKey
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
          .join(' ');
      return (categoryKey, displayLabel);
    }
    return ('unknown', 'Unknown Category');
  }

  void _showFileDialog(FileObject file, String fileUrl, bool isImage, bool isPdf, bool isWord) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: 600,
            height: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: isImage
                        ? Image.network(
                            fileUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Failed to load image'),
                                ),
                          )
                        : isPdf
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 64),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open PDF'),
                                    onPressed: () async {
                                      if (await canLaunchUrl(Uri.parse(fileUrl))) {
                                        await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not open file')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              )
                            : isWord
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.description, color: Colors.blue, size: 64),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Open Document'),
                                        onPressed: () async {
                                          if (await canLaunchUrl(Uri.parse(fileUrl))) {
                                            await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Could not open file')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : const Text('Unsupported file type', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ));
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : uploadedFiles.isEmpty
              ? const Center(child: Text('No uploaded compliance files found.'))
              : ListView.builder(
                  itemCount: uploadedFiles.length,
                  itemBuilder: (context, index) {
                    final file = uploadedFiles[index];
                    final fileUrl = Supabase.instance.client.storage
                        .from('compliance_docs')
                        .getPublicUrl('uploads/${widget.stationOwnerDocId}/${file.name}');
                    final extension = file.name.split('.').last.toLowerCase();
                    final isImage = ['png', 'jpg', 'jpeg'].contains(extension);
                    final isPdf = extension == 'pdf';
                    final isWord = extension == 'doc' || extension == 'docx';
                    final (categoryKey, categoryLabel) = _extractCategoryKeyAndLabel(file.name, widget.stationOwnerDocId);

                    // Compose status key (e.g. business_permit_status)
                    final statusKey = '${categoryKey}_status';
                    final status = (statusEdits[statusKey] ?? complianceStatuses[statusKey] ?? 'Unknown').toString();

                    // Status color logic
                    Color statusColor;
                    switch (status.toLowerCase()) {
                      case 'pending':
                        statusColor = Colors.orange;
                        break;
                      case 'passed':
                        statusColor = Colors.green;
                        break;
                      case 'partially':
                        statusColor = Colors.teal.shade300;
                        break;
                      case 'failed':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  categoryLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal:  10),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                DropdownButton<String>(
                                                                  value: status.toLowerCase() == 'unknown' ? null : status,
                                                                  hint: const Text('Set Status'),
                                                                  items: [
                                                                    DropdownMenuItem(
                                                                      value: 'pending',
                                                                      child: Text('Pending'),
                                                                    ),
                                                                    DropdownMenuItem(
                                                                      value: 'passed',
                                                                      child: Text('Passed'),
                                                                    ),
                                                                    DropdownMenuItem(
                                                                      value: 'partially',
                                                                      child: Text('Partially'),
                                                                    ),
                                                                    DropdownMenuItem(
                                                                      value: 'failed',
                                                                      child: Text('Failed'),
                                                                    ),
                                                                  ],
                                                                  onChanged: (value) {
                                                                                                                                       setState(() {
                                                                      if (value != null) {
                                                                        statusEdits[statusKey] = value;
                                                                      }
                                                                    });
                                                                  },
                                                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                                                                  dropdownColor: Colors.white,
                                                                  underline: Container(
                                                                    height: 1,
                                                                    color: Colors.blueAccent,
                                                                  ),
                                                                ),
                                if (statusEdits.containsKey(statusKey))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final newStatus = statusEdits[statusKey]!;
                                        updateStatus(statusKey, newStatus);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Update', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              file.name,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                _showFileDialog(file, fileUrl, isImage, isPdf, isWord);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Colors.blue),
                                ),
                              ),
                              child: const Text('View File', style: TextStyle(color: Colors.blue)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// Checklist widget with file view buttons
class ComplianceChecklistWithFiles extends StatefulWidget {
  final String stationOwnerDocId;
  final Map<String, dynamic> data;
  const ComplianceChecklistWithFiles({required this.stationOwnerDocId, required this.data});

  @override
  State<ComplianceChecklistWithFiles> createState() => _ComplianceChecklistWithFilesState();
}

class _ComplianceChecklistWithFilesState extends State<ComplianceChecklistWithFiles> {
  List<FileObject> uploadedFiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchComplianceFiles(widget.stationOwnerDocId);
  }

  Future<void> fetchComplianceFiles(String docId) async {
    try {
      final response = await Supabase.instance.client.storage
          .from('compliance_docs')
          .list(path: 'uploads/$docId');
      setState(() {
        uploadedFiles = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper to find file for a given category key
  FileObject? _findFileForCategory(String categoryKey) {
    for (final file in uploadedFiles) {
      final prefix = '${widget.stationOwnerDocId}_';
      if (file.name.startsWith(prefix)) {
        final rest = file.name.substring(prefix.length);
        final fileCategory = rest.split('.').first.toLowerCase();
        if (fileCategory == categoryKey) return file;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // List of checklist items: label, statusKey, fileKey
    final checklist = [
      ("Bacteriological Test Result", "bacteriologicalTestStatus", "bacteriological_test_result"),
      ("Physical-Chemical Test Result", "physicalChemicalTestStatus", "physical_chemical_test_result"),
      ("Business Permit", "businessPermitStatus", "business_permit"),
      ("DTI", "dtiStatus", "dti"),
      ("Sanitary Permit", "sanitaryPermitStatus", "sanitary_permit"),
      ("Mayor's Permit", "mayorsPermitStatus", "mayors_permit"),
      ("Fire Safety Certificate", "fireSafetyStatus", "fire_safety_certificate"),
      ("Other Documents", "otherDocumentsStatus", "other_documents"),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Checklist:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        ...checklist.map((item) {
          final label = item.$1;
          final status = widget.data[item.$2] ?? 'Approved';
          final categoryKey = item.$3;
          final file = _findFileForCategory(categoryKey);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(label, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: status == 'Approved'
                              ? Colors.green
                              : (status == 'Pending' ? Colors.orange : Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                               if (file != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.remove_red_eye, size: 16),
                    label: const Text("View File", style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.blue),
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => SingleComplianceFileViewer(
                          stationOwnerDocId: widget.stationOwnerDocId,
                          file: file,
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// Viewer for a single compliance file
class SingleComplianceFileViewer extends StatelessWidget {
  final String stationOwnerDocId;
  final FileObject file;
  const SingleComplianceFileViewer({required this.stationOwnerDocId, required this.file});

  @override
  Widget build(BuildContext context) {
    final fileUrl = Supabase.instance.client.storage
        .from('compliance_docs')
        .getPublicUrl('uploads/$stationOwnerDocId/${file.name}');
    final extension = file.name.split('.').last.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg'].contains(extension);
    final isPdf = extension == 'pdf';
    final isWord = extension == 'doc' || extension == 'docx';

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            color: Colors.white,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  file.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                ),
                const SizedBox(height: 16),
                if (isImage)
                  Image.network(
                    fileUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Failed to load image'),
                        ),
                  )
                else if (isPdf || isWord)
                  Row(
                    children: [
                      Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.description,
                        color: isPdf ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPdf ? 'PDF Document' : 'Word Document',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.blue),
                        onPressed: () async {
                          if (await canLaunchUrl(Uri.parse(fileUrl))) {
                            await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open file')),
                            );
                          }
                        },
                      ),
                    ],
                  )
                else
                  const Text('Unsupported file type', style: TextStyle(color: Colors.red)),
              ],
            ),
          );
        },
      ),
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
                                          final userData = userDoc.data() as Map<String, dynamic>? ?? {};
                                          final isFederatedPresident = userData['federated_president'] == true;
                                          await userDoc.reference.update({
                                            'district_president': false,
                                            if (!isFederatedPresident) 'role': 'owner',
                                            // If federated_president is true, do not change role
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

// --- Change Password Dialog Widget ---
class _ChangePasswordDialog extends StatefulWidget {
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _changePassword() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = "User not logged in.";
          _isLoading = false;
        });
        return;
      }
      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassword.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
      // Update password
      await user.updatePassword(_newPassword.text.trim());
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message ?? "Failed to change password.";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Failed to change password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Change Password",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blueAccent),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _currentPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Current Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? "Enter current password" : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Enter new password";
                    if (val.length < 6) return "Password must be at least 6 characters";
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Confirm new password";
                    if (val != _newPassword.text) return "Passwords do not match";
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_formKey.currentState?.validate() ?? false) {
                                _changePassword();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Change Password", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}