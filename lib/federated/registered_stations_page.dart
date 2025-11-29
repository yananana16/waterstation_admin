import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_repository.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'compliance_files_viewer.dart';

// Responsive breakpoints
const double _kMobileBreakpoint = 800.0;
const double _kTabletBreakpointLower = 600.0;

// Persisted sort state for the registered stations table (file-scoped)
int _registeredStationsSortColumnIndex = 0;
bool _registeredStationsSortAscending = true;

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
  final void Function(void Function()) setState;
  final void Function(bool, Map<String, dynamic>?, String?, String) onShowComplianceReportDetails;
  final void Function(LatLng?) onMapSelectedLocation;
  final void Function(String) onSearchQueryChanged;
  final void Function(String?) onDistrictFilterChanged;
  final void Function(int) onCurrentPageChanged;
  final bool isDistrictAdmin; // New parameter to control filter visibility

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
    required this.setState,
    required this.onShowComplianceReportDetails,
    required this.onMapSelectedLocation,
    required this.onSearchQueryChanged,
    required this.onDistrictFilterChanged,
    required this.onCurrentPageChanged,
    this.isDistrictAdmin = false, // Default to false for federated admin
  });

  @override
  Widget build(BuildContext context) {
  const int rowsPerPage = 8;
  // Tablet breakpoint: between tabletBreakpointLower and mobileBreakpoint we'll use a denser layout

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
                  _buildComplianceReportDetailsFromData(context, selectedComplianceStationData!),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.10 * 255).round()),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ComplianceFilesViewer(
                          stationOwnerDocId: selectedComplianceStationDocId!,
                          isDistrictAdmin: isDistrictAdmin,
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

  final screenWidth = MediaQuery.of(context).size.width;

  // If small screen, render mobile-friendly stacked layout
  final isMobile = screenWidth < _kMobileBreakpoint;

  // Desktop / wide layout: left column = table, right column = map
  return isMobile
      ? _buildMobileLayout(context, rowsPerPage)
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Table and controls (smaller)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search & filter (kept similar to previous layout)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                        children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((0.06 * 255).round()),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: TextField(
                              controller: searchController,
                              onChanged: (value) => onSearchQueryChanged(value.toLowerCase()),
                              decoration: const InputDecoration(
                                hintText: "Search",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isDistrictAdmin)
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.blueAccent.withAlpha((0.3 * 255).round())),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, color: Colors.blue[800], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  registeredStationsDistrictFilter ?? 'District',
                                  style: TextStyle(fontSize: 15, color: Colors.blue[900], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            width: 280,
                            child: FutureBuilder<QuerySnapshot>(
                              future: FirestoreRepository.instance.getCollectionOnce(
                                'districts',
                                () => FirebaseFirestore.instance.collection('districts'),
                              ),
                              builder: (context, snapshot) {
                                final docs = snapshot.data?.docs ?? [];
                                final districts = docs
                                    .map((doc) => doc['districtName']?.toString() ?? '')
                                    .where((d) => d.isNotEmpty)
                                    .toSet()
                                    .toList()
                                  ..sort();
                                return Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: (registeredStationsDistrictFilter == null || (registeredStationsDistrictFilter?.isEmpty ?? true))
                                                ? null
                                                : registeredStationsDistrictFilter,
                                            hint: const Text('Filter'),
                                            isExpanded: true,
                                            items: districts.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                                            onChanged: (v) => onDistrictFilterChanged(v),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.filter_alt, color: Colors.blue[800], size: 20),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () {
                                          searchController.clear();
                                          onSearchQueryChanged('');
                                          onDistrictFilterChanged(null);
                                          try {
                                            setState(() {});
                                          } catch (_) {}
                                        },
                                        icon: const Icon(Icons.clear, size: 18, color: Colors.blueAccent),
                                        label: const Text('Clear', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), minimumSize: const Size(0, 0)),
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

                  // Table area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                      child: FutureBuilder<QuerySnapshot>(
                        future: FirestoreRepository.instance.getCollectionOnce(
                          'station_owners',
                          () => FirebaseFirestore.instance.collection('station_owners'),
                        ),
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
                            final district = (data['districtName'] ?? '').toString().toLowerCase();
                            final matchesSearch = searchQuery.isEmpty || stationName.contains(searchQuery) || ownerName.contains(searchQuery) || district.contains(searchQuery);
                            final matchesDistrict = registeredStationsDistrictFilter == null || registeredStationsDistrictFilter!.isEmpty
                                ? true
                                : (data['districtName'] ?? '') == registeredStationsDistrictFilter;
                            return matchesSearch && matchesDistrict;
                          }).toList();

                          // Apply sort based on persistent column/index state (Station=0, District=1, Status=2)
                          filteredDocs.sort((a, b) {
                            final aMap = a.data() as Map<String, dynamic>;
                            final bMap = b.data() as Map<String, dynamic>;

                            int cmp = 0;
                            if (_registeredStationsSortColumnIndex == 0) {
                              final aName = (aMap['stationName'] ?? '').toString().toLowerCase();
                              final bName = (bMap['stationName'] ?? '').toString().toLowerCase();
                              cmp = aName.compareTo(bName);
                            } else if (_registeredStationsSortColumnIndex == 1) {
                              final aDistrict = (aMap['districtName'] ?? '').toString().toLowerCase();
                              final bDistrict = (bMap['districtName'] ?? '').toString().toLowerCase();
                              cmp = aDistrict.compareTo(bDistrict);
                            } else if (_registeredStationsSortColumnIndex == 2) {
                              int mapStatus(Map<String, dynamic> m) {
                                final s = (m['status'] ?? '').toString().toLowerCase();
                                return s == 'done' ? 0 : 1;
                              }
                              cmp = mapStatus(aMap).compareTo(mapStatus(bMap));
                            }

                            return _registeredStationsSortAscending ? cmp : -cmp;
                          });

                          if (filteredDocs.isEmpty) {
                            return const Center(child: Text('No station owners found.'));
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.blueGrey.shade100, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((0.06 * 255).round()),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            width: double.infinity,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  // enable sorting state
                                  sortColumnIndex: _registeredStationsSortColumnIndex,
                                  sortAscending: _registeredStationsSortAscending,
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFD6E8FD)),
                                  dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                                    (Set<WidgetState> states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return Colors.blueAccent.withAlpha((0.08 * 255).round());
                                      }
                                      return Colors.white;
                                    },
                                  ),
                                  columnSpacing: 24,
                                  horizontalMargin: 16,
                                  dividerThickness: 1.2,
                                  dataRowMinHeight: 48,
                                  dataRowMaxHeight: 56,
                                  columns: [
                                    DataColumn(
                                      label: SizedBox(
                                        width: 240,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Text('Station', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 12)),
                                        ),
                                      ),
                                      onSort: (colIndex, ascending) {
                                        _registeredStationsSortColumnIndex = colIndex;
                                        _registeredStationsSortAscending = ascending;
                                        try {
                                          setState(() {});
                                        } catch (_) {}
                                      },
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: 120,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Text('District', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 12)),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: 86,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Expanded(
                                                child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 12)),
                                              ),
                                              if (_registeredStationsSortColumnIndex == 2)
                                                Icon(
                                                  _registeredStationsSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                                  size: 12,
                                                  color: const Color(0xFF1976D2),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      onSort: (colIndex, ascending) {
                                        _registeredStationsSortColumnIndex = colIndex;
                                        _registeredStationsSortAscending = ascending;
                                        try {
                                          setState(() {});
                                        } catch (_) {}
                                      },
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: 140,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 12)),
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: filteredDocs.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final stationName = data['stationName'] ?? '';
                                    final district = data['districtName'] ?? '';
                                    final rawStatus = (data['status'] ?? '').toString();
                                    final statusNormalized = rawStatus.toLowerCase() == 'done' ? 'Done' : 'Pending';
                                    final statusColor = statusNormalized == 'Done' ? const Color(0xFF4CAF50) : const Color(0xFFFFC107);
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

                                    return DataRow(cells: [
                                      DataCell(SizedBox(width: 240, child: Text(stationName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis))),
                                      DataCell(SizedBox(width: 120, child: Text(district, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                                      DataCell(SizedBox(width: 86, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)), child: Text(statusNormalized, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))))),
                                      DataCell(SizedBox(
                                        width: 140,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.location_on, color: Colors.blueAccent, size: 20),
                                              tooltip: "View on Map",
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                if (lat != null && lng != null) {
                                                  onMapSelectedLocation(LatLng(lat, lng));
                                                  mapController.move(LatLng(lat, lng), 16.0);
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.description, color: Colors.blueAccent, size: 20),
                                              tooltip: "View Compliance Report",
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                onShowComplianceReportDetails(true, data, doc.id, stationName);
                                              },
                                            ),
                                          ],
                                        ),
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right: Map (larger)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withAlpha((0.2 * 255).round()), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withAlpha((0.07 * 255).round()),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirestoreRepository.instance.getCollectionOnce(
                        'station_owners',
                        () => FirebaseFirestore.instance.collection('station_owners'),
                      ),
                      builder: (context, snapshot) {
                        final center = mapSelectedLocation ?? LatLng(10.7202, 122.5621);
                        List<Marker> markers = [];
                        if (snapshot.hasData) {
                          final docs = snapshot.data!.docs;
                          for (final doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            // Respect district filter (applies to district president and federated filter)
                            final docDistrict = (data['districtName'] ?? '').toString();
                            if (registeredStationsDistrictFilter != null && registeredStationsDistrictFilter!.isNotEmpty) {
                              if (docDistrict != registeredStationsDistrictFilter) continue;
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
                              markers.add(Marker(width: 44, height: 44, point: LatLng(lat, lng), child: Tooltip(message: stationName, child: Container(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.blueAccent.withAlpha((0.15 * 255).round()), blurRadius: 6, spreadRadius: 1),]), child: const Icon(Icons.location_on, color: Colors.blueAccent, size: 32)))));
                            }
                          }
                        }
                        return FlutterMap(
                          mapController: mapController,
                          options: MapOptions(initialCenter: center, initialZoom: mapSelectedLocation != null ? 16.0 : 12.0),
                          children: [
                            TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c'], userAgentPackageName: 'com.example.app'),
                            MarkerLayer(markers: markers),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
          );

        }

        Widget _buildMobileLayout(BuildContext context, int rowsPerPage) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= _kTabletBreakpointLower && screenWidth < _kMobileBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Map (smaller on mobile)
        Container(
          height: 200,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withAlpha((0.2 * 255).round()), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<QuerySnapshot>(
              future: FirestoreRepository.instance.getCollectionOnce(
                'station_owners',
                () => FirebaseFirestore.instance.collection('station_owners'),
              ),
              builder: (context, snapshot) {
                final center = mapSelectedLocation ?? LatLng(10.7202, 122.5621);
                List<Marker> markers = [];
                if (snapshot.hasData) {
                  final docs = snapshot.data!.docs;
                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Respect district filter on mobile map as well
                    final docDistrict = (data['districtName'] ?? '').toString();
                    if (registeredStationsDistrictFilter != null && registeredStationsDistrictFilter!.isNotEmpty) {
                      if (docDistrict != registeredStationsDistrictFilter) continue;
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
                            child: const Icon(Icons.location_on, color: Colors.blueAccent, size: 28),
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

        // Stacked search and filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => onSearchQueryChanged(value.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: "Search",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // District display (read-only for district admin) or Filter (for federated admin)
              if (isDistrictAdmin)
                // Show district name as read-only for district admin
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.blueAccent.withAlpha((0.3 * 255).round())),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: Colors.blue[800], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        registeredStationsDistrictFilter ?? 'District',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Show filter dropdown for federated admin
                FutureBuilder<QuerySnapshot>(
                  future: FirestoreRepository.instance.getCollectionOnce(
                    'districts',
                    () => FirebaseFirestore.instance.collection('districts'),
                  ),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final districts = docs
                        .map((doc) => doc['districtName']?.toString() ?? '')
                        .where((d) => d.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();
                    return Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (registeredStationsDistrictFilter == null || (registeredStationsDistrictFilter?.isEmpty ?? true))
                                    ? null
                                    : registeredStationsDistrictFilter,
                                hint: const Text('Filter'),
                                isExpanded: true,
                                items: districts
                                    .map((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                                    .toList(),
                                onChanged: (v) => onDistrictFilterChanged(v),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            searchController.clear();
                            onSearchQueryChanged('');
                            onDistrictFilterChanged(null);
                            try {
                              setState(() {});
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.clear, color: Colors.blueAccent),
                          label: const Text('Clear', style: TextStyle(color: Colors.blueAccent)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), minimumSize: const Size(0, 0)),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),

        // List of stations as cards for mobile/tablet
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: FutureBuilder<QuerySnapshot>(
              future: FirestoreRepository.instance.getCollectionOnce(
                'station_owners',
                () => FirebaseFirestore.instance.collection('station_owners'),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading station owners: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
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
                }).toList()
                  ..sort((a, b) {
                    final aName = (a.data() as Map<String, dynamic>)['stationName']?.toString().toLowerCase() ?? '';
                    final bName = (b.data() as Map<String, dynamic>)['stationName']?.toString().toLowerCase() ?? '';
                    return aName.compareTo(bName);
                  });

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No station owners found.'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (ctx, idx) {
                    final doc = filteredDocs[idx];
                          final data = doc.data() as Map<String, dynamic>;
                          final stationName = data['stationName'] ?? '';
                          final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                          final district = data['districtName'] ?? '';
                          final email = data['email'] ?? '';
                          final phone = data['phone'] ?? '';
                          final addressSnippet = (data['address'] ?? '').toString();
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
                          final rawStatus = (data['status'] ?? '').toString();
                          final statusNormalized = rawStatus.toLowerCase() == 'done' ? 'Done' : 'Pending';
                          final statusColor = statusNormalized == 'Done' ? const Color(0xFF4CAF50) : const Color(0xFFFFC107);

                          // Dense style for tablet: smaller paddings and fonts
                          final cardPadding = isTablet ? 8.0 : 12.0;
                          final titleSize = isTablet ? 14.0 : 16.0;
                          final subtitleSize = isTablet ? 12.0 : 13.0;

                          return Card(
                            color: Colors.white,
                            margin: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                            elevation: 0.5,
                            child: Padding(
                              padding: EdgeInsets.all(cardPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Leading icon + title
                                      Padding(
                                        padding: EdgeInsets.only(right: isTablet ? 8 : 12),
                                        child: CircleAvatar(
                                          radius: isTablet ? 18 : 22,
                                          backgroundColor: Colors.blueAccent.withOpacity(0.12),
                                          child: const Icon(Icons.local_drink, color: Colors.blueAccent),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(stationName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: titleSize)),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 6,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.person, size: subtitleSize + 2, color: Colors.black54),
                                                    const SizedBox(width: 6),
                                                    Text(ownerName, style: TextStyle(fontSize: subtitleSize)),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.location_city, size: subtitleSize + 2, color: Colors.black54),
                                                    const SizedBox(width: 6),
                                                    Text(district, style: TextStyle(fontSize: subtitleSize, color: Colors.black54)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status chip
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 10, vertical: isTablet ? 4 : 6),
                                        decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)),
                                        child: Text(statusNormalized, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Secondary info row (email, phone, address snippet)
                                  Row(
                                    children: [
                                      if ((email ?? '').toString().isNotEmpty) ...[
                                        Icon(Icons.email, size: subtitleSize + 2, color: Colors.black45),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(email.toString(), style: TextStyle(fontSize: subtitleSize), overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 12),
                                      ],
                                      if ((phone ?? '').toString().isNotEmpty) ...[
                                        Icon(Icons.phone, size: subtitleSize + 2, color: Colors.black45),
                                        const SizedBox(width: 6),
                                        Text(phone.toString(), style: TextStyle(fontSize: subtitleSize)),
                                      ],
                                    ],
                                  ),
                                  if (addressSnippet.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.home, size: subtitleSize + 2, color: Colors.black45),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(addressSnippet, style: TextStyle(fontSize: subtitleSize), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Tooltip(
                                        message: 'View on map',
                                        child: IconButton(
                                          icon: const Icon(Icons.location_on, color: Colors.blueAccent),
                                          onPressed: () {
                                            if (lat != null && lng != null) {
                                              onMapSelectedLocation(LatLng(lat, lng));
                                              mapController.move(LatLng(lat, lng), 16.0);
                                            }
                                          },
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'View compliance report',
                                        child: IconButton(
                                          icon: const Icon(Icons.description, color: Colors.blueAccent),
                                          onPressed: () {
                                            onShowComplianceReportDetails(true, data, doc.id, stationName);
                                          },
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => onShowComplianceReportDetails(true, data, doc.id, stationName),
                                        icon: const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                                        label: const Text('Details', style: TextStyle(color: Colors.blueAccent)),
                                        style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 12, vertical: isTablet ? 4 : 6)),
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

  Widget _buildComplianceReportDetailsFromData(BuildContext context, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.blueAccent, size: 32),
                onPressed: () {
                  onShowComplianceReportDetails(false, null, null, "");
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
          Text(
            data['stationName'] ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 16),
          // Normalize status for display in details view (Done or Pending only)
          Builder(
            builder: (ctx) {
              final rawStatus = (data['status'] ?? '').toString();
              final statusNormalized = rawStatus.toLowerCase() == 'done' ? 'Done' : 'Pending';
              return Container(
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
                        _detailCell(Icons.info, "Status", statusNormalized),
                      ],
                    ),
                  ],
                ),
              );
            },
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
