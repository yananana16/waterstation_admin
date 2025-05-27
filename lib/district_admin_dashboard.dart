import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DistrictAdminDashboard extends StatefulWidget {
  final String? selectedDistrict; // Add this line

  const DistrictAdminDashboard({super.key, this.selectedDistrict}); // Update constructor

  @override
  _DistrictAdminDashboardState createState() => _DistrictAdminDashboardState();
}

class _DistrictAdminDashboardState extends State<DistrictAdminDashboard> {
  int _selectedIndex = 0;

  // Add a variable to hold districts data
  late Future<List<Map<String, dynamic>>> _districtsFuture;

  @override
  void initState() {
    super.initState();
    _districtsFuture = _fetchDistricts();
  }

  // Fetch districts from Firestore
  Future<List<Map<String, dynamic>>> _fetchDistricts() async {
    final snapshot = await FirebaseFirestore.instance.collection('districts').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
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
                  ),
                ],
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
            final districts = snapshot.data ?? [];

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
                            final selectedDistrict = widget.selectedDistrict?.toLowerCase();
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
                // Table Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text("Name of Station", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("Owner Name", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("District", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("Compliance Report", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("Address", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const Divider(thickness: 1),
                // Table Content
                Expanded(
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
                      // Filter by search query and selected district
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                        final ownerName = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                        final district = (data['districtName'] ?? '').toString().toLowerCase();
                        final matchesSearch = searchQuery.isEmpty ||
                          stationName.contains(searchQuery) ||
                          ownerName.contains(searchQuery) ||
                          district.contains(searchQuery);
                        final matchesDistrict = widget.selectedDistrict == null ||
                          (data['districtName']?.toString().toLowerCase() == widget.selectedDistrict!.toLowerCase());
                        return matchesSearch && matchesDistrict;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return const Center(child: Text('No station owners found.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data() as Map<String, dynamic>;
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text(stationName)),
                                Expanded(flex: 2, child: Text(ownerName)),
                                Expanded(flex: 1, child: Text(district)),
                                Expanded(
                                  flex: 1,
                                  child: TextButton(
                                    onPressed: () {
                                      // Handle compliance report view
                                    },
                                    child: const Text("View", style: TextStyle(color: Color(0xFF1976D2))),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: TextButton(
                                    onPressed: () {
                                      if (lat != null && lng != null) {
                                        mapSelectedLocation = LatLng(lat!, lng!);
                                        mapController.move(LatLng(lat!, lng!), 16.0);
                                        setState(() {});
                                      }
                                    },
                                    child: const Text("View Location", style: TextStyle(color: Color(0xFF1976D2))),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
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

    return StatefulBuilder(
      builder: (context, setState) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (showComplianceReport) {
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
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1976D2)),
                      onPressed: () {
                        setState(() {
                          showComplianceReport = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _complianceReportDetails(),
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
            const SizedBox(height: 16),
            // Responsive Layout
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isDesktop = constraints.maxWidth >= 800;
                  return isDesktop
                      ? Row(
                          children: [
                            // "For Approval" Section
                            Expanded(
                              child: _complianceSection(
                                "For Approval",
                                Color(0xFF1976D2),
                                10,
                                (title) {
                                  setState(() {
                                    isLoading = true;
                                    Future.delayed(const Duration(seconds: 1), () {
                                      setState(() {
                                        isLoading = false;
                                        showComplianceReport = true;
                                        complianceTitle = title;
                                      });
                                    });
                                  });
                                },
                              ),
                            ),
                            // "Approved" Section
                            Expanded(
                              child: _complianceSection(
                                "Approved",
                                Colors.green,
                                5,
                                (title) {
                                  setState(() {
                                    isLoading = true;
                                    Future.delayed(const Duration(seconds: 1), () {
                                      setState(() {
                                        isLoading = false;
                                        showComplianceReport = true;
                                        complianceTitle = title;
                                      });
                                    });
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            // "For Approval" Section
                            Expanded(
                              child: _complianceSection(
                                "For Approval",
                                Color(0xFF1976D2),
                                10,
                                (title) {
                                  setState(() {
                                    isLoading = true;
                                    Future.delayed(const Duration(seconds: 1), () {
                                      setState(() {
                                        isLoading = false;
                                        showComplianceReport = true;
                                        complianceTitle = title;
                                      });
                                    });
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            // "Approved" Section
                            Expanded(
                              child: _complianceSection(
                                "Approved",
                                Colors.green,
                                5,
                                (title) {
                                  setState(() {
                                    isLoading = true;
                                    Future.delayed(const Duration(seconds: 1), () {
                                      setState(() {
                                        isLoading = false;
                                        showComplianceReport = true;
                                        complianceTitle = title;
                                      });
                                    });
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _complianceSection(String title, Color buttonColor, int itemCount, Function(String) onViewDetails) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$title Station ${index + 1}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          onViewDetails("$title Station ${index + 1}");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          title == "For Approval" ? "View Compliance" : "View Details",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _complianceReportDetails() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Compliance Report Details",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("PureFlow Water Station", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("Owner's Name: Mark Delacruz"),
                    Text("Location: Brgy. San Vicente Jaro, Iloilo City"),
                    Text("Contact Number: 09178456210"),
                    Text("Email: markdelacruz@gmail.com"),
                    Text("Date of Compliance: March 15, 2023"),
                    Text("Status: Approved"),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                    ),
                    const SizedBox(height: 8),
                    _checklistItem("Bacteriological Test Result", "Approved"),
                    _checklistItem("Physical-Chemical Test Result", "Approved"),
                    _checklistItem("Business Permit", "Approved"),
                    _checklistItem("DTI", "Approved"),
                    _checklistItem("Sanitary Permit", "Approved"),
                    _checklistItem("Mayor's Permit", "Approved"),
                    _checklistItem("Fire Safety Certificate", "Approved"),
                    _checklistItem("Other Documents", "Approved"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _checklistItem(String label, String status) {
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

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }
}

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