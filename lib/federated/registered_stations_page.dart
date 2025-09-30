import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_repository.dart';
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
  final void Function(void Function()) setState;
  final void Function(bool, Map<String, dynamic>?, String?, String) onShowComplianceReportDetails;
  final void Function(LatLng?) onMapSelectedLocation;
  final void Function(String) onSearchQueryChanged;
  final void Function(String?) onDistrictFilterChanged;
  final void Function(int) onCurrentPageChanged;

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
  });

  @override
  Widget build(BuildContext context) {
    const int rowsPerPage = 8;

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
        // Search and filter UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Search pill (left)
              SizedBox(
                width: 800,
                child: Container(
                  margin: const EdgeInsets.only(left: 220),
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
                          onChanged: (value) => onSearchQueryChanged(value.toLowerCase()),
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
                width: 700,
                child: FutureBuilder<QuerySnapshot>(
                  future: FirestoreRepository.instance.getCollectionOnce(
                    'districts',
                    () => FirebaseFirestore.instance.collection('districts'),
                  ),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    // Build a deduplicated, sorted list of district names to avoid duplicate DropdownMenuItem values
                    final districts = docs
                        .map((doc) => doc['districtName']?.toString() ?? '')
                        .where((d) => d.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();
                    return Container(
                      margin: const EdgeInsets.only(right: 500),
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
                                // If the selected filter is null or empty, pass null as value so the hint is shown
                                value: (registeredStationsDistrictFilter == null || (registeredStationsDistrictFilter?.isEmpty ?? true))
                                    ? null
                                    : registeredStationsDistrictFilter,
                                hint: const Text("Filter"),
                                isExpanded: true,
                                items: districts
                                    .map((district) => DropdownMenuItem<String>(
                                          value: district,
                                          child: Text(district),
                                        ))
                                    .toList(),
                                onChanged: (value) => onDistrictFilterChanged(value),
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                                icon: const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.filter_alt, color: Colors.blue[800]),
                          ),
                          // Clear filters button
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: TextButton.icon(
                              onPressed: () {
                                // Clear the search input and district filter, then refresh parent state
                                searchController.clear();
                                onSearchQueryChanged('');
                                onDistrictFilterChanged(null);
                                try {
                                  setState(() {});
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.clear, size: 18, color: Colors.blueAccent),
                              label: const Text(
                                'Clear',
                                style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
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
        ),
        // Table-based Station List
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
                  final matchesSearch = searchQuery.isEmpty ||
                      stationName.contains(searchQuery) ||
                      ownerName.contains(searchQuery) ||
                      district.contains(searchQuery);
                  final matchesDistrict = registeredStationsDistrictFilter == null || registeredStationsDistrictFilter!.isEmpty
                      ? true
                      : (data['districtName'] ?? '') == registeredStationsDistrictFilter;
                  return matchesSearch && matchesDistrict;
                }).toList();

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
                      child: ConstrainedBox(
  constraints: BoxConstraints(
    minWidth: MediaQuery.of(context).size.width * 0.9, // at least 90% of screen
  ),
  child: Container(
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
                            columnSpacing: 64,
                            horizontalMargin: 32,
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
                                    'CHO inspection Status',
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
                // Normalize status to only show 'Done' or 'Pending'.
                // Any value equal to 'done' (case-insensitive) => 'Done', otherwise => 'Pending'.
                final rawStatus = (data['status'] ?? '').toString();
                final statusNormalized = rawStatus.toLowerCase() == 'done' ? 'Done' : 'Pending';
                final statusColor = statusNormalized == 'Done'
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFFC107);

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                                      width: 320,
                                      child: Text(
                                        address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    // Show CHO inspection status by querying the inspections subcollection for the latest inspection
                                    FutureBuilder<QuerySnapshot>(
                                      future: () async {
                                        final now = DateTime.now();
                                        final ym = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
                                        return FirebaseFirestore.instance
                                            .collection('station_owners')
                                            .doc(doc.id)
                                            .collection('inspections')
                                            .where('monthlyInspectionMonth', isEqualTo: ym)
                                            .limit(1)
                                            .get();
                                      }(),
                                      builder: (ctx, inspSnap) {
                                        String displayStatus = statusNormalized; // fallback to owner doc status
                                        Color displayColor = statusColor;
                                        if (inspSnap.connectionState == ConnectionState.waiting) {
                                          return SizedBox(
                                            width: 90,
                                            child: Row(
                                              children: const [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                                SizedBox(width: 8),
                                                Text('Loading', style: TextStyle(fontSize: 12)),
                                              ],
                                            ),
                                          );
                                        }
                                        if (inspSnap.hasError) {
                                          // on error, fallback to owner status
                                          displayStatus = statusNormalized;
                                          displayColor = statusColor;
                                        } else if (inspSnap.hasData && inspSnap.data!.docs.isNotEmpty) {
                                          final inspDoc = inspSnap.data!.docs.first;
                                          final inspData = inspDoc.data() as Map<String, dynamic>;
                                          final rawInspStatus = (inspData['status'] ?? '').toString();
                                          final inspNormalized = rawInspStatus.toLowerCase() == 'done' ? 'Done' : 'Pending';
                                          displayStatus = inspNormalized;
                                          displayColor = inspNormalized == 'Done' ? const Color(0xFF4CAF50) : const Color(0xFFFFC107);
                                        }

                                        return Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(color: displayColor, borderRadius: BorderRadius.circular(6)),
                                            child: Text(
                                              displayStatus,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        );
                                      },
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
                                              onMapSelectedLocation(LatLng(lat, lng));
                                              mapController.move(LatLng(lat, lng), 16.0);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.description, color: Colors.blueAccent),
                                          tooltip: "View Compliance Report",
                                          onPressed: () {
                                            onShowComplianceReportDetails(
                                              true,
                                              data,
                                              doc.id,
                                              stationName,
                                            );
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
                    // Pagination controls
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: registeredStationsCurrentPage > 0
                                ? () => onCurrentPageChanged(registeredStationsCurrentPage - 1)
                                : null,
                          ),
                          Text(
                            'Page ${totalPages == 0 ? 0 : (registeredStationsCurrentPage + 1)} of $totalPages',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (registeredStationsCurrentPage < totalPages - 1)
                                ? () => onCurrentPageChanged(registeredStationsCurrentPage + 1)
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
