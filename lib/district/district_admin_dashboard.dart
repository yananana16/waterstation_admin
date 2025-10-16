// ignore_for_file: unused_element, unused_field, unused_local_variable, library_private_types_in_public_api
import 'package:flutter/material.dart';
// Make sure this import path is correct and points to the file where RoleSelectionScreen is defined.
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waterstation_admin/login_screen.dart';
import 'package:waterstation_admin/district/district_compliance_files_viewer.dart';
import 'package:waterstation_admin/district/compliance_page.dart'; // Add this import
import 'package:waterstation_admin/district/recommendations_page.dart';
import 'package:waterstation_admin/services/firestore_repository.dart';

class DistrictAdminDashboard extends StatefulWidget {
  const DistrictAdminDashboard({super.key});

  @override
  _DistrictAdminDashboardState createState() => _DistrictAdminDashboardState();
}

class _DistrictAdminDashboardState extends State<DistrictAdminDashboard> {
  int _selectedIndex = 0;

  // Add a variable to hold districts data
  late Future<List<Map<String, dynamic>>> _districtsFuture;

  // Store the district of the current user
  String? _userDistrict;
  late Future<void> _userDistrictFuture;

  // Add state for compliance report details navigation from Water Stations page
  bool _showComplianceReportDetails = false;
  Map<String, dynamic>? _selectedComplianceStationData;
  String? _selectedComplianceStationDocId;
  String _complianceReportTitle = "";

