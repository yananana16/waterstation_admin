import 'package:flutter/material.dart';

class InspectionPage extends StatefulWidget {
  final VoidCallback? onClose;
  const InspectionPage({super.key, this.onClose});

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  final List<Map<String, String>> _all = [
    {'no': '1', 'station': 'Crystal Clear Refills', 'location': 'La Paz', 'date': 'May 5, 2025', 'officer': 'M. Cruz', 'status': 'Done'},
    {'no': '2', 'station': 'HydroPure Station', 'location': 'Lapuz', 'date': 'May 5, 2025', 'officer': 'A. Santos', 'status': 'Done'},
    {'no': '3', 'station': 'EverFresh Water Refilling', 'location': 'City Proper 1', 'date': 'May 5, 2025', 'officer': 'P. Reyes', 'status': 'Done'},
    {'no': '4', 'station': 'AquaPrime Refilling Station', 'location': 'Mandurriao', 'date': 'May 6, 2025', 'officer': 'T. Andres', 'status': 'Pending'},
    {'no': '5', 'station': 'HydroPure H2O Haven', 'location': 'La Paz', 'date': 'May 6, 2025', 'officer': 'J. Alonzo', 'status': 'Pending'},
  ];

  String _query = '';
  String _statusFilter = 'All';
  int _page = 0;
  final int _perPage = 3;

  List<Map<String, String>> get _filtered {
    final q = _query.toLowerCase().trim();
    var list = _all.where((m) {
      final matchQuery = q.isEmpty ||
          m.values.any((v) => v.toLowerCase().contains(q));
      final matchStatus = _statusFilter == 'All' || m['status'] == _statusFilter;
      return matchQuery && matchStatus;
    }).toList();
    return list;
  }

  List<Map<String, String>> get _paged {
    final f = _filtered;
    final start = _page * _perPage;
    if (start >= f.length) return [];
    final end = (start + _perPage).clamp(0, f.length);
    return f.sublist(start, end);
  }

  void _nextPage() {
    final maxPage = ((_filtered.length - 1) / _perPage).floor();
    setState(() {
      if (_page < maxPage) _page++;
    });
  }

  void _prevPage() {
    setState(() {
      if (_page > 0) _page--;
    });
  }

  void _setFilter(String s) {
    setState(() {
      _statusFilter = s;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paged = _paged;
    final totalPages = ((_filtered.length - 1) / _perPage).floor() + 1;

    // Render as a flexible subscreen within schedule_page
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          // header inside subscreen
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
                const Text('Inspection', style: TextStyle(color: Color(0xFF0B63B7), fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Search + Filter row
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
                            onChanged: (v) => setState(() {
                              _query = v;
                              _page = 0;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _statusFilter,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                            DropdownMenuItem(value: 'Done', child: Text('Done')),
                            DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          ],
                          onChanged: (v) {
                            if (v != null) _setFilter(v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Table header
                    Container(
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
                                SizedBox(width: 36, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Station', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Officer', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                SizedBox(width: 90, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                              ],
                            ),
                          ),
                          // rows
                          if (paged.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Center(child: Text('No records found', style: TextStyle(color: Colors.black54))),
                            )
                          else
                            ...paged.map((row) => Container(
                                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF0B63B7)))),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 36, child: Text(row['no'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                      Expanded(child: Text(row['station'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                      Expanded(child: Text(row['location'] ?? '', style: const TextStyle(color: Colors.black54))),
                                      Expanded(child: Text(row['date'] ?? '', style: const TextStyle(color: Colors.black54))),
                                      Expanded(child: Text(row['officer'] ?? '', style: const TextStyle(color: Colors.black54))),
                                      SizedBox(
                                        width: 90,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: row['status'] == 'Done' ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              row['status'] ?? '',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Pagination controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Page ${_page + 1} of ${_filtered.isEmpty ? 0 : totalPages}', style: const TextStyle(color: Colors.black54)),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _page > 0 ? _prevPage : null,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                              child: const Text('Back'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: (_page + 1) < totalPages ? _nextPage : null,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                              child: const Text('Next'),
                            ),
                          ],
                        )
                      ],
                    )
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

