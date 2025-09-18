import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DistrictManagementPage extends StatelessWidget {
  final void Function(void Function()) setState;
  final void Function(bool showSettings, bool showNotifications) onHeaderAction;
  const DistrictManagementPage({super.key, required this.setState, required this.onHeaderAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // White background
      child: Column(
        children: [
          // Header bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: const Text(
              "District Presidents",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.blueGrey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Container(
                width: 950,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "District Association Presidents",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.blueAccent,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
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
                          return GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 24,
                              childAspectRatio: 2.6,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, idx) {
                              final doc = docs[idx];
                              final data = doc.data() as Map<String, dynamic>;
                              final districtName = data['districtName'] ?? 'Unknown';
                              final customUID = data['customUID'];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: Colors.white,
                                shadowColor: Colors.blueGrey.withOpacity(0.08),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              districtName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            FutureBuilder<DocumentSnapshot?>(
                                              future: (customUID != null && customUID.isNotEmpty)
                                                  ? FirebaseFirestore.instance.collection('station_owners').doc(customUID).get()
                                                  : Future.value(null),
                                              builder: (context, snapshot) {
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
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 15,
                                                    color: ownerDisplay == "Not assigned" ? Colors.grey : Colors.blue[900],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[800],
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.12), blurRadius: 8)],
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.people, color: Colors.white, size: 30),
                                          onPressed: () async {
                                            setState(() {});
                                            await showDialog(
                                              context: context,
                                              builder: (context) => StationOwnersDialog(districtName: districtName),
                                            );
                                          },
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dummy dialog for demonstration. Replace with your actual implementation.
class StationOwnersDialog extends StatefulWidget {
  final String districtName;
  const StationOwnersDialog({super.key, required this.districtName});

  @override
  State<StationOwnersDialog> createState() => _StationOwnersDialogState();
}

class _StationOwnersDialogState extends State<StationOwnersDialog> {
  String searchText = ""; // <-- persist search text in dialog state

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('districts')
          .where('districtName', isEqualTo: widget.districtName)
          .get(),
      builder: (context, districtSnap) {
        if (districtSnap.connectionState == ConnectionState.waiting) {
          return const AlertDialog(content: Center(child: CircularProgressIndicator()));
        }
        if (districtSnap.hasError || districtSnap.data == null || districtSnap.data!.docs.isEmpty) {
          return const AlertDialog(content: Text('District not found.'));
        }
        final districtData = districtSnap.data!.docs.first.data() as Map<String, dynamic>;
        final currentPresidentUID = districtData['customUID'];
        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          contentPadding: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 32, left: 32, right: 32),
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.blueAccent),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Text(widget.districtName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue[900])),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current President Card
                FutureBuilder<DocumentSnapshot>(
                  future: currentPresidentUID != null && currentPresidentUID.isNotEmpty
                      ? FirebaseFirestore.instance.collection('station_owners').doc(currentPresidentUID).get()
                      : Future.value(null),
                  builder: (context, ownerSnap) {
                    String presidentName = "Not assigned";
                    String stationName = "";
                    String email = "";
                    if (ownerSnap.hasData && ownerSnap.data != null && ownerSnap.data!.exists) {
                      final ownerData = ownerSnap.data!.data() as Map<String, dynamic>?;
                      if (ownerData != null) {
                        final firstName = ownerData['firstName'] ?? '';
                        final lastName = ownerData['lastName'] ?? '';
                        presidentName = ('$firstName $lastName').trim();
                        stationName = ownerData['stationName'] ?? '';
                        email = ownerData['email'] ?? '';
                      }
                    }
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: Colors.white,
                      shadowColor: Colors.blueGrey.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.person, color: Colors.white, size: 36),
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Current President: $presidentName",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                                  ),
                                  if (stationName.isNotEmpty)
                                    Text(stationName, style: const TextStyle(fontSize: 14, color: Colors.black)),
                                  if (email.isNotEmpty)
                                    Text(email, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Search Bar and Owners List (refresh only list)
                StatefulBuilder(
                  builder: (context, setListState) {
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue[100]!),
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Search Station Owner, Email, or Station Name",
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                            ),
                            onChanged: (val) {
                              setListState(() {
                                searchText = val.trim().toLowerCase();
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          height: 340,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('station_owners')
                                .where('districtName', isEqualTo: widget.districtName)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return const Text('Error loading owners.');
                              }
                              final docs = snapshot.data?.docs ?? [];
                              final filteredDocs = docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.toLowerCase();
                                final email = (data['email'] ?? '').toLowerCase();
                                final stationName = (data['stationName'] ?? '').toLowerCase();
                                return searchText.isEmpty ||
                                    name.contains(searchText) ||
                                    email.contains(searchText) ||
                                    stationName.contains(searchText);
                              }).toList();
                              if (filteredDocs.isEmpty) {
                                return const Text('No owners found for this district.');
                              }
                              return ListView.builder(
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, idx) {
                                  final doc = filteredDocs[idx];
                                  final data = doc.data() as Map<String, dynamic>;
                                  final ownerUID = doc.id;
                                  final ownerName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                                  final stationName = data['stationName'] ?? '';
                                  final email = data['email'] ?? '';
                                  final isPresident = ownerUID == currentPresidentUID;
                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 10),
                                    color: Colors.white,
                                    shadowColor: Colors.blueGrey.withOpacity(0.08),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.blueAccent,
                                            child: Icon(
                                              isPresident ? Icons.verified_user : Icons.person,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ownerName.isEmpty ? 'Unnamed Owner' : ownerName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Colors.blue[900],
                                                  ),
                                                ),
                                                if (stationName.isNotEmpty)
                                                  Text(stationName, style: const TextStyle(fontSize: 14, color: Colors.black)),
                                                if (email.isNotEmpty)
                                                  Text(email, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
                                              ],
                                            ),
                                          ),
                                          if (!isPresident)
                                            IconButton(
                                              icon: const Icon(Icons.check_circle, color: Colors.blueAccent, size: 30),
                                              tooltip: "Assign as President",
                                              onPressed: () async {
                                                await FirebaseFirestore.instance
                                                    .collection('districts')
                                                    .where('districtName', isEqualTo: widget.districtName)
                                                    .get()
                                                    .then((districtSnap) async {
                                                  if (districtSnap.docs.isNotEmpty) {
                                                    await districtSnap.docs.first.reference.update({'customUID': ownerUID});
                                                  }
                                                });
                                                Navigator.of(context).pop();
                                              },
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
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