  // Move these to class-level state
  LatLng? _mapSelectedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  int _currentPage = 0;
  static const int _rowsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _districtsFuture = _fetchDistricts();
    _userDistrictFuture = _fetchUserDistrict();
  }

  // Fetch districts from Firestore
  Future<List<Map<String, dynamic>>> _fetchDistricts() async {
    final snapshot = await FirestoreRepository.instance.getCollectionOnce(
      'districts',
      () => FirebaseFirestore.instance.collection('districts'),
    );
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<void> _fetchUserDistrict() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirestoreRepository.instance.getDocumentOnce(
        'users/${user.uid}',
        () => FirebaseFirestore.instance.collection('users').doc(user.uid),
      );
      if (!mounted) return;
      setState(() {
        _userDistrict = (doc.data() as Map<String, dynamic>?)?['districtName']?.toString();
      });
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
          // --- Sidebar copied from admin_dashboard.dart ---
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: const Color(0xFFD6E8FD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.10 * 255).round()),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo, App Name, Tagline (optional, can add if needed)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFD6E8FD),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      // ...add logo/tagline here if desired...
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
                        "District Admin",
                        style: TextStyle(fontSize: 20, color: Color(0xFF004687), fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        userEmail,
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
                _sidebarNavItem("Compliance", 2),
                _sidebarNavItem("Recommendations", 4),
                _sidebarNavItem("Profile", 3),
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
          // --- Main Content Area with Topbar ---
          Expanded(
            child: Column(
              children: [
                // --- Top Bar copied from admin_dashboard.dart ---
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E8FD),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.18 * 255).round()),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 32),
                      // Logo and tagline (optional, add if needed)
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ...add logo/tagline here if desired...
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Color(0xFF1976D2), size: 28),
                        onPressed: () {
                          // ...handle settings page...
                        },
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Color(0xFF1976D2), size: 28),
                            onPressed: () {
                              // ...handle notifications page...
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
                  child: _getSelectedPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Sidebar navigation item builder copied from admin_dashboard.dart ---
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
        onTap: () {
          if (label == "Log out") {
            _logout(context);
          } else {
            setState(() => _selectedIndex = index);
          }
        },
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
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.04 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  "Hello, User!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                ),
              ),
              const SizedBox(height: 24),
              // Main dashboard grid
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Trends chart and barangay lists
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Trends chart
                          Container(
                            width: double.infinity,
                            height: 220,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((0.04 * 255).round()),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "Trends in Water Refilling Station Openings",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                                    ),
                                    const Spacer(),
                                    const Text("2025", style: TextStyle(fontSize: 14, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.show_chart, size: 80, color: Colors.blueAccent.withAlpha((0.3 * 255).round())),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Barangay lists
                          Row(
                            children: [
                              // Top 3 High
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha((0.04 * 255).round()),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        "Top 3 Barangays with High Number of WRS (La Paz)",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1976D2)),
                                      ),
                                      SizedBox(height: 10),
                                      Text("1. Jereos"),
                                      Text("2. Luna"),
                                      Text("3. Magdalo"),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              // Top 6 Low
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha((0.04 * 255).round()),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        "Top 6 Barangays with Low Number of WRS (La Paz)",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent),
                                      ),
                                      SizedBox(height: 10),
                                      Text("1. Ingore"),
                                      Text("2. Railway"),
                                      Text("3. Tabuc Suba"),
                                      Text("4. Laguda"),
                                      Text("5. Buntud"),
                                      Text("6. Divinagracia"),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Right: Water Refilling Stations summary and Compliance summary
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Water Refilling Stations summary
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((0.04 * 255).round()),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Water Refilling Stations\n$_userDistrict",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1976D2)),
                                    ),
                                    const Spacer(),
                                    const Text("See More", style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StationCountBox("Magdalo", 24),
                                    _StationCountBox("Gustilo", 24),
                                    _StationCountBox("Molo", 17),
                                    _StationCountBox("Jereos", 30),
                                    _StationCountBox("Luna", 26),
                                    _StationCountBox("Nabitasan", 14),
                                    _StationCountBox("Ticad", 19),
                                    _StationCountBox("Calingin", 9),
                                    _StationCountBox("Baldoza", 9),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Compliance summary
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((0.04 * 255).round()),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.verified, color: Colors.green, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      "Compliance Overview",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1976D2)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Compliance Rate Progress Bar
                                Row(
                                  children: [
                                    const Text("Compliance Rate:", style: TextStyle(fontSize: 13, color: Colors.black87)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: 285 / (285 + 178), // compliant / total
                                        backgroundColor: Colors.grey[300],
                                        color: Colors.green,
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${((285 / (285 + 178)) * 100).toStringAsFixed(1)}%",
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Bigger status cards in a grid
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _BigComplianceStatBox(
                                        icon: Icons.hourglass_top,
                                        label: "Pending Approvals",
                                        value: "45",
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _BigComplianceStatBox(
                                        icon: Icons.check_circle,
                                        label: "Approved Today",
                                        value: "5",
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _BigComplianceStatBox(
                                        icon: Icons.verified,
                                        label: "Compliant Stations",
                                        value: "285",
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _BigComplianceStatBox(
                                        icon: Icons.warning,
                                        label: "Non-Compliant Stations",
                                        value: "178",
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 1:
        return _buildWaterStationsPage();
      case 4:
        return const RecommendationsPage();
      case 2:
        // Use the new CompliancePage widget
        return FutureBuilder<void>(
          future: _userDistrictFuture,
          builder: (context, userDistrictSnapshot) {
            if (userDistrictSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_userDistrict == null) {
              return const Center(child: Text('Could not determine your district.'));
            }
            return CompliancePage(userDistrict: _userDistrict!);
          },
        );
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildWaterStationsPage() {
    // Use class-level state for search/map/compliance details
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
          // Details and files side-by-side
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
                            color: Colors.black.withAlpha((0.15 * 255).round()),
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

    return FutureBuilder<void>(
      future: _userDistrictFuture,
      builder: (context, userDistrictSnapshot) {
        if (userDistrictSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_userDistrict == null) {
          return const Center(child: Text('Could not determine your district.'));
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _districtsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading districts'));
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
                      const Text(
                        "Water Refilling Stations",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings, color: Color(0xFF1976D2)),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 16),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications, color: Color(0xFF1976D2)),
                                onPressed: () {},
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
                // Map Section (OpenStreetMap)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  margin: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirestoreRepository.instance.getCollectionOnce(
                        'station_owners',
                        () => FirebaseFirestore.instance.collection('station_owners'),
                      ),
                      builder: (context, snapshot) {
                        final center = _mapSelectedLocation ?? LatLng(10.7202, 122.5621); // Iloilo City
                        List<Marker> markers = [];
                        if (snapshot.hasData) {
                          final docs = snapshot.data!.docs;
                          for (final doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            // Only show markers for the selected district
                            final districtName = (data['districtName'] ?? '').toString().toLowerCase();
                            final selectedDistrict = _userDistrict?.toLowerCase();
                            if (selectedDistrict != null && districtName != selectedDistrict) {
                              continue;
                            }
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
                                  width: 40,
                                  height: 40,
                                  point: LatLng(lat, lng),
                                  child: Tooltip(
                                    message: stationName,
                                    child: const Icon(Icons.location_on, color: Colors.blueAccent, size: 32),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                // Table-based Station List
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirestoreRepository.instance.getCollectionOnce(
                        'station_owners_approved_$_userDistrict',
                        () => FirebaseFirestore.instance
                            .collection('station_owners')
                            .where('status', isEqualTo: 'approved'),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error loading station owners: ${snapshot.error}'));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        // Filter by search query and district
                        final filteredDocs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                          final ownerName = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                          final district = (data['districtName'] ?? '').toString().toLowerCase();
                          final matchesSearch = _searchQuery.isEmpty ||
                              stationName.contains(_searchQuery) ||
                              ownerName.contains(_searchQuery) ||
                              district.contains(_searchQuery);
                          // Only show stations in the user's district
                          final matchesDistrict = data['districtName']?.toString().toLowerCase() == _userDistrict!.toLowerCase();
                          return matchesSearch && matchesDistrict;
                        }).toList();

                        // Pagination logic
                        final totalRows = filteredDocs.length;
                        final totalPages = (totalRows / _rowsPerPage).ceil();
                        final startIdx = _currentPage * _rowsPerPage;
                        final endIdx = (startIdx + _rowsPerPage) > totalRows ? totalRows : (startIdx + _rowsPerPage);
                        final pageDocs = filteredDocs.sublist(
                          startIdx < totalRows ? startIdx : 0,
                          endIdx < totalRows ? endIdx : totalRows,
                        );

                        if (filteredDocs.isEmpty) {
                          return const Center(child: Text('No station owners found.'));
                        }

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
                                            width: 250,
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
                                                // Show compliance details immediately on first click
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
                            // Pagination controls
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _currentPage > 0
                                        ? () => setState(() {
                                            _currentPage--;
                                          })
                                        : null,
                                  ),
                                  Text(
                                    'Page ${totalPages == 0 ? 0 : (_currentPage + 1)} of $totalPages',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: (_currentPage < totalPages - 1)
                                        ? () => setState(() {
                                            _currentPage++;
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
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }
}

// ...existing code...

// Sidebar button widget
class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Color(0xFF1976D2) : Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Color(0xFF1976D2) : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Summary card widget
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
            color: Colors.blueAccent.withAlpha((0.08 * 255).round()),
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
              color: Colors.blueAccent.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.bar_chart, size: 60, color: Colors.blueAccent.withAlpha((0.4 * 255).round())),
            ),
          ),
        ),
      ],
    );
  }
}

// Add helper widgets for dashboard boxes
class _StationCountBox extends StatelessWidget {
  final String name;
  final int count;
  const _StationCountBox(this.name, this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(name, style: TextStyle(fontSize: 13, color: Color(0xFF1976D2))),
          const SizedBox(height: 4),
          Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1976D2))),
        ],
      ),
    );
  }
}

class _ComplianceStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ComplianceStatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
  color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        ],
      ),
    );
  }
}

// Add a new bigger compliance stat box widget
class _BigComplianceStatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _BigComplianceStatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70, // Reduced height
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
  color: color.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(12), // Smaller border radius
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((0.08 * 255).round()),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, color: color, size: 26), // Smaller icon
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13, // Smaller font
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18, // Smaller value font
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}