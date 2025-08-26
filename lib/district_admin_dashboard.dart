import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _districtsFuture = _fetchDistricts();
    _userDistrictFuture = _fetchUserDistrict();
  }

  // Fetch districts from Firestore
  Future<List<Map<String, dynamic>>> _fetchDistricts() async {
    final snapshot = await FirebaseFirestore.instance.collection('districts').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _fetchUserDistrict() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _userDistrict = doc.data()?['districtName']?.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set dashboard background to white
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
                _buildSidebarItem(Icons.article, "Compliance", 2),
                const Spacer(),
                _buildSidebarItem(Icons.person, "Profile", 3),
                _buildSidebarItem(Icons.logout, "Logout", -1),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: _getSelectedPage(),
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
            setState(() => _selectedIndex = index);
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section (AppBar style, matching Water Stations/Compliance)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFE3F2FD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Dashboard",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
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
                  ),]
                ),
              ),
            
            // Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center the boxes
                children: [
                  Flexible(
                    child: _SummaryCard(
                      title: "Pending Compliance Approvals",
                      value: "45",
                    ),
                  ),
                  const SizedBox(width: 24),
                  Flexible(
                    child: _SummaryCard(
                      title: "Number of Compliant Station",
                      value: "285",
                    ),
                  ),
                  const SizedBox(width: 24),
                  Flexible(
                    child: _SummaryCard(
                      title: "Non-Compliant Stations",
                      value: "178",
                    ),
                  ),
                ],
              ),
            ),
            // Charts
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Sunday, 24 March 2024",
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                          const Spacer(),
                          Text(
                            "11:25 AM PHST",
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            // Placeholder for Annual Water Refilling Station Count chart
                            Expanded(
                              child: _ChartPlaceholder(
                                title: "Annual Water Refilling Station Count",
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Placeholder for Monthly Compliance chart
                            Expanded(
                              child: _ChartPlaceholder(
                                title: "Monthly Compliance",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case 1:
        return _buildWaterStationsPage();
      case 2:
        return _buildCompliancePage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildWaterStationsPage() {
    // Use controllers at the State level to persist search/map state
    final TextEditingController searchController = TextEditingController();
    String searchQuery = "";
    LatLng? mapSelectedLocation;
    final MapController mapController = MapController();

    // --- Pagination and filter state ---
    int currentPage = 0;
    const int rowsPerPage = 6;

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

    return FutureBuilder<void>(
      future: _userDistrictFuture,
      builder: (context, userDistrictSnapshot) {
        if (userDistrictSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_userDistrict == null) {
          return const Center(child: Text('Could not determine your district.'));
        }
        return StatefulBuilder(
          builder: (context, setState) {
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
                          future: FirebaseFirestore.instance.collection('station_owners').get(),
                          builder: (context, snapshot) {
                            final center = mapSelectedLocation ?? LatLng(10.7202, 122.5621); // Iloilo City
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
                              mapController: mapController,
                              options: MapOptions(
                                initialCenter: center,
                                initialZoom: mapSelectedLocation != null ? 16.0 : 12.0,
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
                        controller: searchController,
                        onChanged: (value) {
                          searchQuery = value.toLowerCase();
                          setState(() {});
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
                    // Table-based Station List (copied layout)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                        child: FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('station_owners')
                              .where('status', isEqualTo: 'approved')
                              .get(),
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
                              final matchesSearch = searchQuery.isEmpty ||
                                  stationName.contains(searchQuery) ||
                                  ownerName.contains(searchQuery) ||
                                  district.contains(searchQuery);
                              // Only show stations in the user's district
                              final matchesDistrict = data['districtName']?.toString().toLowerCase() == _userDistrict!.toLowerCase();
                              return matchesSearch && matchesDistrict;
                            }).toList();

                            // Pagination logic
                            final totalRows = filteredDocs.length;
                            final totalPages = (totalRows / rowsPerPage).ceil();
                            final startIdx = currentPage * rowsPerPage;
                            final endIdx = (startIdx + rowsPerPage) > totalRows ? totalRows : (startIdx + rowsPerPage);
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
                                                width: 250, // Set your desired max width here
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
                                                      mapSelectedLocation = LatLng(lat, lng);
                                                      mapController.move(LatLng(lat, lng), 16.0);
                                                      setState(() {});
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
                                // Pagination controls
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: currentPage > 0
                                            ? () => setState(() {
                                                currentPage--;
                                              })
                                            : null,
                                      ),
                                      Text(
                                        'Page ${totalPages == 0 ? 0 : (currentPage + 1)} of $totalPages',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: (currentPage < totalPages - 1)
                                            ? () => setState(() {
                                                currentPage++;
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
      },
    );
  }

  Widget _buildCompliancePage() {
    bool showComplianceReport = false;
    String complianceTitle = "";
    bool isLoading = false;
    Map<String, dynamic>? selectedStationData;
    String complianceStatusFilter = 'approved';
    String? selectedStationOwnerDocId;

    // --- Pagination state ---
    int complianceCurrentPage = 0;
    const int complianceRowsPerPage = 6;

    return FutureBuilder<void>(
      future: _userDistrictFuture,
      builder: (context, userDistrictSnapshot) {
        if (userDistrictSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_userDistrict == null) {
          return const Center(child: Text('Could not determine your district.'));
        }
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

            // Table-based compliance list with pagination
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
                          ToggleButtons(
                            isSelected: [
                              complianceStatusFilter == 'approved',
                              complianceStatusFilter == 'pending_approval',
                              complianceStatusFilter == 'district_approved',
                            ],
                            onPressed: (int idx) {
                              setState(() {
                                if (idx == 0) {
                                  complianceStatusFilter = 'approved';
                                } else if (idx == 1) {
                                  complianceStatusFilter = 'pending_approval';
                                } else if (idx == 2) {
                                  complianceStatusFilter = 'district_approved';
                                }
                                complianceCurrentPage = 0;
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
                              Text('District Approved', style: TextStyle(fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 16),
                // Table-based Station List
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('station_owners')
                          .where('status', isEqualTo: complianceStatusFilter)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error loading stations: ${snapshot.error}'));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        // Filter by user's district only
                        final filteredDocs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final districtName = (data['districtName'] ?? '').toString().toLowerCase();
                          final userDistrict = _userDistrict?.toLowerCase();
                          return userDistrict == null || districtName == userDistrict;
                        }).toList();

                        // Pagination logic
                        final totalRows = filteredDocs.length;
                        final totalPages = (totalRows / complianceRowsPerPage).ceil();
                        final startIdx = complianceCurrentPage * complianceRowsPerPage;
                        final endIdx = (startIdx + complianceRowsPerPage) > totalRows ? totalRows : (startIdx + complianceRowsPerPage);
                        final pageDocs = filteredDocs.sublist(
                          startIdx < totalRows ? startIdx : 0,
                          endIdx < totalRows ? endIdx : totalRows,
                        );

                        if (filteredDocs.isEmpty) {
                          return Center(
                            child: Text(
                              complianceStatusFilter == 'approved'
                                  ? 'No approved stations found.'
                                  : 'No pending approval stations found.',
                            ),
                          );
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
                                      case 'pending_approval':
                                        statusColor = Colors.teal;
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
                                            width: 180, // Set your desired max width here
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
                            // Pagination controls
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: complianceCurrentPage > 0
                                        ? () => setState(() {
                                            complianceCurrentPage--;
                                          })
                                        : null,
                                  ),
                                  Text(
                                    'Page ${totalPages == 0 ? 0 : (complianceCurrentPage + 1)} of $totalPages',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: (complianceCurrentPage < totalPages - 1)
                                        ? () => setState(() {
                                            complianceCurrentPage++;
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
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

// Sidebar button widget
// ignore: unused_element
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
          statusValues.every((s) => s == 'partially')) {
        // Update station_owners status to "district_approved"
        await FirebaseFirestore.instance
            .collection('station_owners')
            .doc(widget.stationOwnerDocId)
            .update({'status': 'district_approved'});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All statuses are "partially". Station marked as district_approved.')),
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

  Future<void> updateAllStatuses() async {
    if (statusEdits.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(widget.stationOwnerDocId)
          .set(statusEdits, SetOptions(merge: true));
      setState(() {
        for (final entry in statusEdits.entries) {
          complianceStatuses[entry.key] = entry.value;
        }
        statusEdits.clear();
      });

      // After updating, check if all statuses are "partially"
      final doc = await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(widget.stationOwnerDocId)
          .get();
      final data = doc.data() ?? {};
      final statusValues = data.entries
          .where((e) => e.key.endsWith('_status'))
          .map((e) => (e.value ?? '').toString().toLowerCase())
          .toList();
      if (statusValues.isNotEmpty &&
          statusValues.every((s) => s == 'partially')) {
        await FirebaseFirestore.instance
            .collection('station_owners')
            .doc(widget.stationOwnerDocId)
            .update({'status': 'district_approved'});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All statuses are "partially". Station marked as district_approved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All statuses updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update statuses')),
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
              : Column(
                  children: [
                    // --- Add Update All Statuses button ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.update),
                            label: const Text('Update All Statuses'),
                            onPressed: statusEdits.isNotEmpty ? updateAllStatuses : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          if (statusEdits.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Text(
                                '${statusEdits.length} pending change(s)',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // --- Existing ListView.builder ---
                    Expanded(
                      child: ListView.builder(
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
                                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
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
                                        value: (['pending', 'partially', 'failed'].contains(status.toLowerCase()))
                                            ? status.toLowerCase()
                                            : null,
                                        hint: const Text('Set Status'),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'pending',
                                            child: Text('Pending'),
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
                    ),
                  ],
                ));
  }
}

// Checklist widget with file view buttons  
class ComplianceChecklistWithFiles extends StatefulWidget {
  final String stationOwnerDocId;
  final Map<String, dynamic> data;
  const ComplianceChecklistWithFiles({super.key, required this.stationOwnerDocId, required this.data});

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
  const SingleComplianceFileViewer({super.key, required this.stationOwnerDocId, required this.file});

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