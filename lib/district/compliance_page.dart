import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'district_compliance_files_viewer.dart';
// removed unused intl import

// Responsive breakpoints (match federated layout)
const double _kMobileBreakpoint = 800.0;
const double _kTabletBreakpointLower = 600.0;

class CompliancePage extends StatefulWidget {
  final String userDistrict;
  const CompliancePage({required this.userDistrict, super.key});

  @override
  State<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends State<CompliancePage> {
    bool showSubmitReqOnly = false;
  bool showComplianceReport = false;
  String complianceTitle = "";
  bool isLoading = false;
  Map<String, dynamic>? selectedStationData;
  String complianceStatusFilter = 'approved';
  String? selectedStationOwnerDocId;
  // Added for federated-like layout
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  int complianceCurrentPage = 0;
  static const int complianceRowsPerPage = 10;

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

  Future<void> _refreshSelectedStationData() async {
    if (selectedStationOwnerDocId == null) return;
    final docSnap = await FirebaseFirestore.instance.collection('station_owners').doc(selectedStationOwnerDocId).get();
    if (!mounted) return;
    setState(() {
      selectedStationData = (docSnap.data() ?? {}) as Map<String, dynamic>?;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (showComplianceReport && selectedStationData != null && selectedStationOwnerDocId != null) {
      // Details stacked above files viewer, using same responsive container as federated
      return LayoutBuilder(builder: (context, constraints) {
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
                            onStatusChanged: _refreshSelectedStationData,
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
      });
    }

    // Main page (responsive like federated) — but scoped to widget.userDistrict
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
          ),
          child: const Text(
            "Compliance Report",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blueAccent, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 18),

        // Status Toggle (pending, approved, district_approved, submitreq)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(32)),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { complianceStatusFilter = 'pending_approval'; complianceCurrentPage = 0; showSubmitReqOnly = false; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: complianceStatusFilter == 'pending_approval' && !showSubmitReqOnly ? Colors.blueAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: Text('Pending Approval', style: TextStyle(color: complianceStatusFilter == 'pending_approval' && !showSubmitReqOnly ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { complianceStatusFilter = 'approved'; complianceCurrentPage = 0; showSubmitReqOnly = false; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: complianceStatusFilter == 'approved' && !showSubmitReqOnly ? Colors.blueAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(child: Text('Approved', style: TextStyle(color: complianceStatusFilter == 'approved' && !showSubmitReqOnly ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 16))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { complianceStatusFilter = 'district_approved'; complianceCurrentPage = 0; showSubmitReqOnly = false; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: complianceStatusFilter == 'district_approved' && !showSubmitReqOnly ? Colors.blueAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(child: Text('District Approved', style: TextStyle(color: complianceStatusFilter == 'district_approved' && !showSubmitReqOnly ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 16))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { showSubmitReqOnly = true; complianceCurrentPage = 0; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: showSubmitReqOnly ? Colors.orangeAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(child: Text('Need to Submit', style: TextStyle(color: showSubmitReqOnly ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 16))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Search box (scoped to district results)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: TextField(
              controller: searchController,
              onChanged: (val) {
                setState(() { searchQuery = val.trim().toLowerCase(); complianceCurrentPage = 0; });
              },
              decoration: InputDecoration(
                hintText: 'Search station, owner, email',
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.blueAccent), onPressed: () { searchController.clear(); setState(() { searchQuery = ''; complianceCurrentPage = 0; }); }) : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 1, height: 1, color: Color(0xFFB3E5FC)),
        const SizedBox(height: 18),

        // Station list (responsive: cards on mobile/tablet, DataTable on desktop)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('station_owners').where('status', isEqualTo: complianceStatusFilter).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error loading stations: ${snapshot.error}'));
                final docs = snapshot.data?.docs ?? [];
                // Scope to the current user's district
                final baseDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final district = (data['districtName'] ?? '').toString().toLowerCase();
                  return district == widget.userDistrict.toLowerCase();
                }).toList();

                // Filter for submitreq label if needed
                final submitReqDocs = showSubmitReqOnly
                  ? baseDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final labels = (data['labels'] ?? []) as List<dynamic>;
                      return labels.contains('submitreq');
                    }).toList()
                  : baseDocs;

                // apply search over stationName, owner, email
                final filteredDocs = submitReqDocs.where((doc) {
                  if (searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                  final ownerName = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return stationName.contains(searchQuery) || ownerName.contains(searchQuery) || email.contains(searchQuery);
                }).toList();

                final totalRows = filteredDocs.length;
                final totalPages = (totalRows / complianceRowsPerPage).ceil();
                final startIdx = complianceCurrentPage * complianceRowsPerPage;
                final endIdx = (startIdx + complianceRowsPerPage) > totalRows ? totalRows : (startIdx + complianceRowsPerPage);
                final pageDocs = filteredDocs.sublist(startIdx < totalRows ? startIdx : 0, endIdx < totalRows ? endIdx : totalRows);

                if (filteredDocs.isEmpty) {
                  final msg = complianceStatusFilter == 'approved' ? 'No approved stations found.' : complianceStatusFilter == 'pending_approval' ? 'No pending approval stations found.' : 'No district-approved stations found.';
                  return Center(child: Text(msg));
                }

                final screenWidth = MediaQuery.of(context).size.width;
                final isMobile = screenWidth < _kMobileBreakpoint;
                final isTablet = screenWidth >= _kTabletBreakpointLower && screenWidth < _kMobileBreakpoint;

                if (isMobile || isTablet) {
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
                                              Row(children: [Icon(Icons.person, size: subtitleSize + 2, color: Colors.black54), const SizedBox(width: 6), Expanded(child: Text(ownerName, style: TextStyle(fontSize: subtitleSize)))]),
                                              const SizedBox(height: 6),
                                              Row(children: [Icon(Icons.location_city, size: subtitleSize + 2, color: Colors.black54), const SizedBox(width: 6), Expanded(child: Text(district, style: TextStyle(fontSize: subtitleSize, color: Colors.black54)))]),
                                            ],
                                          ),
                                        ),
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(6)), child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                    if (address.toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(children: [Icon(Icons.home, size: subtitleSize + 2, color: Colors.black45), const SizedBox(width: 6), Expanded(child: Text(address, style: TextStyle(fontSize: subtitleSize), overflow: TextOverflow.ellipsis))]),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      ElevatedButton(onPressed: () { setState(() { isLoading = true; }); Future.delayed(const Duration(milliseconds: 300), () { setState(() { isLoading = false; showComplianceReport = true; complianceTitle = stationName; selectedStationData = data; selectedStationOwnerDocId = stationOwnerDocId; }); }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), child: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      const SizedBox(width: 8),
                                    ]),
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
                            IconButton(icon: const Icon(Icons.chevron_left, size: 28), color: Colors.blueAccent, onPressed: complianceCurrentPage > 0 ? () => setState(() => complianceCurrentPage--) : null),
                            Text('Page ${totalPages == 0 ? 0 : (complianceCurrentPage + 1)} of $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                            IconButton(icon: const Icon(Icons.chevron_right, size: 28), color: Colors.blueAccent, onPressed: complianceCurrentPage < totalPages - 1 ? () => setState(() => complianceCurrentPage++) : null),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Desktop table with horizontal scroll
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1000),
                            child: DataTable(
                              columnSpacing: 24,
                              horizontalMargin: 20,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFE3F2FD)),
                              columns: const [
                                DataColumn(label: SizedBox(width: 180, child: Text('Station Name', style: TextStyle(fontWeight: FontWeight.bold)))),
                                DataColumn(label: SizedBox(width: 150, child: Text('Owner', style: TextStyle(fontWeight: FontWeight.bold)))),
                                DataColumn(label: SizedBox(width: 120, child: Text('District', style: TextStyle(fontWeight: FontWeight.bold)))),
                                DataColumn(label: SizedBox(width: 200, child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold)))),
                                DataColumn(label: SizedBox(width: 120, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)))),
                                DataColumn(label: SizedBox(width: 130, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)))),
                              ],
                              rows: pageDocs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final stationName = data['stationName'] ?? '';
                                final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                                final district = data['districtName'] ?? '';
                                final address = data['address'] ?? '';
                                final status = data['status'] ?? '';
                                final stationOwnerDocId = doc.id;
                                return DataRow(cells: [
                                  DataCell(SizedBox(width: 180, child: Text(stationName, style: const TextStyle(color: Colors.blueAccent), overflow: TextOverflow.ellipsis))),
                                  DataCell(SizedBox(width: 150, child: Text(ownerName, overflow: TextOverflow.ellipsis))),
                                  DataCell(SizedBox(width: 120, child: Text(district, overflow: TextOverflow.ellipsis))),
                                  DataCell(SizedBox(width: 200, child: Text(address, overflow: TextOverflow.ellipsis))),
                                  DataCell(SizedBox(width: 120, child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))),
                                  DataCell(SizedBox(width: 130, child: ElevatedButton(onPressed: () { setState(() { isLoading = true; }); Future.delayed(const Duration(milliseconds: 300), () { setState(() { isLoading = false; showComplianceReport = true; complianceTitle = stationName; selectedStationData = data; selectedStationOwnerDocId = stationOwnerDocId; }); }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))))),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left, size: 28), color: Colors.blueAccent, onPressed: complianceCurrentPage > 0 ? () => setState(() => complianceCurrentPage--) : null),
                          Text('Page ${totalPages == 0 ? 0 : (complianceCurrentPage + 1)} of $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                          IconButton(icon: const Icon(Icons.chevron_right, size: 28), color: Colors.blueAccent, onPressed: complianceCurrentPage < totalPages - 1 ? () => setState(() => complianceCurrentPage++) : null),
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
                  const Icon(Icons.assignment_turned_in, color: Colors.blueAccent, size: 32),
                  const SizedBox(width: 12),
                  // Use Expanded to prevent overflow when the title is long
                  Expanded(
                    child: Text(
                      "Compliance Report Details",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                        : (data['status'] == 'district_approved')
                                            ? Colors.indigo
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
}

