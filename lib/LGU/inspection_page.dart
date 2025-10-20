import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InspectionPage extends StatefulWidget {
  final VoidCallback? onClose;
  const InspectionPage({super.key, this.onClose});

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  // Month selector (use current month by default)
  DateTime _selectedMonth = DateTime.now();

  // Search / filter / paging state
  String _query = '';
  String _statusFilter = 'All';
  int _page = 0;
  final int _perPage = 10;

  // Cache for per-station month status (key: stationId::YYYY-MM)
  final Map<String, String> _monthStatusCache = {};
  // Cache for per-station officer name for the month (key: stationId::YYYY-MM)
  final Map<String, String> _monthOfficerCache = {};

  String _monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

  String _normalizeStatus(dynamic raw) {
    try {
      if (raw == null) return 'Pending';
      final s = raw.toString().toLowerCase().trim();
      if (s.contains('done') || s.contains('complete') || s.contains('completed')) return 'Done';
      if (s.contains('pending') || s.contains('todo') || s.contains('scheduled')) return 'Pending';
      if (s == 'true') return 'Done';
      if (s == 'false') return 'Pending';
    } catch (_) {}
    return 'Pending';
  }

  // Check inspections under station subcollection or top-level collection for given month.
  Future<String> _getMonthStatus(String stationId, DateTime month) async {
    final mk = _monthKey(month);
    final cacheKey = '$stationId::$mk';
    if (_monthStatusCache.containsKey(cacheKey)) return _monthStatusCache[cacheKey]!;

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));
    final firestore = FirebaseFirestore.instance;

    try {
      final subByMonth = firestore
          .collection('station_owners')
          .doc(stationId)
          .collection('inspections')
          .where('monthlyInspectionMonth', isEqualTo: mk)
          .limit(1);
      final subByMonthSnap = await subByMonth.get();
      if (subByMonthSnap.docs.isNotEmpty) {
        final data = subByMonthSnap.docs.first.data();
        final status = _normalizeStatus(data['status'] ?? data['state'] ?? data['statusText']);
        final officerName = (data['officerName'] ?? data['officer'] ?? data['officer_full_name'])?.toString() ?? '';
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        return status;
      }

      final subByDate = firestore
          .collection('station_owners')
          .doc(stationId)
          .collection('inspections')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .limit(1);
      final subByDateSnap = await subByDate.get();
      if (subByDateSnap.docs.isNotEmpty) {
        final data = subByDateSnap.docs.first.data();
        final status = _normalizeStatus(data['status'] ?? data['state'] ?? data['statusText']);
        final officerName = (data['officerName'] ?? data['officer'] ?? data['officer_full_name'])?.toString() ?? '';
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        return status;
      }

      final topByMonth = firestore.collection('inspections').where('stationId', isEqualTo: stationId).where('monthlyInspectionMonth', isEqualTo: mk).limit(1);
      final topByMonthSnap = await topByMonth.get();
      if (topByMonthSnap.docs.isNotEmpty) {
        final data = topByMonthSnap.docs.first.data();
        final status = _normalizeStatus(data['status'] ?? data['state'] ?? data['statusText']);
        final officerName = (data['officerName'] ?? data['officer'] ?? data['officer_full_name'])?.toString() ?? '';
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        return status;
      }

      final topByDate = firestore.collection('inspections').where('stationId', isEqualTo: stationId).where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart)).where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd)).limit(1);
      final topByDateSnap = await topByDate.get();
      if (topByDateSnap.docs.isNotEmpty) {
        final data = topByDateSnap.docs.first.data();
        final status = _normalizeStatus(data['status'] ?? data['state'] ?? data['statusText']);
        final officerName = (data['officerName'] ?? data['officer'] ?? data['officer_full_name'])?.toString() ?? '';
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        return status;
      }
    } catch (e) {
      debugPrint('Error checking inspections for station: $stationId -> $e');
    }
    _monthStatusCache[cacheKey] = 'Pending';
    _monthOfficerCache[cacheKey] = '';
    return 'Pending';
  }

  // Ensure statuses for a list of rows (calls _getMonthStatus for uncached entries).
  Future<List<String>> _ensureStatusesForRows(List<Map<String, String>> rows) async {
    final futures = rows.map((r) => _getMonthStatus(r['id']!, _selectedMonth));
    return await Future.wait(futures);
  }

  void _nextPage() {
    setState(() {
      _page++;
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
    // Render as a flexible subscreen within schedule_page, but source stations from Firestore
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
                // optional month selector
                    TextButton.icon(
                      onPressed: () async {
                        // Use showDatePicker and normalize to first day of selected month
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedMonth,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (pickedDate != null) {
                          final monthOnly = DateTime(pickedDate.year, pickedDate.month, 1);
                          setState(() => _selectedMonth = monthOnly);
                        }
                      },
                      icon: const Icon(Icons.calendar_month, color: Color(0xFF0B63B7)),
                      label: Text('${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}', style: const TextStyle(color: Color(0xFF0B63B7))),
                    ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('station_owners').orderBy('stationName').snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data?.docs ?? [];
                  // Map docs to rows
                  final rows = List.generate(docs.length, (index) {
                    final d = docs[index].data() as Map<String, dynamic>;
                    return {
                      'id': docs[index].id,
                      'no': '${index + 1}',
                      'station': d['stationName']?.toString() ?? d['station']?.toString() ?? 'Unknown',
                      'location': d['districtName']?.toString() ?? d['location']?.toString() ?? '',
                      'date': d['lastInspectionDate']?.toString() ?? '',
                      'officer': d['assignedOfficer']?.toString() ?? '',
                    };
                  });

                  // Apply textual search first to reduce status lookups
                  final q = _query.toLowerCase().trim();
                  var preFiltered = rows.where((m) => q.isEmpty || m.values.any((v) => v.toLowerCase().contains(q))).toList();

                  return FutureBuilder<List<String>>(
                    future: _ensureStatusesForRows(preFiltered),
                    builder: (context, sSnap) {
                      if (sSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final statuses = sSnap.data ?? List.filled(preFiltered.length, 'Pending');

                      // Combine statuses into rows
                      final combined = <Map<String, String>>[];
                      for (var i = 0; i < preFiltered.length; i++) {
                        final r = Map<String, String>.from(preFiltered[i]);
                        r['status'] = statuses[i];
                        // set officer from cache if available (only when an inspection exists for the month)
                        final cacheKey = '${r['id']}::${_monthKey(_selectedMonth)}';
                        final officer = _monthOfficerCache.containsKey(cacheKey) ? (_monthOfficerCache[cacheKey] ?? '') : '';
                        r['officer'] = officer;
                        combined.add(r);
                      }

                      // Apply status filter now (All means keep all)
                      final filtered = _statusFilter == 'All' ? combined : combined.where((r) => r['status'] == _statusFilter).toList();

                      final totalPages = filtered.isEmpty ? 1 : ((filtered.length - 1) / _perPage).floor() + 1;
                      final start = (_page * _perPage).clamp(0, filtered.length);
                      final end = ((_page * _perPage) + _perPage).clamp(0, filtered.length);
                      final paged = (start >= end) ? <Map<String, String>>[] : filtered.sublist(start, end).cast<Map<String, String>>();

                      return Column(
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
                          // Table header + scrollable rows
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
                                        SizedBox(width: 36, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                        Expanded(child: Text('Station', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                        Expanded(child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                        Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                        Expanded(child: Text('Officer', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                        SizedBox(width: 90, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                      ],
                                    ),
                                  ),
                                  // rows area
                                  Expanded(
                                    child: paged.isEmpty
                                        ? Container(
                                            padding: const EdgeInsets.all(20),
                                            child: const Center(child: Text('No records found', style: TextStyle(color: Colors.black54))),
                                          )
                                        : ListView.separated(
                                            itemCount: paged.length,
                                            separatorBuilder: (_, __) => const Divider(height: 0, color: Color(0xFF0B63B7)),
                                            itemBuilder: (context, idx) {
                                              final row = paged[idx];
                                              final status = row['status'] ?? 'Pending';
                                              return Container(
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
                                                            color: status == 'Done' ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            status,
                                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                          ),
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
                          ),
                          const SizedBox(height: 12),
                          // Pagination controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Page ${_page + 1} of ${filtered.isEmpty ? 0 : totalPages}', style: const TextStyle(color: Colors.black54)),
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
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

