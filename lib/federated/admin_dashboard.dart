// ignore_for_file: unused_import, unused_element, unused_field, unused_local_variable, library_private_types_in_public_api
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'district_management_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';
import '../login_screen.dart'; // <-- Add this import if RoleSelectionScreen is defined in this file
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'compliance_page.dart';
import 'change_password_dialog.dart'; // <-- Add this import
// <-- Add this import
import 'logout_dialog.dart'; // <-- Add this import
import 'registered_stations_page.dart'; // <-- Add this import
import 'recommendations_page.dart';

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
  bool _isSidebarCollapsed = false; // collapse for wide screens
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  // Add this map to hold district counts
  final Map<String, int> _districtCounts = {};

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
          if (!mounted) return;
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

  // Add this method to fetch counts from Firestore
  Future<Map<String, int>> _fetchDistrictCounts() async {
    final districts = [
      "La Paz", "Mandurriao", "Molo", "Lapuz", "Arevalo",
      "Jaro", "City Proper"
    ];
    Map<String, int> counts = {};
    for (final district in districts) {
      final query = await FirebaseFirestore.instance
          .collection('station_owners')
          .where('districtName', isEqualTo: district)
          .get();
      counts[district] = query.size;
    }
    return counts;
  }

  // Count station owners by a specific status (e.g., 'approved', 'failed')
  Future<int> _countStationsByStatus(String status) async {
    final query = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('status', isEqualTo: status)
        .get();
    return query.size;
  }

  // Count station owners with any of the provided statuses
  Future<int> _countStationsByStatuses(List<String> statuses) async {
    if (statuses.isEmpty) return 0;
    // Firestore doesn't support OR queries directly, so run multiple queries and sum.
    int total = 0;
    for (final s in statuses) {
      final q = await FirebaseFirestore.instance.collection('station_owners').where('status', isEqualTo: s).get();
      total += q.size;
    }
    return total;
  }

  // Count total station owners
  Future<int> _countTotalStations() async {
    final q = await FirebaseFirestore.instance.collection('station_owners').get();
    return q.size;
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
      builder: (context) => LogoutDialog(), // <-- Use new dialog widget
    );
    if (shouldLogout == true) {
      await _authService.signOut();
      if (!mounted) return;
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
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      // On narrow screens we provide a Drawer
      drawer: Drawer(
        child: SafeArea(child: _buildSidebarContent(collapsed: false, forDrawer: true)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900; // breakpoint
          final sidebarWidth = isWide ? (_isSidebarCollapsed ? 80.0 : 250.0) : 0.0;
          return Row(
            children: [
              if (isWide)
                // permanent sidebar on wide screens
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: sidebarWidth,
                  child: _buildSidebarContent(collapsed: _isSidebarCollapsed),
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
                            color: Colors.black.withAlpha((0.18 * 255).round()),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Menu or collapse button
                          if (!isWide)
                            IconButton(
                              icon: const Icon(Icons.menu, color: Color(0xFF1976D2)),
                              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                            ),
                          if (isWide)
                            IconButton(
                              icon: Icon(_isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left, color: const Color(0xFF1976D2)),
                              onPressed: () {
                                setState(() {
                                  _isSidebarCollapsed = !_isSidebarCollapsed;
                                });
                              },
                            ),
                          const SizedBox(width: 12),
                          // Logo and tagline area (keeps spacing)
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                          ),
                          const Spacer(),
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
          );
        },
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

  // Build sidebar content so it can be used inside Drawer or as permanent sidebar
  Widget _buildSidebarContent({required bool collapsed, bool forDrawer = false}) {
    // When collapsed show only icons and tooltips
    return Container(
      color: const Color(0xFFD6E8FD),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: const Color(0xFFD6E8FD),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: collapsed
                ? const SizedBox(height: 20)
                : Column(
                    children: [],
                  ),
          ),
          // User Info
          if (!collapsed)
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
          // Use icon-only buttons when collapsed
          _sidebarNavTile("Dashboard", 0, collapsed),
          _sidebarNavTile("Water Stations", 1, collapsed),
          _sidebarNavTile("District Presidents", 2, collapsed),
          _sidebarNavTile("Compliance", 3, collapsed),
          _sidebarNavTile("Recommendations", 5, collapsed),
          const Spacer(),
          if (!collapsed) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: 160,
                height: 42,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person, color: Color(0xFF004687)),
                  label: const Text("Profile", style: TextStyle(color: Color(0xFF004687))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    side: const BorderSide(color: Color(0xFFD6E8FD)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _onItemTapped(4),
                ),
              ),
            ),
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
        ],
      ),
    );
  }

  // helper to build each nav row respecting collapsed state
  Widget _sidebarNavTile(String label, int index, bool collapsed) {
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
    final isSelected = _selectedIndex == index;
    if (collapsed) {
      return Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, color: isSelected ? const Color(0xFF004687) : Colors.blueGrey),
          onPressed: () => _onItemTapped(index),
        ),
      );
    }
    return _sidebarNavItem(label, index);
  }

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return RegisteredStationsPage(
          mapSelectedLocation: _mapSelectedLocation,
          mapController: _mapController,
          searchController: _searchController,
          searchQuery: _searchQuery,
          registeredStationsCurrentPage: _registeredStationsCurrentPage,
          registeredStationsDistrictFilter: _registeredStationsDistrictFilter,
          showComplianceReportDetails: _showComplianceReportDetails,
          selectedComplianceStationData: _selectedComplianceStationData,
          selectedComplianceStationDocId: _selectedComplianceStationDocId,
          complianceReportTitle: _complianceReportTitle,
          setState: setState,
          onShowComplianceReportDetails: (show, data, docId, title) {
            setState(() {
              _showComplianceReportDetails = show;
              _selectedComplianceStationData = data;
              _selectedComplianceStationDocId = docId;
              _complianceReportTitle = title;
            });
          },
          onMapSelectedLocation: (location) {
            setState(() {
              _mapSelectedLocation = location;
            });
          },
          onSearchQueryChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
          onDistrictFilterChanged: (filter) {
            setState(() {
              _registeredStationsDistrictFilter = filter;
              _registeredStationsCurrentPage = 0;
            });
          },
          onCurrentPageChanged: (page) {
            setState(() {
              _registeredStationsCurrentPage = page;
            });
          },
        );
      case 2:
        return _buildDistrictManagementPage();
      case 3:
        return const CompliancePage();
      case 4:
        return _buildProfilePage();
      case 5:
        return RecommendationsPage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildDashboardOverview() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      // Common header and welcome widgets
      final header = Container(
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
      );

      final welcome = Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha((0.08 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          "Hello, User!",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
        ),
      );

      Widget buildMainContent(bool stackedForMobile) {
        if (!stackedForMobile) {
          // original two-column layout (desktop)
          return Expanded(
            child: Container(
              color: const Color(0xFFF5F8FE),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column: Chart and Top Barangays
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Compliance Overview (moved here)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withAlpha((0.08 * 255).round()),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.verified, color: Color(0xFF43A047), size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        "Compliance Overview",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1976D2)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Text("Compliance Rate:", style: TextStyle(fontSize: 15, color: Colors.black87)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FutureBuilder<List<int>>(
                                          future: Future.wait([
                                            _countTotalStations(),
                                            _countStationsByStatus('approved')
                                          ]),
                                          builder: (context, snap) {
                                            double rate = 0.0;
                                            String pct = '-';
                                            if (snap.hasData) {
                                              final total = snap.data![0];
                                              final approved = snap.data![1];
                                              rate = total > 0 ? (approved / total) : 0.0;
                                              pct = "${(rate * 100).toStringAsFixed(1)}%";
                                            }
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: LinearProgressIndicator(
                                                    value: rate,
                                                    minHeight: 8,
                                                    backgroundColor: Colors.grey[300],
                                                    color: const Color(0xFF43A047),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(pct, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF43A047))),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    height: 56,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: FutureBuilder<int>(
                                            future: _countStationsByStatuses([
                                              'pending_approval',
                                              'pending_approved',
                                              'district_approved',
                                              'District_Approved'
                                            ]),
                                            builder: (context, snap) {
                                              final val = snap.data?.toString() ?? '-';
                                              return _ComplianceStatTile(
                                                "Pending Approvals",
                                                val,
                                                color: const Color(0xFFFFECB3),
                                                textColor: const Color(0xFFF9A825),
                                                icon: Icons.hourglass_top,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FutureBuilder<int>(
                                            future: _countTotalStations(),
                                            builder: (context, snap) {
                                              final val = snap.data?.toString() ?? '-';
                                              return _ComplianceStatTile(
                                                "Total Stations",
                                                val,
                                                color: const Color(0xFFE3F2FD),
                                                textColor: const Color(0xFF1976D2),
                                                icon: Icons.check_circle,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 56,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: FutureBuilder<int>(
                                            future: _countStationsByStatus('approved'),
                                            builder: (context, snap) {
                                              final val = snap.data?.toString() ?? '-';
                                              return _ComplianceStatTile(
                                                "Compliant Stations",
                                                val,
                                                color: const Color(0xFFE8F5E9),
                                                textColor: const Color(0xFF43A047),
                                                icon: Icons.verified,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FutureBuilder<int>(
                                            future: Future.wait([
                                              _countTotalStations(),
                                              _countStationsByStatus('approved'),
                                              _countStationsByStatuses([
                                                'pending_approval',
                                                'pending_approved',
                                                'district_approved',
                                                'District_Approved'
                                              ])
                                            ]).then((results) {
                                              final total = results[0];
                                              final approved = results[1];
                                              final pending = results[2];
                                              final nonCompliant = total - approved - pending;
                                              return nonCompliant < 0 ? 0 : nonCompliant;
                                            }),
                                            builder: (context, snap) {
                                              final val = snap.data?.toString() ?? '-';
                                              return _ComplianceStatTile(
                                                "Non-Compliant Stations",
                                                val,
                                                color: const Color(0xFFFFEBEE),
                                                textColor: const Color(0xFFD32F2F),
                                                icon: Icons.warning,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Top Barangays row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    // Remove fixed height
                                    margin: const EdgeInsets.only(right: 18),
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withAlpha((0.08 * 255).round()),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: FutureBuilder<Map<String, int>>(
                                      future: _fetchDistrictCounts(),
                                      builder: (context, snapshot) {
                                        final counts = snapshot.data ?? {};
                                        // Sort districts by count ascending
                                        final sorted = counts.entries.toList()
                                          ..sort((a, b) => a.value.compareTo(b.value));
                                        final top3 = sorted.take(3).toList();
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "Top 3 Districts with Low Number of WRS",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD32F2F)),
                                            ),
                                            const SizedBox(height: 10),
                                            for (int i = 0; i < top3.length; i++)
                                              Text("${i + 1}. ${top3[i].key} (${top3[i].value})"),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Right column: Station count and Trends (moved here)
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Water Refilling Stations Iloilo City card
                            FutureBuilder<Map<String, int>>(
                              future: _fetchDistrictCounts(),
                              builder: (context, snapshot) {
                                final counts = snapshot.data ?? {};
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  margin: const EdgeInsets.only(bottom: 18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withAlpha((0.08 * 255).round()),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Water Refilling Stations\nIloilo City",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color(0xFF1976D2),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left column
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _DistrictStationTile("La Paz", "${counts["La Paz"] ?? "-"}"),
                                                const SizedBox(height: 8),
                                                _DistrictStationTile("Mandurriao", "${counts["Mandurriao"] ?? "-"}"),
                                                const SizedBox(height: 8),
                                                _DistrictStationTile("Molo", "${counts["Molo"] ?? "-"}"),
                                                const SizedBox(height: 8),
                                                _DistrictStationTile("Lapuz", "${counts["Lapuz"] ?? "-"}"),
                                                const SizedBox(height: 8),
                                                _DistrictStationTile("Arevalo", "${counts["Arevalo"] ?? "-"}"),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          // Right column
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _DistrictStationTile("Jaro", "${counts["Jaro"] ?? "-"}"),
                                                const SizedBox(height: 8),
                                                _DistrictStationTile("City Proper", "${counts["City Proper"] ?? "-"}"),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Trends card removed as requested
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Stacked single-column layout for narrow/mobile
        return Expanded(
          child: Container(
            color: const Color(0xFFF5F8FE),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Compliance Overview (moved here for mobile)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha((0.06 * 255).round()),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified, color: Color(0xFF43A047), size: 20),
                            const SizedBox(width: 8),
                            const Text("Compliance Overview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1976D2))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text("Compliance Rate:", style: TextStyle(fontSize: 14, color: Colors.black87)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FutureBuilder<List<int>>(
                                future: Future.wait([
                                  _countTotalStations(),
                                  _countStationsByStatus('approved')
                                ]),
                                builder: (context, snap) {
                                  double rate = 0.0;
                                  String pct = '-';
                                  if (snap.hasData) {
                                    final total = snap.data![0];
                                    final approved = snap.data![1];
                                    rate = total > 0 ? (approved / total) : 0.0;
                                    pct = "${(rate * 100).toStringAsFixed(1)}%";
                                  }
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: rate,
                                          minHeight: 8,
                                          backgroundColor: Colors.grey[300],
                                          color: const Color(0xFF43A047),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(pct, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF43A047))),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FutureBuilder<int>(
                                future: _countStationsByStatuses([
                                  'pending_approval',
                                  'pending_approved',
                                  'district_approved',
                                  'District_Approved'
                                ]),
                                builder: (context, snap) {
                                  final val = snap.data?.toString() ?? '-';
                                  return _ComplianceStatTile(
                                    "Pending Approvals",
                                    val,
                                    color: const Color(0xFFFFECB3),
                                    textColor: const Color(0xFFF9A825),
                                    icon: Icons.hourglass_top,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FutureBuilder<int>(
                                future: _countTotalStations(),
                                builder: (context, snap) {
                                  final val = snap.data?.toString() ?? '-';
                                  return _ComplianceStatTile(
                                    "Total Stations",
                                    val,
                                    color: const Color(0xFFE3F2FD),
                                    textColor: const Color(0xFF1976D2),
                                    icon: Icons.check_circle,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FutureBuilder<int>(
                                future: _countStationsByStatus('approved'),
                                builder: (context, snap) {
                                  final val = snap.data?.toString() ?? '-';
                                  return _ComplianceStatTile(
                                    "Compliant Stations",
                                    val,
                                    color: const Color(0xFFE8F5E9),
                                    textColor: const Color(0xFF43A047),
                                    icon: Icons.verified,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FutureBuilder<int>(
                                future: Future.wait([
                                  _countTotalStations(),
                                  _countStationsByStatus('approved'),
                                  _countStationsByStatuses([
                                    'pending_approval',
                                    'pending_approved',
                                    'district_approved',
                                    'District_Approved'
                                  ])
                                ]).then((results) {
                                  final total = results[0];
                                  final approved = results[1];
                                  final pending = results[2];
                                  final nonCompliant = total - approved - pending;
                                  return nonCompliant < 0 ? 0 : nonCompliant;
                                }),
                                builder: (context, snap) {
                                  final val = snap.data?.toString() ?? '-';
                                  return _ComplianceStatTile(
                                    "Non-Compliant Stations",
                                    val,
                                    color: const Color(0xFFFFEBEE),
                                    textColor: const Color(0xFFD32F2F),
                                    icon: Icons.warning,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // Top districts (stacked)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha((0.06 * 255).round()),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: FutureBuilder<Map<String, int>>(
                      future: _fetchDistrictCounts(),
                      builder: (context, snapshot) {
                        final counts = snapshot.data ?? {};
                        final sortedDesc = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                        final top3Desc = sortedDesc.take(3).toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Top Districts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1976D2))),
                            const SizedBox(height: 8),
                            for (int i = 0; i < top3Desc.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text("${i + 1}. ${top3Desc[i].key} (${top3Desc[i].value})"),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Station counts and compliance stacked
                  FutureBuilder<Map<String, int>>(
                    future: _fetchDistrictCounts(),
                    builder: (context, snapshot) {
                      final counts = snapshot.data ?? {};
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha((0.06 * 255).round()),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Water Refilling Stations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1976D2))),
                            const SizedBox(height: 12),
                            _DistrictStationTile("La Paz", "${counts["La Paz"] ?? "-"}"),
                            const SizedBox(height: 8),
                            _DistrictStationTile("Mandurriao", "${counts["Mandurriao"] ?? "-"}"),
                            const SizedBox(height: 8),
                            _DistrictStationTile("Molo", "${counts["Molo"] ?? "-"}"),
                            const SizedBox(height: 8),
                            _DistrictStationTile("Lapuz", "${counts["Lapuz"] ?? "-"}"),
                            const SizedBox(height: 8),
                            _DistrictStationTile("Arevalo", "${counts["Arevalo"] ?? "-"}"),
                            const SizedBox(height: 8),
                            _DistrictStationTile("Jaro", "${counts["Jaro"] ?? "-"}"),
                            const SizedBox(height: 8),
                            _DistrictStationTile("City Proper", "${counts["City Proper"] ?? "-"}"),
                          ],
                        ),
                      );
                    },
                  ),

                  // (removed duplicate mobile Compliance Overview)
                ],
              ),
            ),
          ),
        );
      }

      return Column(
        children: [
          header,
          welcome,
          buildMainContent(!isWide),
        ],
      );
    });
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

  Color _statusColor(String? status) {
    switch (status) {
      case "failed":
        return const Color(0xFFFF4C4C);
      case "pending_approval":
        return const Color(0xFFFFA500);
      case "district_approved":
        return const Color(0xFF20C997);
      case "approved":
        return const Color(0xFF28A745);
      default:
        return Colors.blueGrey;
    }
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
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blueAccent, size: 22),
                          const SizedBox(width: 8),
                          const Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['status']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                color: _statusColor(data['status']?.toString()),
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
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

// Station count tile widget
class _StationCountTile extends StatelessWidget {
  final String label;
  final String value;
  const _StationCountTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Remove fixed height, let grid control height
      decoration: BoxDecoration(
        color: Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), // Slightly less vertical padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
    );
  }
}

// Compliance stat tile widget
class _ComplianceStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;
  final IconData icon;
  const _ComplianceStatTile(this.label, this.value, {required this.color, required this.textColor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

// Add this widget below _StationCountTile
class _DistrictStationTile extends StatelessWidget {
  final String district;
  final String count;
  const _DistrictStationTile(this.district, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
              border: Border.all(color: Color(0xFF1976D2), width: 0.5),
            ),
            child: Text(
              district,
              style: const TextStyle(
                color: Color(0xFF004687),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
        Container(
          width: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Color(0xFF004687),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}
