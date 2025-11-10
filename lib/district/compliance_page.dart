import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'district_compliance_files_viewer.dart';
import 'package:intl/intl.dart';

class CompliancePage extends StatefulWidget {
  final String userDistrict;
  const CompliancePage({required this.userDistrict, super.key});

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

  Future<void> _refreshSelectedStationData() async {
    if (selectedStationOwnerDocId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('station_owners')
        .doc(selectedStationOwnerDocId)
        .get();
    if (doc.exists) {
      setState(() {
        selectedStationData = doc.data();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Details view
    if (showComplianceReport && selectedStationData != null && selectedStationOwnerDocId != null) {
      return Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color.fromARGB(255, 234, 248, 255),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF087693)),
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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118)),
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
                    child: Column(
                      children: [
                        _buildComplianceReportDetailsFromData(selectedStationData!),
                        const SizedBox(height: 16),
                        // Was: fixed height 420 -> make viewer take remaining space
                        Expanded(
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
                                onStatusChanged: _refreshSelectedStationData, // refresh header after updates
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Main compliance page
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);

    return Column(
      children: [
        // Header with date and time
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF087693)),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFF087693)),
                  const SizedBox(width: 8),
                  Text(
                    "$formattedTime PST",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Compliance Report title
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            "Compliance Report",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118)),
          ),
        ),
        // Tab selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      complianceStatusFilter = 'pending_approval';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: complianceStatusFilter == 'pending_approval'
                          ? const Color.fromARGB(255, 234, 248, 255)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        "Pending Approval",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: complianceStatusFilter == 'pending_approval'
                              ? Color.fromARGB(255, 0, 92, 118)
                              : Colors.black54,
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
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: complianceStatusFilter == 'approved'
                          ? const Color.fromARGB(255, 234, 248, 255)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        "Approved",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: complianceStatusFilter == 'approved'
                              ? Color.fromARGB(255, 0, 92, 118)
                              : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // NEW: District Approved tab
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      complianceStatusFilter = 'district_approved';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: complianceStatusFilter == 'district_approved'
                          ? const Color.fromARGB(255, 234, 248, 255)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        "District Approved",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: complianceStatusFilter == 'district_approved'
                              ? Color.fromARGB(255, 0, 92, 118)
                              : Colors.black54,
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
        const SizedBox(height: 16),
        // List of store cards
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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

                if (filteredDocs.isEmpty) {
                  final msg = complianceStatusFilter == 'approved'
                      ? 'No approved stations found.'
                      : complianceStatusFilter == 'pending_approval'
                          ? 'No pending approval stations found.'
                          : 'No district-approved stations found.';
                  return Center(child: Text(msg));
                }

                return ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, idx) {
                    final doc = filteredDocs[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final stationName = data['stationName'] ?? '';
                    final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                    final district = data['districtName'] ?? '';
                    final address = data['address'] ?? '';
                    final stationOwnerDocId = doc.id;
                    final isSelected = selectedStationOwnerDocId == stationOwnerDocId && showComplianceReport;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: isSelected
                            ? Border.all(color: Color(0xFF087693), width: 2)
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stationName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ownerName,
                                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                                  ),
                                  Text(
                                    district,
                                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                                  ),
                                  Text(
                                    address,
                                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isLoading = true;
                                });
                                Future.delayed(const Duration(milliseconds: 200), () {
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
                                backgroundColor: Color(0xFF0094c3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                "View Details",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
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
                  Icon(Icons.assignment_turned_in, color: Color(0xFF087693), size: 32),
                  const SizedBox(width: 12),
                  Text(
                    "Compliance Report Details",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 92, 118),
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
                            const Icon(Icons.person, color: Color(0xFF087693), size: 18),
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
                            const Icon(Icons.location_on, color: Color(0xFF087693), size: 18),
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
                            const Icon(Icons.phone, color: Color(0xFF087693), size: 18),
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
                            const Icon(Icons.email, color: Color(0xFF087693), size: 18),
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
                            const Icon(Icons.calendar_today, color: Color(0xFF087693), size: 18),
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
                            const Icon(Icons.verified, color: Color(0xFF087693), size: 18),
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
                                            ? Color(0xFF087693)
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

