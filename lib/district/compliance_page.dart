import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'district_compliance_files_viewer.dart';

class CompliancePage extends StatefulWidget {
  final String userDistrict;
  const CompliancePage({required this.userDistrict, Key? key}) : super(key: key);

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

  int complianceCurrentPage = 0;
  static const int complianceRowsPerPage = 6;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildComplianceReportDetailsFromData(selectedStationData!),
                  ),
                  const SizedBox(width: 24),
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

    return Column(
      children: [
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
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final districtName = (data['districtName'] ?? '').toString().toLowerCase();
                  final userDistrict = widget.userDistrict.toLowerCase();
                  return districtName == userDistrict;
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
                                    width: 180,
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
}
