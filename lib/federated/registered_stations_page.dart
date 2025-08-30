import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'compliance_files_viewer.dart';

class RegisteredStationsPage extends StatelessWidget {
  final LatLng? mapSelectedLocation;
  final MapController mapController;
  final TextEditingController searchController;
  final String searchQuery;
  final int registeredStationsCurrentPage;
  final String? registeredStationsDistrictFilter;
  final bool showComplianceReportDetails;
  final Map<String, dynamic>? selectedComplianceStationData;
  final String? selectedComplianceStationDocId;
  final String complianceReportTitle;
  final void Function(void Function()) setStateCallback;

  const RegisteredStationsPage({
    super.key,
    required this.mapSelectedLocation,
    required this.mapController,
    required this.searchController,
    required this.searchQuery,
    required this.registeredStationsCurrentPage,
    required this.registeredStationsDistrictFilter,
    required this.showComplianceReportDetails,
    required this.selectedComplianceStationData,
    required this.selectedComplianceStationDocId,
    required this.complianceReportTitle,
    required this.setStateCallback,
  });

  @override
  Widget build(BuildContext context) {
    // --- Remove local state, use class fields instead ---
    const int rowsPerPage = 8;

    // Show compliance report details if requested
    if (showComplianceReportDetails &&
        selectedComplianceStationData != null &&
        selectedComplianceStationDocId != null) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildComplianceReportDetailsFromData(selectedComplianceStationData!),
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
                          stationOwnerDocId: selectedComplianceStationDocId!,
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
                final center = mapSelectedLocation ?? LatLng(10.7202, 122.5621);
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
                          controller: searchController,
                          onChanged: (value) {
                            setStateCallback(() {
                              // Update search query state
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
                                value: registeredStationsDistrictFilter,
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
                                  setStateCallback(() {
                                    // Update district filter state
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
                  final matchesSearch = searchQuery.isEmpty ||
                      stationName.contains(searchQuery) ||
                      ownerName.contains(searchQuery) ||
                      district.contains(searchQuery);
                  final matchesDistrict = registeredStationsDistrictFilter == null || registeredStationsDistrictFilter!.isEmpty
                      ? true
                      : (data['districtName'] ?? '') == registeredStationsDistrictFilter;
                  return matchesSearch && matchesDistrict;
                }).toList();

                // --- Pagination logic ---
                final totalRows = filteredDocs.length;
                final totalPages = (totalRows / rowsPerPage).ceil();
                final startIdx = registeredStationsCurrentPage * rowsPerPage;
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
                                              setStateCallback(() {
                                                // Update map location state
                                              });
                                              mapController.move(LatLng(lat, lng), 16.0);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.description, color: Colors.blueAccent),
                                          tooltip: "View Compliance Report",
                                          onPressed: () {
                                            setStateCallback(() {
                                              // Show compliance report details
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
                            onPressed: registeredStationsCurrentPage > 0
                                ? () => setStateCallback(() {
                                    // Go to previous page
                                  })
                                : null,
                          ),
                          Text(
                            'Page ${totalPages == 0 ? 0 : (registeredStationsCurrentPage + 1)} of $totalPages',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (registeredStationsCurrentPage < totalPages - 1)
                                ? () => setStateCallback(() {
                                    // Go to next page
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
                  setStateCallback(() {
                    // Close compliance report details
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
}