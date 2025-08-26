import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DistrictManagementPage extends StatelessWidget {
  final void Function(void Function()) setState;
  final void Function(bool showSettings, bool showNotifications) onHeaderAction;
  const DistrictManagementPage({Key? key, required this.setState, required this.onHeaderAction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        
        Expanded(
          child: Center(
            child: Container(
              width: 950,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FAFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "District Association Presidents",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Table format for districts
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('districts').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Error loading districts'));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(child: Text('No districts found.'));
                        }
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('District Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('President', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final districtName = data['districtName'] ?? 'Unknown';
                              final customUID = data['customUID'];
                              return DataRow(
                                cells: [
                                  DataCell(Text(districtName)),
                                  DataCell(
                                    FutureBuilder<DocumentSnapshot?>(
                                      future: (customUID != null && customUID.isNotEmpty)
                                          ? FirebaseFirestore.instance.collection('station_owners').doc(customUID).get()
                                          : Future.value(null),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 80,
                                            height: 16,
                                            child: LinearProgressIndicator(minHeight: 2),
                                          );
                                        }
                                        String ownerDisplay = "Not assigned";
                                        if (customUID != null && customUID.isNotEmpty && snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                          final ownerData = snapshot.data!.data() as Map<String, dynamic>?;
                                          if (ownerData != null) {
                                            final firstName = ownerData['firstName'] ?? '';
                                            final lastName = ownerData['lastName'] ?? '';
                                            ownerDisplay = ('$firstName $lastName').trim();
                                            if (ownerDisplay.isEmpty) ownerDisplay = "Not assigned";
                                          }
                                        }
                                        return Text(
                                          ownerDisplay,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: ownerDisplay == "Not assigned" ? Colors.grey : Colors.blue[900],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.people, size: 18),
                                      label: const Text("Owners", style: TextStyle(fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        textStyle: const TextStyle(fontSize: 13),
                                      ),
                                      onPressed: () async {
                                        setState(() {
                                        });
                                        await showDialog(
                                          context: context,
                                          builder: (context) => StationOwnersDialog(districtName: districtName),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Dummy dialog for demonstration. Replace with your actual implementation.
class StationOwnersDialog extends StatelessWidget {
  final String districtName;
  const StationOwnersDialog({Key? key, required this.districtName}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Owners for $districtName'),
      content: const Text('List of owners goes here.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
