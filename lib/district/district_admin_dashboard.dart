// ignore_for_file: unused_element, unused_field, unused_local_variable, library_private_types_in_public_api
import 'package:flutter/material.dart';
// Make sure this import path is correct and points to the file where RoleSelectionScreen is defined.
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waterstation_admin/district/compliance_page.dart'; // Add this import
import 'package:waterstation_admin/federated/registered_stations_page.dart';
import 'package:waterstation_admin/federated/change_password_dialog.dart';
import 'package:waterstation_admin/federated/logout_dialog.dart';
import 'package:waterstation_admin/services/firestore_repository.dart';

class DistrictAdminDashboard extends StatefulWidget {
  const DistrictAdminDashboard({super.key});

  @override
  _DistrictAdminDashboardState createState() => _DistrictAdminDashboardState();
}

class _DistrictAdminDashboardState extends State<DistrictAdminDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false; // collapse for wide screens
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Add a variable to hold districts data
  late Future<List<Map<String, dynamic>>> _districtsFuture;

  // Store the district of the current user
  String? _userDistrict;
  late Future<void> _userDistrictFuture;
  // Cached list of barangays for the current district (from station_owners)
  List<Map<String, String>> _barangays = [];
  bool _loadingBarangays = false;

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

  // Count station owners by a specific status within the current user's district
  Future<int> _countStationsByStatusInDistrict(String status) async {
    if (_userDistrict == null) return 0;
    final query = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('districtName', isEqualTo: _userDistrict)
        .where('status', isEqualTo: status)
        .get();
    return query.size;
  }

  // Count station owners with any of the provided statuses within the user's district
  Future<int> _countStationsByStatusesInDistrict(List<String> statuses) async {
    if (_userDistrict == null) return 0;
    if (statuses.isEmpty) return 0;
    int total = 0;
    for (final s in statuses) {
      final q = await FirebaseFirestore.instance
          .collection('station_owners')
          .where('districtName', isEqualTo: _userDistrict)
          .where('status', isEqualTo: s)
          .get();
      total += q.size;
    }
    return total;
  }

  // Count total station owners within the user's district
  Future<int> _countTotalStationsInDistrict() async {
    if (_userDistrict == null) return 0;
    final q = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('districtName', isEqualTo: _userDistrict)
        .get();
    return q.size;
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
      // once we know the user's district, load barangays for that district
      if (_userDistrict != null && _userDistrict!.isNotEmpty) {
        _fetchBarangaysForDistrict();
      }
    }
  }

  /// Load distinct barangays for the current district by scanning station_owners
  Future<void> _fetchBarangaysForDistrict() async {
    if (_userDistrict == null || _userDistrict!.isEmpty) return;
    setState(() {
      _loadingBarangays = true;
      _barangays = [];
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('station_owners')
          .where('districtName', isEqualTo: _userDistrict)
          .get();

      // Map key => {name, count}
      final Map<String, Map<String, dynamic>> counts = {};
      for (final d in snap.docs) {
        final data = d.data();
        String id = '';
        if (data.containsKey('barangayID')) id = (data['barangayID'] ?? '').toString();
        if (id.isEmpty && data.containsKey('barangayId')) id = (data['barangayId'] ?? '').toString();
        final name = (data['barangayName'] ?? data['barangay'] ?? '').toString();

        final key = id.isNotEmpty ? id : (name.isNotEmpty ? name : d.id);
        if (!counts.containsKey(key)) counts[key] = {'id': id.isNotEmpty ? id : key, 'name': name.isNotEmpty ? name : key, 'count': 0};
        counts[key]!['count'] = (counts[key]!['count'] as int) + 1;
      }

      final list = counts.values.map((e) => {'id': e['id'].toString(), 'name': e['name'].toString(), 'count': (e['count'] as int)}).toList();
      list.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
      if (mounted) setState(() {
        // cast to List<Map<String, String>> while keeping count as string inside map
        _barangays = list.map((m) => {'id': m['id'].toString(), 'name': m['name'].toString(), 'count': m['count'].toString()}).toList();
      });
    } catch (err) {
      debugPrint('Failed loading barangays for district $_userDistrict: $err');
    } finally {
      if (mounted) setState(() => _loadingBarangays = false);
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
                    // --- Top Header Bar ---
                    Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          const SizedBox(width: 8),
                          // Logo and tagline (optional, add if needed)
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
                      child: _getSelectedPage(),
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

  // Build sidebar content so it can be used inside Drawer or as permanent sidebar
  Widget _buildSidebarContent({required bool collapsed, bool forDrawer = false}) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? "Admin Panel";
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
                  FutureBuilder<Map<String, dynamic>?>(
                    future: (() async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return null;

                      // Prefer exact match by userId
                      final byId = await FirebaseFirestore.instance
                          .collection('station_owners')
                          .where('userId', isEqualTo: user.uid)
                          .limit(1)
                          .get();
                      if (byId.docs.isNotEmpty) return byId.docs.first.data() as Map<String, dynamic>?;

                      // Fallback: try matching by email if available
                      if (user.email != null && user.email!.isNotEmpty) {
                        final byEmail = await FirebaseFirestore.instance
                            .collection('station_owners')
                            .where('email', isEqualTo: user.email)
                            .limit(1)
                            .get();
                        if (byEmail.docs.isNotEmpty) return byEmail.docs.first.data() as Map<String, dynamic>?;
                      }

                      // No matching station_owner for logged-in user
                      return null;
                    })(),
                    builder: (context, snap) {
                      final user = FirebaseAuth.instance.currentUser;
                      String displayName = 'District Admin';
                      String contactText = userEmail;
                      if (snap.hasData && snap.data != null) {
                        final data = snap.data!;
                        final fname = data['firstName']?.toString();
                        final phone = data['phone']?.toString();
                        if (fname != null && fname.isNotEmpty) displayName = fname;
                        if (phone != null && phone.isNotEmpty) contactText = phone;
                      } else if (user?.displayName != null && user!.displayName!.isNotEmpty) {
                        displayName = user.displayName!;
                      }
                      // Show: Name, then email, then "District President of <district>"
                      final districtLabel = _userDistrict ?? '';
                      final emailLine = FirebaseAuth.instance.currentUser?.email ?? userEmail;
                      return Column(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 20, color: Color(0xFF004687), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            emailLine,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF004687)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            districtLabel.isNotEmpty ? 'District President of $districtLabel' : 'District President',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF004687)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          // Navigation Items
          const Divider(color: Color(0xFF004687), thickness: 1, height: 10),
          // Use icon-only buttons when collapsed
          _sidebarNavTile("Dashboard", 0, collapsed),
          _sidebarNavTile("Water Stations", 1, collapsed),
          _sidebarNavTile("Compliance", 2, collapsed),
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
                  onPressed: () => setState(() => _selectedIndex = 3),
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
          onPressed: () => setState(() => _selectedIndex = index),
        ),
      );
    }
    return _sidebarNavItem(label, index);
  }

  // --- Sidebar navigation item builder ---
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
        onTap: () => setState(() => _selectedIndex = index),
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
        return _buildWaterStationsPage();
      // Recommendations page removed
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
      case 3:
        return _buildProfilePage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

      // Responsive dashboard overview copied from federated admin pattern
      Widget _buildDashboardOverview() {
        return LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          // compute current date/time strings
          final now = DateTime.now();
          const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          final dateStr = '${monthNames[now.month-1]} ${now.day}, ${now.year}';
          int hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
          final minute = now.minute.toString().padLeft(2, '0');
          final ampm = now.hour >= 12 ? 'PM' : 'AM';
          final timeStr = '$hour:$minute $ampm';

          final header = Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                const Icon(Icons.access_time, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  timeStr,
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
                  color: Colors.black.withAlpha((0.04 * 255).round()),
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
              // Desktop two-column layout
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: barangay lists (flex 2)
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            // Moved Compliance Overview to top-left per request
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
                                  // Compliance Rate Progress Bar (district-scoped)
                                  Row(
                                    children: [
                                      const Text("Compliance Rate:", style: TextStyle(fontSize: 13, color: Colors.black87)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FutureBuilder<List<int>>(
                                          future: Future.wait([
                                            _countTotalStationsInDistrict(),
                                            _countStationsByStatusInDistrict('approved')
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
                                                    backgroundColor: Colors.grey[300],
                                                    color: Colors.green,
                                                    minHeight: 8,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(pct, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FutureBuilder<int>(
                                          future: _countStationsByStatusesInDistrict([
                                            'pending_approval',
                                            'pending_approved',
                                            'district_approved',
                                            'District_Approved'
                                          ]),
                                          builder: (context, snap) {
                                            final val = snap.data?.toString() ?? '-';
                                            return _BigComplianceStatBox(
                                              icon: Icons.hourglass_top,
                                              label: "Pending Approvals",
                                              value: val,
                                              color: Colors.orange,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: FutureBuilder<int>(
                                          future: _countTotalStationsInDistrict(),
                                          builder: (context, snap) {
                                            final val = snap.data?.toString() ?? '-';
                                            return _BigComplianceStatBox(
                                              icon: Icons.check_circle,
                                              label: "Total Stations",
                                              value: val,
                                              color: Colors.blueAccent,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FutureBuilder<int>(
                                          future: _countStationsByStatusInDistrict('approved'),
                                          builder: (context, snap) {
                                            final val = snap.data?.toString() ?? '-';
                                            return _BigComplianceStatBox(
                                              icon: Icons.verified,
                                              label: "Compliant Stations",
                                              value: val,
                                              color: Colors.green,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: FutureBuilder<int>(
                                          future: Future.wait([
                                            _countTotalStationsInDistrict(),
                                            _countStationsByStatusInDistrict('approved'),
                                            _countStationsByStatusesInDistrict([
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
                                            return _BigComplianceStatBox(
                                              icon: Icons.warning,
                                              label: "Non-Compliant Stations",
                                              value: val,
                                              color: Colors.redAccent,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                // Top 3 Highest-count barangays (data-driven)
                                Expanded(
                                  child: Container(
                                    height: 200,
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
                                        const Text(
                                          "Top 3 Barangays (Most WRS)",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1976D2)),
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: _loadingBarangays
                                              ? const Center(child: CircularProgressIndicator())
                                              : (_barangays.isEmpty
                                                  ? const Text('No barangay data')
                                                  : Builder(builder: (context) {
                                                      final items = List<Map<String, String>>.from(_barangays);
                                                      items.sort((a, b) => (int.tryParse(b['count'] ?? '0') ?? 0).compareTo(int.tryParse(a['count'] ?? '0') ?? 0));
                                                      final top3 = items.take(3).toList();
                                                      return Column(
                                                        children: top3.map((b) {
                                                          final name = b['name'] ?? '';
                                                          final cnt = int.tryParse(b['count'] ?? '0') ?? 0;
                                                          return Expanded(
                                                                child: Container(
                                                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFEAF5FF),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Expanded(
                                                                          child: Text(name, style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                                                      const SizedBox(width: 8),
                                                                      Container(
                                                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                                                        decoration: BoxDecoration(color: const Color(0xFF1976D2), borderRadius: BorderRadius.circular(20)),
                                                                        child: Text(cnt.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                        }).toList(),
                                                      );
                                                    })),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                // Bottom 6 Lowest-count barangays (data-driven)
                                Expanded(
                                  child: Container(
                                    height: 200,
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
                                        const Text(
                                          "6 Barangays (Lowest WRS)",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1976D2)),
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: _loadingBarangays
                                              ? const Center(child: CircularProgressIndicator())
                                              : (_barangays.isEmpty
                                                  ? const Text('No barangay data')
                                                  : Builder(builder: (context) {
                                                      final items = List<Map<String, String>>.from(_barangays);
                                                      items.sort((a, b) => (int.tryParse(a['count'] ?? '0') ?? 0).compareTo(int.tryParse(b['count'] ?? '0') ?? 0));
                                                      final bottom6 = items.take(6).toList();
                                                      return Column(
                                                        children: bottom6.map((b) {
                                                          final name = b['name'] ?? '';
                                                          final cnt = int.tryParse(b['count'] ?? '0') ?? 0;
                                                          return Expanded(
                                                            child: Container(
                                                              margin: const EdgeInsets.symmetric(vertical: 4),
                                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFF7F9FC),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                                                                  const SizedBox(width: 8),
                                                                  Text(cnt.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      );
                                                    })),
                                        ),
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
                      // Right: Stations summary and compliance (flex 1)
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
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _loadingBarangays
                                      ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                                          : (_barangays.isEmpty
                                          ? const Text('No barangay data')
                                          : SizedBox(
                                              height: 420,
                                              child: SingleChildScrollView(
                                                    child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: _barangays.map((b) {
                                                    final name = b['name'] ?? '';
                                                    final cnt = int.tryParse(b['count'] ?? '0') ?? 0;
                                                    final id = b['id'] ?? '';
                                                    return Container(
                                                      width: 110,
                                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEAF5FF),
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.03 * 255).round()), blurRadius: 6, offset: const Offset(0, 2))],
                                                      ),
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 2),
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(cnt.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Compliance summary (data-driven)
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
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Stacked single-column layout for narrow/mobile
            return Expanded(
              child: Container(
                color: const Color(0xFFF5F8FE),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Keep same greeting and widgets but stacked
                      const SizedBox(height: 8),
                      // Barangay lists stacked (mobile): dynamic top3 and bottom6
                      Container(
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
                            const Text(
                              "Top 3 Barangays (Most WRS)",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1976D2)),
                            ),
                            const SizedBox(height: 10),
                            _loadingBarangays
                                ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                                : (_barangays.isEmpty
                                    ? const Text('No barangay data')
                                    : Builder(builder: (context) {
                                        final items = List<Map<String, String>>.from(_barangays);
                                        items.sort((a, b) => (int.tryParse(b['count'] ?? '0') ?? 0).compareTo(int.tryParse(a['count'] ?? '0') ?? 0));
                                        final top3 = items.take(3).toList();
                                        return Column(
                                          children: top3.map((b) {
                                            final name = b['name'] ?? '';
                                            final cnt = int.tryParse(b['count'] ?? '0') ?? 0;
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(name),
                                              trailing: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                                decoration: BoxDecoration(color: const Color(0xFF1976D2), borderRadius: BorderRadius.circular(20)),
                                                child: Text(cnt.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      })),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
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
                            const Text(
                              "6 Barangays (Lowest WRS)",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1976D2)),
                            ),
                            const SizedBox(height: 10),
                            _loadingBarangays
                                ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                                : (_barangays.isEmpty
                                    ? const Text('No barangay data')
                                    : Builder(builder: (context) {
                                        final items = List<Map<String, String>>.from(_barangays);
                                        items.sort((a, b) => (int.tryParse(a['count'] ?? '0') ?? 0).compareTo(int.tryParse(b['count'] ?? '0') ?? 0));
                                        final bottom6 = items.take(6).toList();
                                        return Column(
                                          children: bottom6.map((b) {
                                            final name = b['name'] ?? '';
                                            final cnt = int.tryParse(b['count'] ?? '0') ?? 0;
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(name),
                                              trailing: Text(cnt.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                                            );
                                          }).toList(),
                                        );
                                      })),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Stations summary
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
                              ],
                            ),
                            const SizedBox(height: 10),
                            _loadingBarangays
                                ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                                : (_barangays.isEmpty
                                    ? const Text('No barangay data')
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _barangays.map((b) {
                                          final name = b['name'] ?? '';
                                          final cnt = int.tryParse(b['count'] ?? '0') ?? 0;
                                          return _StationCountBox(name, cnt);
                                        }).toList(),
                                      )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Compliance summary (stacked)
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
                            // Compliance tiles stacked for mobile
                            FutureBuilder<List<int>>(
                              future: Future.wait([
                                _countTotalStationsInDistrict(),
                                _countStationsByStatusInDistrict('approved')
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
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: rate,
                                            backgroundColor: Colors.grey[300],
                                            color: Colors.green,
                                            minHeight: 8,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(pct, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FutureBuilder<int>(
                                            future: _countStationsByStatusInDistrict('approved'),
                                            builder: (context, snap) {
                                              final val = snap.data?.toString() ?? '-';
                                              return _BigComplianceStatBox(
                                                icon: Icons.verified,
                                                label: "Compliant Stations",
                                                value: val,
                                                color: Colors.green,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FutureBuilder<int>(
                                            future: Future.wait([
                                              _countTotalStationsInDistrict(),
                                              _countStationsByStatusInDistrict('approved'),
                                              _countStationsByStatusesInDistrict([
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
                                              return _BigComplianceStatBox(
                                                icon: Icons.warning,
                                                label: "Non-Compliant Stations",
                                                value: val,
                                                color: Colors.redAccent,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildWaterStationsPage() {
    // Wait for user district to load before showing the stations page
    return FutureBuilder<void>(
      future: _userDistrictFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_userDistrict == null) {
          return const Center(child: Text('Could not determine your district.'));
        }
        // Delegate rendering to the shared RegisteredStationsPage used in federated admin.
        // NOTE: The stations list is already alphabetically sorted by stationName
        // and the DataTable stretches to available width inside RegisteredStationsPage.
        // (See modifications in registered_stations_page.dart for implementation.)
        return RegisteredStationsPage(
          mapSelectedLocation: _mapSelectedLocation,
          mapController: _mapController,
          searchController: _searchController,
          searchQuery: _searchQuery,
          registeredStationsCurrentPage: _currentPage,
          registeredStationsDistrictFilter: _userDistrict,
          showComplianceReportDetails: _showComplianceReportDetails,
          selectedComplianceStationData: _selectedComplianceStationData,
          selectedComplianceStationDocId: _selectedComplianceStationDocId,
          complianceReportTitle: _complianceReportTitle,
          setState: (fn) => setState(fn),
          onShowComplianceReportDetails: (show, data, docId, title) {
            setState(() {
              _showComplianceReportDetails = show;
              _selectedComplianceStationData = data;
              _selectedComplianceStationDocId = docId;
              _complianceReportTitle = title;
            });
          },
          onMapSelectedLocation: (loc) => setState(() => _mapSelectedLocation = loc),
          onSearchQueryChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
          onDistrictFilterChanged: (d) => setState(() => _userDistrict = d),
          onCurrentPageChanged: (p) => setState(() => _currentPage = p),
          isDistrictAdmin: true, // District admin should see district name, not filter dropdown
        );
      },
    );
  }

  /// Show a dialog listing station owners for the given barangay (id/name map)
  Future<void> _showBarangayStations(Map<String, String> barangay) async {
    if (_userDistrict == null) return;
    final id = barangay['id'] ?? '';
    final name = barangay['name'] ?? '';

    try {
      final List<QueryDocumentSnapshot> results = [];

      if (id.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('station_owners')
              .where('districtName', isEqualTo: _userDistrict)
              .where('barangayID', isEqualTo: id)
              .get();
          results.addAll(snap.docs);
        } catch (_) {}
      }

      // also try by barangayName (some docs don't have barangayID)
      if (name.isNotEmpty) {
        try {
          final snap2 = await FirebaseFirestore.instance
              .collection('station_owners')
              .where('districtName', isEqualTo: _userDistrict)
              .where('barangayName', isEqualTo: name)
              .get();
          results.addAll(snap2.docs);
        } catch (_) {}
      }

      // dedupe by id
      final Map<String, QueryDocumentSnapshot> keyed = {};
      for (final d in results) keyed[d.id] = d;
      final entries = keyed.values.toList();

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Stations in ${name.isNotEmpty ? name : 'Barangay'}'),
            content: SizedBox(
              width: 520,
              child: entries.isEmpty
                  ? const Text('No stations found for this barangay.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final data = entries[i].data() as Map<String, dynamic>;
                        final stationName = (data['stationName'] ?? data['station'] ?? 'Unknown').toString();
                        final owner = ((data['firstName'] ?? '') as String) + ' ' + ((data['lastName'] ?? '') as String);
                        final status = (data['status'] ?? '').toString();
                        return ListTile(
                          title: Text(stationName),
                          subtitle: Text(owner.trim().isEmpty ? (data['stationOwnerName'] ?? '') : owner),
                          trailing: Text(status.isNotEmpty ? status : 'n/a', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ],
          );
        },
      );
    } catch (err) {
      debugPrint('Error showing barangay stations: $err');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load stations')));
    }
  }

  // Profile Page for District Admin (federated design)
  Widget _buildProfilePage() {
    final user = FirebaseAuth.instance.currentUser;
    // If not signed in, show message
    if (user == null) return const Center(child: Text('Not signed in'));

    return FutureBuilder<Map<String, dynamic>?>(
      future: (() async {
        // Fetch user doc
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.exists ? userDoc.data() : null;

        // Find station_owner that belongs to the logged-in user.
        Map<String, dynamic>? stationData;
        // Prefer match by userId
        final byId = await FirebaseFirestore.instance
            .collection('station_owners')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (byId.docs.isNotEmpty) {
          stationData = byId.docs.first.data() as Map<String, dynamic>?;
        } else if (user.email != null && user.email!.isNotEmpty) {
          // Fallback to match by email
          final byEmail = await FirebaseFirestore.instance
              .collection('station_owners')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) stationData = byEmail.docs.first.data() as Map<String, dynamic>?;
        }

        return {
          'user': userData,
          'station': stationData,
        };
      })(),
      builder: (context, snapshot) {
        String adminName = "";
        String contact = "";
        String email = user.email ?? "";
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          final userData = data['user'] as Map<String, dynamic>?;
          final stationData = data['station'] as Map<String, dynamic>?;

          // Prefer station_owners values if available
          if (stationData != null) {
            adminName = stationData['firstName']?.toString() ?? "";
            contact = stationData['phone']?.toString() ?? "";
          }

          // Fallback to users collection values
          if (adminName.isEmpty && userData != null) {
            adminName = userData['admin_name']?.toString() ?? "";
          }
          if (contact.isEmpty && userData != null) {
            contact = userData['contact']?.toString() ?? "";
          }
        }

        final TextEditingController nameController = TextEditingController(text: adminName);
        final TextEditingController contactController = TextEditingController(text: contact);
        final TextEditingController emailController = TextEditingController(text: email);

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
                                enabled: false,
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
                                          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                            'admin_name': nameController.text.trim(),
                                            'contact': contactController.text.trim(),
                                          }, SetOptions(merge: true));
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
                                      builder: (context) => const ChangePasswordDialog(),
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

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LogoutDialog(),
    );
    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } catch (e) {
        debugPrint('Error signing out: $e');
      }
    }
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