import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'compliance_files_viewer.dart';
import '../services/firestore_repository.dart';

// Responsive breakpoints for adaptive layouts
const double _kMobileBreakpoint = 800.0;
const double _kTabletBreakpointLower = 600.0;

class CompliancePage extends StatefulWidget {
  const CompliancePage({super.key});

  @override
  State<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends State<CompliancePage> {
  bool showComplianceReport = false;
  String complianceTitle = "";
  bool isLoading = false;
  Map<String, dynamic>? selectedStationData;
  String complianceStatusFilter = 'approved';
  String? selectedStationOwnerDocId;
  String? selectedDistrictFilter;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  int complianceCurrentPage = 0;
  static const int complianceRowsPerPage = 10;

  Future<void> _refreshSelectedStationData() async {
    if (selectedStationOwnerDocId != null) {
      final doc = await FirestoreRepository.instance.getDocumentOnce(
        'station_owners/$selectedStationOwnerDocId',
        () => FirebaseFirestore.instance.collection('station_owners').doc(selectedStationOwnerDocId),
      );
      setState(() {
        selectedStationData = doc.data() as Map<String, dynamic>?;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (showComplianceReport && selectedStationData != null && selectedStationOwnerDocId != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Always stack details above files viewer, regardless of orientation
          return Column(
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildComplianceReportDetailsFromData(selectedStationData!),
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
                              stationOwnerDocId: selectedStationOwnerDocId!,
                              onStatusChanged: _refreshSelectedStationData, // Pass callback
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
        },
      );
    }
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: const Text(
            "Compliance Report",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.blueAccent,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Status Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        complianceStatusFilter = 'district_approved';
                        complianceCurrentPage = 0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: complianceStatusFilter == 'district_approved'
                            ? Colors.blueAccent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: Text(
                          "Pending Approval",
                          style: TextStyle(
                            color: complianceStatusFilter == 'district_approved'
                                ? Colors.white
                                : Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        complianceStatusFilter = 'approved';
                        complianceCurrentPage = 0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: complianceStatusFilter == 'approved'
                            ? Colors.blueAccent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: Text(
                          "Approved",
                          style: TextStyle(
                            color: complianceStatusFilter == 'approved'
                                ? Colors.white
                                : Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Search box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: TextField(
              controller: searchController,
              onChanged: (val) {
                setState(() {
                  searchQuery = val.trim().toLowerCase();
                  complianceCurrentPage = 0;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search station, owner, email, or district',
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.blueAccent),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            searchQuery = '';
                            complianceCurrentPage = 0;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // District Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: FutureBuilder<QuerySnapshot>(
            future: FirestoreRepository.instance.getCollectionOnce(
              'districts',
              () => FirebaseFirestore.instance.collection('districts'),
            ),
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
                  const Text("Filter by District:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16)),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDistrictFilter,
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
                            selectedDistrictFilter = value;
                            complianceCurrentPage = 0;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        const Divider(thickness: 1, height: 1, color: Color(0xFFB3E5FC)),
        const SizedBox(height: 18),
        // Station Cards List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FutureBuilder<QuerySnapshot>(
              future: FirestoreRepository.instance.getCollectionOnce(
                'station_owners_status_$complianceStatusFilter',
                () => FirebaseFirestore.instance.collection('station_owners').where('status', isEqualTo: complianceStatusFilter),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading stations: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                // apply district filter first
                final baseDocs = (selectedDistrictFilter == null || selectedDistrictFilter!.isEmpty)
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final district = (data['districtName'] ?? '').toString().toLowerCase();
                        return district == (selectedDistrictFilter ?? '').toLowerCase();
                      }).toList();

                // apply search over stationName, owner, email, district
                final filteredDocs = baseDocs.where((doc) {
                  if (searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                  final ownerName = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final district = (data['districtName'] ?? '').toString().toLowerCase();
                  return stationName.contains(searchQuery) || ownerName.contains(searchQuery) || email.contains(searchQuery) || district.contains(searchQuery);
                }).toList();
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
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          complianceStatusFilter == 'approved'
                              ? 'No approved stations found.'
                              : 'No pending approval stations found.',
                          style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                }
                // Responsive: show card list for mobile/tablet, DataTable for desktop
                final screenWidth = MediaQuery.of(context).size.width;
                final isMobile = screenWidth < _kMobileBreakpoint;
                final isTablet = screenWidth >= _kTabletBreakpointLower && screenWidth < _kMobileBreakpoint;

                if (isMobile || isTablet) {
                  // Card-based list for mobile/tablet
                  final cardPadding = isTablet ? 10.0 : 14.0;
                  final titleSize = isTablet ? 14.0 : 16.0;
                  final subtitleSize = isTablet ? 12.0 : 13.0;
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: pageDocs.length,
                          itemBuilder: (ctx, idx) {
                            final doc = pageDocs[idx];
                            final data = doc.data() as Map<String, dynamic>;
                            final stationName = data['stationName'] ?? '';
                            final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                            final district = data['districtName'] ?? '';
                            final address = data['address'] ?? '';
                            final status = data['status'] ?? '';
                            final stationOwnerDocId = doc.id;

                            return Card(
                              color: Colors.white,
                              margin: EdgeInsets.symmetric(vertical: isTablet ? 8 : 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200, width: 1)),
                              elevation: 0.5,
                              child: Padding(
                                padding: EdgeInsets.all(cardPadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(stationName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: titleSize, color: Colors.blueAccent)),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.person, size: subtitleSize + 2, color: Colors.black54),
                                                  const SizedBox(width: 6),
                                                  Expanded(child: Text(ownerName, style: TextStyle(fontSize: subtitleSize))),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.location_city, size: subtitleSize + 2, color: Colors.black54),
                                                  const SizedBox(width: 6),
                                                  Expanded(child: Text(district, style: TextStyle(fontSize: subtitleSize, color: Colors.black54))),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(6)),
                                          child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    if (address.toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.home, size: subtitleSize + 2, color: Colors.black45),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(address, style: TextStyle(fontSize: subtitleSize), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
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
                                            backgroundColor: Colors.blueAccent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          child: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Pagination controls
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 28),
                              color: Colors.blueAccent,
                              onPressed: complianceCurrentPage > 0 ? () => setState(() => complianceCurrentPage--) : null,
                            ),
                            Text(
                              'Page ${totalPages == 0 ? 0 : (complianceCurrentPage + 1)} of $totalPages',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 28),
                              color: Colors.blueAccent,
                              onPressed: complianceCurrentPage < totalPages - 1 ? () => setState(() => complianceCurrentPage++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Desktop: Table-style list (unchanged)
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columnSpacing: 18,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFE3F2FD)),
                          columns: const [
                            DataColumn(label: Text('Station Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Owner', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('District', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: pageDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final stationName = data['stationName'] ?? '';
                            final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                            final district = data['districtName'] ?? '';
                            final address = data['address'] ?? '';
                            final status = data['status'] ?? '';
                            final stationOwnerDocId = doc.id;
                            return DataRow(
                              cells: [
                                DataCell(Text(stationName, style: const TextStyle(color: Colors.blueAccent))),
                                DataCell(Text(ownerName)),
                                DataCell(Text(district)),
                                DataCell(Text(address)),
                                DataCell(
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
                                      backgroundColor: Colors.blueAccent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    ),
                                    child: const Text(
                                      "View Details",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // Pagination
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 28),
                            color: Colors.blueAccent,
                            onPressed: complianceCurrentPage > 0
                                ? () => setState(() {
                                    complianceCurrentPage--;
                                  })
                                : null,
                          ),
                          Text(
                            'Page ${totalPages == 0 ? 0 : (complianceCurrentPage + 1)} of $totalPages',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 28),
                            color: Colors.blueAccent,
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
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

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
                    showComplianceReport = false;
                    selectedStationData = null;
                    selectedStationOwnerDocId = null;
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
          // Replace the static "Store Name" label with the selected stationName
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
}

