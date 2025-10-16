import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_repository.dart';
import 'package:flutter/material.dart';

class WaterStationsPage extends StatefulWidget {
  const WaterStationsPage({super.key});

  @override
  State<WaterStationsPage> createState() => _WaterStationsPageState();
}

class _WaterStationsPageState extends State<WaterStationsPage> {
  int currentPage = 0; // Track current page
  String searchQuery = ""; // Track search query
  String selectedDistrict = 'All Districts'; // Track selected district for filtering
  static const int rowsPerPage = 14;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: Row(
            children: [
              // Search bar
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                      currentPage = 0; // Reset to first page on search
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search by owner name or station name...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Filter dropdown for districts
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedDistrict,
                  items: ['All Districts', 'La Paz', 'Mandurriao', 'Molo', 'Lapuz', 'Arevalo', 'Jaro', 'City Proper']
                      .map((district) => DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDistrict = value ?? 'All Districts';
                      currentPage = 0; // Reset to first page on filter change
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Filter by district",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                // Filter by search query
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stationName = (data['stationName'] ?? '').toString().toLowerCase();
                  final ownerName = ('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toLowerCase();
                  final districtName = (data['districtName'] ?? '').toString().toLowerCase();

                  final matchesSearch = stationName.contains(searchQuery) || ownerName.contains(searchQuery);
                  final matchesDistrict = selectedDistrict == 'All Districts' || districtName == selectedDistrict.toLowerCase();

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

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF6FF)),
                          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFFE0F7FA);
                              }
                              return null; // Use default color
                            },
                          ),
                          columnSpacing: 24,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B63B7),
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          border: TableBorder.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          columns: const [
                            DataColumn(label: Text('Station Name')),
                            DataColumn(label: Text('Owner')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('District')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: pageDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final stationName = data['stationName'] ?? '';
                            final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                            final status = data['status'] ?? 'Unknown';
                            final districtName = data['districtName'] ?? 'Unknown';
                            final address = data['address'] ?? 'Unknown';
                            final email = data['email'] ?? 'Unknown';
                            final phone = data['phone'] ?? 'Unknown';

                            return DataRow(
                              cells: [
                                DataCell(Text(stationName)),
                                DataCell(Text(ownerName)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: status == 'approved'
                                          ? const Color(0xFF4CAF50).withAlpha((0.1 * 255).round())
                                          : const Color(0xFFD32F2F).withAlpha((0.1 * 255).round()),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: status == 'approved' ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(districtName)),
                                DataCell(
                                  ElevatedButton(
                                    onPressed: () {
                                      // Logic to view all details of the station_owner
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text('Details of $stationName'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _DetailRow(label: 'Owner:', value: ownerName),
                                                _DetailRow(label: 'Status:', value: status),
                                                _DetailRow(label: 'District:', value: districtName),
                                                _DetailRow(label: 'Address:', value: address),
                                                _DetailRow(label: 'Email:', value: email),
                                                _DetailRow(label: 'Phone:', value: phone),
                                                _DetailRow(label: 'Station Name:', value: stationName),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0B63B7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('View'),
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: Color(0xFF0B63B7)),
                            onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
                          ),
                          Text(
                            'Page ${totalPages == 0 ? 0 : (currentPage + 1)} of $totalPages',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B63B7),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Color(0xFF0B63B7)),
                            onPressed: (currentPage < totalPages - 1) ? () => setState(() => currentPage++) : null,
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
}

// Private helper for details (moved into this file)
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
