import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Firestore functionality removed per request — placeholders/local data used instead.
// Note: creating Firebase Authentication users from a trusted/admin context
// should be done via the Firebase Admin SDK (Cloud Function). This UI will
// add inspector records to Firestore and a corresponding users doc, but
// creating the Auth account should be performed server-side for security.

// StaffSubscreen widget moved from schedule_page.dart
class StaffSubscreen extends StatefulWidget {
  final VoidCallback? onClose;
  const StaffSubscreen({super.key, this.onClose});

  @override
  State<StaffSubscreen> createState() => _StaffSubscreenState();
}

class _StaffSubscreenState extends State<StaffSubscreen> {
  // Local placeholder data used only as a fallback when Firestore isn't
  // reachable. Primary data is read from the `inspectors` collection.
  final List<Map<String, String>> _localInspectors = List.generate(
    5,
    (i) => {
      'id': 'inspector_sample_${i + 1}',
      'inspectorNo': '0${(i + 1).toString().padLeft(3, '0')}',
      'firstName': 'First$i',
      'lastName': 'Last$i',
      'displayName': 'First$i Last$i',
      'email': 'sample${i + 1}@example.com',
      'phone': '09${(100000000 + i).toString().substring(1)}',
      'role': 'inspector',
    },
  );

  Future<void> _showAddInspectorDialog() async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'inspector');
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Inspector (placeholder)'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: firstCtrl, decoration: const InputDecoration(labelText: 'First name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              TextFormField(controller: lastCtrl, decoration: const InputDecoration(labelText: 'Last name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              TextFormField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role'), readOnly: true),
              const SizedBox(height: 8),
              const Text('This demo will only add a local placeholder entry. No backend is modified.' , style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (res != true) return;

    final first = firstCtrl.text.trim();
    final last = lastCtrl.text.trim();
  final displayName = '$first $last';

    // Try to add to Firestore; fall back to local placeholder list on error.
    try {
      final col = FirebaseFirestore.instance.collection('inspectors');
      final docRef = col.doc();

      // Simple inspectorNo generator: month + last 4 digits of epoch millis
      final ms = DateTime.now().millisecondsSinceEpoch;
      final inspectorNo = '${DateTime.now().month.toString().padLeft(2, '0')}${(ms % 10000).toString().padLeft(4, '0')}';

      final payload = {
        'id': docRef.id,
        'inspectorNo': inspectorNo,
        'firstName': first,
        'lastName': last,
        'displayName': displayName,
        'email': 'inspector$inspectorNo@gmail.com',
        'phone': '',
        'role': roleCtrl.text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(payload);

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspector added')));
    } catch (e) {
      // Firestore failed — keep local placeholder for offline/demo use.
      final id = 'inspector_local_${DateTime.now().millisecondsSinceEpoch}';
      final inspectorNo = '${DateTime.now().month.toString().padLeft(2, '0')}${(_localInspectors.length + 1).toString().padLeft(3, '0')}';

      setState(() {
        _localInspectors.add({
          'id': id,
          'inspectorNo': inspectorNo,
          'firstName': first,
          'lastName': last,
          'displayName': displayName,
          'email': 'inspector$inspectorNo@gmail.com',
          'phone': '',
          'role': roleCtrl.text,
        });
      });

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspector added (local fallback)')));
    }
  }

  // Renders the local placeholder list (fallback when Firestore isn't available)
  Widget _buildInspectorListFromLocal() {
    if (_localInspectors.isEmpty) {
      return const Center(child: Text('No records found', style: TextStyle(color: Colors.black54)));
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _localInspectors.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, idx) {
        final r = _localInspectors[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Tooltip(
                  message: r['id'] ?? '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['inspectorNo'] ?? r['id'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if ((r['inspectorNo']) != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          r['id'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: Text(r['firstName'] ?? r['displayName'] ?? '')),
              Expanded(child: Text(r['lastName'] ?? '')),
              Expanded(child: Text(r['phone'] ?? '', style: const TextStyle(color: Colors.black54))),
              Expanded(child: Text(r['email'] ?? '', style: const TextStyle(color: Colors.black54))),
              SizedBox(width: 140, child: Text(r['role'] ?? '', textAlign: TextAlign.center)),
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () {
                          // Placeholder: editing not implemented in offline demo
                        },
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0B63B7))),
                        child: const Text('Edit', style: TextStyle(color: Color(0xFF0B63B7)), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFB00020)),
                        tooltip: 'Delete inspector',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Confirm delete'),
                              content: Text('Delete inspector "${r['displayName'] ?? r['firstName'] ?? ''}"? This will remove the local placeholder entry.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          setState(() {
                            _localInspectors.removeWhere((e) => e['id'] == r['id']);
                          });
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspector deleted (local placeholder)')));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF6FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0B63B7)),
                  onPressed: () {
                    if (widget.onClose != null) widget.onClose!();
                  },
                ),
                const SizedBox(width: 8),
                const Text('Staff', style: TextStyle(color: Color(0xFF0B63B7), fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showAddInspectorDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Inspector'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search/filter row (kept minimal)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) {
                            // implement local filtering if desired
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                        child: const Text('Filter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // table: listen to inspectors collection
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF0B63B7)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Container(
                            color: const Color(0xFFF7FBFF),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: const [
                                SizedBox(width: 140, child: Text('Inspector No.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('First Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Last Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                SizedBox(width: 140, child: Text('Role', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                SizedBox(width: 120, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                              ],
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('inspectors').orderBy('inspectorNo').snapshots(),
                              builder: (context, snap) {
                                if (snap.hasError) {
                                  // On error, show local placeholders
                                  return _buildInspectorListFromLocal();
                                }

                                if (!snap.hasData) {
                                  // still loading — show placeholders while waiting
                                  return _buildInspectorListFromLocal();
                                }

                                final docs = snap.data!.docs;
                                if (docs.isEmpty) return _buildInspectorListFromLocal();

                                return ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                  itemBuilder: (context, idx) {
                                    final d = docs[idx];
                                    final r = (d.data() as Map<String, dynamic>? ?? {})..['id'] = d.id;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 140,
                                            child: Tooltip(
                                              message: d.id,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    (r['inspectorNo'] ?? d.id).toString(),
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    d.id,
                                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(child: Text(r['firstName'] ?? r['displayName'] ?? '')),
                                          Expanded(child: Text(r['lastName'] ?? '')),
                                          Expanded(child: Text(r['phone'] ?? '', style: const TextStyle(color: Colors.black54))),
                                          Expanded(child: Text(r['email'] ?? '', style: const TextStyle(color: Colors.black54))),
                                          SizedBox(width: 140, child: Text(r['role'] ?? '', textAlign: TextAlign.center)),
                                          SizedBox(
                                            width: 120,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  height: 34,
                                                  child: OutlinedButton(
                                                    onPressed: () {
                                                      // editing not implemented in this demo
                                                    },
                                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0B63B7))),
                                                    child: const Text('Edit', style: TextStyle(color: Color(0xFF0B63B7)), overflow: TextOverflow.ellipsis),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFB00020)),
                                                    tooltip: 'Delete inspector',
                                                    onPressed: () async {
                                                      final confirm = await showDialog<bool>(
                                                        context: context,
                                                        builder: (c) => AlertDialog(
                                                          title: const Text('Confirm delete'),
                                                          content: Text('Delete inspector "${r['displayName'] ?? r['firstName'] ?? ''}"?'),
                                                          actions: [
                                                            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                                            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm != true) return;

                                                      try {
                                                        await FirebaseFirestore.instance.collection('inspectors').doc(d.id).delete();
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspector deleted')));
                                                      } catch (e) {
                                                        // fallback: remove from locals
                                                        setState(() {
                                                          _localInspectors.removeWhere((e) => e['id'] == d.id);
                                                        });
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspector deleted (local fallback)')));
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
