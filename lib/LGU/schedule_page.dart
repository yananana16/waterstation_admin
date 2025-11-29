import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inspection_page.dart'; // added import
import 'add_schedule_subscreen.dart';
import 'staff_subscreen.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

enum _ActiveSubscreen { none, inspection, addSchedule, assignment, staff } // added staff

class _SchedulePageState extends State<SchedulePage> {
  _ActiveSubscreen _activeSubscreen = _ActiveSubscreen.none;
  // Monthly inspection state
  DateTime _selectedMonth = DateTime.now();

  // We'll load stations from Firestore (collection: 'station_owners').
  // Cache per-station month-inspection status to reduce queries on rebuilds.
  final Map<String, String> _monthStatusCache = {}; // key: stationId::YYYY-MM -> 'done'|'pending'
  // Cache for per-station officer name for the month (key: stationId::YYYY-MM)
  final Map<String, String> _monthOfficerCache = {};
  // Cache for per-station inspection date for the month (string)
  final Map<String, String> _monthDateCache = {};

  String _formatDateField(dynamic value) {
    try {
      if (value == null) return '';
      if (value is Timestamp) {
        final dt = value.toDate().toLocal();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
      if (value is DateTime) {
        final dt = value.toLocal();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) {
        final dt = parsed.toLocal();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
      return value.toString();
    } catch (_) {
      return value.toString();
    }
  }

  String _monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

  // Normalize potential status values coming from Firestore documents to
  // either 'done' or 'pending'. Accepts nulls and various field names.
  String _normalizeStatus(dynamic raw) {
    try {
      if (raw == null) return 'pending';
      final s = raw.toString().toLowerCase().trim();
      if (s.contains('done') || s.contains('complete') || s.contains('completed')) return 'done';
      if (s.contains('pending') || s.contains('todo') || s.contains('scheduled')) return 'pending';
      // some documents store booleans
      if (s == 'true') return 'done';
      if (s == 'false') return 'pending';
    } catch (_) {}
    return 'pending';
  }

  // Query Firestore to determine if a station has an inspection for the given month.
  // This supports both a subcollection 'inspections' under station doc, or a top-level
  // collection 'inspections' with a field 'stationId'. We try subcollection first for efficiency.
  Future<String> _getMonthStatus(String stationId, DateTime month) async {
  final mk = _monthKey(month);
  final cacheKey = '$stationId::$mk';
    if (_monthStatusCache.containsKey(cacheKey)) return _monthStatusCache[cacheKey]!;

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

    final firestore = FirebaseFirestore.instance;

    try {
      // 1) Prefer station subcollection documents that explicitly mark the monthlyInspectionMonth
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
        final dateStr = _formatDateField(data['date'] ?? data['createdAt'] ?? data['inspectionDate']);
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        _monthDateCache[cacheKey] = dateStr;
        return status;
      }

      // 1b) Fallback: search subcollection by date range (some docs use a 'date' or 'createdAt' field)
      final subByDate = firestore.collection('station_owners').doc(stationId).collection('inspections')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .limit(1);
      final subByDateSnap = await subByDate.get();
      if (subByDateSnap.docs.isNotEmpty) {
        final data = subByDateSnap.docs.first.data();
        final status = _normalizeStatus(data['status'] ?? data['state'] ?? data['statusText']);
        final officerName = (data['officerName'] ?? data['officer'] ?? data['officer_full_name'])?.toString() ?? '';
        final dateStr = _formatDateField(data['date'] ?? data['createdAt'] ?? data['inspectionDate']);
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        _monthDateCache[cacheKey] = dateStr;
        return status;
      }

      // 2) Try top-level collection 'inspections' with an explicit monthlyInspectionMonth
      final topByMonth = firestore.collection('inspections')
          .where('stationId', isEqualTo: stationId)
          .where('monthlyInspectionMonth', isEqualTo: mk)
          .limit(1);
      final topByMonthSnap = await topByMonth.get();
      if (topByMonthSnap.docs.isNotEmpty) {
        final data = topByMonthSnap.docs.first.data();
        final status = _normalizeStatus(data['status'] ?? data['state'] ?? data['statusText']);
        final officerName = (data['officerName'] ?? data['officer'] ?? data['officer_full_name'])?.toString() ?? '';
        final dateStr = _formatDateField(data['date'] ?? data['createdAt'] ?? data['inspectionDate']);
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        _monthDateCache[cacheKey] = dateStr;
        return status;
      }

      // 2b) Fallback: top-level search by date range
      final topByDate = firestore.collection('inspections')
          .where('stationId', isEqualTo: stationId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .limit(1);
      final topByDateSnap = await topByDate.get();
      if (topByDateSnap.docs.isNotEmpty) {
        final data = topByDateSnap.docs.first.data();
        final status = _normalizeStatus(data['status'] ?? data['state'] ?? data['statusText']);
        final officerName = (data['officerName'] ?? data['officer'] ?? data['officer_full_name'])?.toString() ?? '';
        final dateStr = _formatDateField(data['date'] ?? data['createdAt'] ?? data['inspectionDate']);
        _monthStatusCache[cacheKey] = status;
        _monthOfficerCache[cacheKey] = officerName;
        _monthDateCache[cacheKey] = dateStr;
        return status;
      }
    } catch (e) {
      // on error, default to Pending but do not crash UI
      debugPrint('Error checking inspections for station: $stationId -> $e');
    }
    _monthStatusCache[cacheKey] = 'pending';
    _monthOfficerCache[cacheKey] = '';
    _monthDateCache[cacheKey] = '';
    return 'pending';
  }

  void _openInspection() => setState(() => _activeSubscreen = _ActiveSubscreen.inspection);
  void _openAddSchedule() => setState(() => _activeSubscreen = _ActiveSubscreen.addSchedule);
  // assignment action removed (Assign quick action was removed from UI)
  void _openStaff() => setState(() => _activeSubscreen = _ActiveSubscreen.staff); // new
  void _closeSubscreen() => setState(() => _activeSubscreen = _ActiveSubscreen.none);

  @override
  Widget build(BuildContext context) {
  final mq = MediaQuery.of(context);
  final w = mq.size.width;
    // scale based on a 1200px reference width, clamped to reasonable range
    final scale = (w / 1200).clamp(0.75, 1.2);
    final horizontalPadding = (w * 0.03).clamp(12.0, 48.0);
    final sectionSpacing = (w * 0.02).clamp(12.0, 28.0);
  final headerFontSize = 22.0 * scale;

    // inspectionRows replaced by dynamic per-station per-month schedule
    // sample assigned inspectors counts for quick right-column card
    final assignedLocations = [
      {'name': 'La Paz', 'count': 12},
      {'name': 'Mandurriao', 'count': 9},
      {'name': 'Molo', 'count': 10},
      {'name': 'Lapuz', 'count': 8},
      {'name': 'Arevalo', 'count': 11},
    ];
    return Column(
      children: [
        // Main content
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: _activeSubscreen == _ActiveSubscreen.inspection
                ? InspectionPage(onClose: _closeSubscreen)
                : _activeSubscreen == _ActiveSubscreen.addSchedule
                    ? AddScheduleSubscreen(onClose: _closeSubscreen)
                    : _activeSubscreen == _ActiveSubscreen.assignment
                        ? AssignmentSubscreen(onClose: _closeSubscreen)
                        : _activeSubscreen == _ActiveSubscreen.staff
                            ? StaffSubscreen(onClose: _closeSubscreen)
                            : LayoutBuilder(builder: (context, constraints) {
                                // allow layout to adapt: when narrow, stack vertically
                                final isNarrow = constraints.maxWidth < 900;
                                final availableHeight = constraints.maxHeight;
                                return isNarrow
                                    ? SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            // Quick Access buttons for mobile
                                            Container(
                                              padding: EdgeInsets.all(16 * scale),
                                              margin: EdgeInsets.only(bottom: 16 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12 * scale),
                                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Quick Access', style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7))),
                                                  SizedBox(height: 16 * scale),
                                                  Wrap(
                                                    spacing: 16,
                                                    runSpacing: 16,
                                                    alignment: WrapAlignment.spaceEvenly,
                                                    children: [
                                                      _ScheduleActionButton(icon: Icons.check_circle, label: 'Inspection', onPressed: _openInspection, scale: scale),
                                                      _ScheduleActionButton(icon: Icons.calendar_month, label: 'Add', scale: scale, onPressed: _openAddSchedule),
                                                      _ScheduleActionButton(icon: Icons.people, label: 'Staff', onPressed: _openStaff, scale: scale),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Inspection preview for mobile
                                            Container(
                                              padding: EdgeInsets.all(16 * scale),
                                              margin: EdgeInsets.only(bottom: 16 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12 * scale),
                                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text('Inspection', style: TextStyle(color: const Color(0xFF0B63B7), fontWeight: FontWeight.bold, fontSize: 18 * scale)),
                                                      TextButton(
                                                        onPressed: _openInspection,
                                                        child: Text('See More', style: TextStyle(color: const Color(0xFF0B63B7), decoration: TextDecoration.underline)),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 8 * scale),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${_selectedMonth.year} • ${_selectedMonth.month.toString().padLeft(2, '0')}',
                                                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500, fontSize: 14 * scale),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      OutlinedButton(
                                                        onPressed: () async {
                                                          final picked = await showDatePicker(
                                                            context: context,
                                                            initialDate: _selectedMonth,
                                                            firstDate: DateTime(2020),
                                                            lastDate: DateTime(2030),
                                                            helpText: 'Select month',
                                                          );
                                                          if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month));
                                                        },
                                                        child: const Text('Change'),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 12 * scale),
                                                  // Preview list (show first few items)
                                                  StreamBuilder<QuerySnapshot>(
                                                    stream: FirebaseFirestore.instance.collection('station_owners').orderBy('districtName').limit(5).snapshots(),
                                                    builder: (context, snap) {
                                                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                                      final docs = snap.data!.docs;
                                                      if (docs.isEmpty) return const Center(child: Text('No stations'));
                                                      return Column(
                                                        children: docs.map((doc) {
                                                          final sId = doc.id;
                                                          final sName = (doc.data() as Map<String, dynamic>)['stationName'] ?? 'Unknown';
                                                          final sLoc = (doc.data() as Map<String, dynamic>)['districtName'] ?? '';
                                                          return Container(
                                                            margin: EdgeInsets.only(bottom: 8 * scale),
                                                            padding: EdgeInsets.all(12 * scale),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFF7FBFF),
                                                              borderRadius: BorderRadius.circular(8 * scale),
                                                              border: Border.all(color: const Color(0xFFE0E0E0)),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text(sName.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * scale), overflow: TextOverflow.ellipsis),
                                                                      SizedBox(height: 4 * scale),
                                                                      Text(sLoc.toString(), style: TextStyle(color: Colors.black54, fontSize: 12 * scale), overflow: TextOverflow.ellipsis),
                                                                    ],
                                                                  ),
                                                                ),
                                                                FutureBuilder<String>(
                                                                  future: _getMonthStatus(sId, _selectedMonth),
                                                                  builder: (context, statusSnap) {
                                                                    final raw = statusSnap.data ?? 'pending';
                                                                    final status = raw.toString().toLowerCase();
                                                                    final display = status.isNotEmpty ? (status[0].toUpperCase() + status.substring(1)) : 'Pending';
                                                                    return Container(
                                                                      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                                                                      decoration: BoxDecoration(
                                                                        color: (status == 'done') ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                                                                        borderRadius: BorderRadius.circular(6 * scale),
                                                                      ),
                                                                      child: Text(display, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11 * scale)),
                                                                    );
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Assigned Inspectors for mobile
                                            Container(
                                              padding: EdgeInsets.all(16 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12 * scale),
                                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Number of Assigned Inspectors', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 16 * scale)),
                                                  SizedBox(height: 12 * scale),
                                                  ...assignedLocations.map((loc) => Padding(
                                                        padding: EdgeInsets.symmetric(vertical: 6 * scale),
                                                        child: Row(
                                                          children: [
                                                            Expanded(child: Text(loc['name'].toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale))),
                                                            Container(
                                                              padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
                                                              decoration: BoxDecoration(color: const Color(0xFF0B63B7), borderRadius: BorderRadius.circular(6 * scale)),
                                                              child: Text(loc['count'].toString(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14 * scale)),
                                                            )
                                                          ],
                                                        ),
                                                      )),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Inspection Table (left)
                                          Expanded(
                                            flex: 6,
                                            child: Container(
                                              padding: EdgeInsets.all(18 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12 * scale),
                                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4 * scale,
                                                    offset: Offset(0, 2 * scale),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Inspection',
                                                    style: TextStyle(
                                                      color: const Color(0xFF0B63B7),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: headerFontSize,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6 * scale),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${_selectedMonth.year} • ${_selectedMonth.month.toString().padLeft(2, '0')}',
                                                        style: TextStyle(
                                                          color: Colors.black54,
                                                          fontWeight: FontWeight.w500,
                                                          fontSize: 14 * scale,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      OutlinedButton(
                                                        onPressed: () async {
                                                          // pick month (rudimentary month picker using showDatePicker)
                                                          final picked = await showDatePicker(
                                                            context: context,
                                                            initialDate: _selectedMonth,
                                                            firstDate: DateTime(2020),
                                                            lastDate: DateTime(2030),
                                                            helpText: 'Select month (pick any day in month)',
                                                          );
                                                          if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month));
                                                        },
                                                        child: const Text('Change month'),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 12 * scale),
                                                  // Bordered table: give table area a max height and make rows scrollable
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: const Color(0xFF0B63B7)),
                                                    ),
                                                    // bound the table area so its internal ListView can scroll without overflowing
                                                    child: SizedBox(
                                                      height: (availableHeight * 0.62).clamp(220.0, availableHeight - 80.0),
                                                      child: Column(
                                                        children: [
                                                          // header row (fixed)
                                                          Container(
                                                            color: const Color(0xFFF7FBFF),
                                                            padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 8 * scale),
                                                            child: Row(
                                                              children: [
                                                                SizedBox(width: 28 * scale, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale))),
                                                                Expanded(child: Text('Station', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale))),
                                                                Expanded(child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale))),
                                                                Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale))),
                                                                Expanded(child: Text('Officer', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale))),
                                                                SizedBox(width: 80 * scale, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale))),
                                                              ],
                                                            ),
                                                          ),
                                                          // rows (scrollable) - build from _stations & _schedule for selected month
                                                          Expanded(
                                                            child: StreamBuilder<QuerySnapshot>(
                                                              stream: FirebaseFirestore.instance.collection('station_owners').orderBy('districtName').snapshots(),
                                                              builder: (context, snap) {
                                                                if (snap.hasError) return Center(child: Text('Error loading stations'));
                                                                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                                                final docs = snap.data!.docs;
                                                                if (docs.isEmpty) return const Center(child: Text('No stations'));
                                                                return ListView.separated(
                                                                  physics: const AlwaysScrollableScrollPhysics(),
                                                                  padding: EdgeInsets.zero,
                                                                  itemCount: docs.length,
                                                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF0B63B7)),
                                                                  itemBuilder: (context, idx) {
                                                                    final doc = docs[idx];
                                                                    final sId = doc.id;
                                                                    final sName = (doc.data() as Map<String, dynamic>)['stationName'] ?? (doc.data() as Map<String, dynamic>)['displayName'] ?? 'Unknown';
                                                                    final sLoc = (doc.data() as Map<String, dynamic>)['districtName'] ?? '';
                                                                    return Padding(
                                                                      padding: EdgeInsets.symmetric(vertical: 14 * scale, horizontal: 8 * scale),
                                                                      child: Row(
                                                                        children: [
                                                                          SizedBox(width: 28 * scale, child: Text('${idx + 1}', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13 * scale))),
                                                                          Expanded(child: Text(sName.toString(), style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13 * scale))),
                                                                          Expanded(child: Text(sLoc.toString(), style: TextStyle(color: Colors.black54, fontSize: 13 * scale))),
                                                                          Expanded(
                                                                            child: Builder(builder: (ctx) {
                                                                              final cacheKey = '$sId::${_monthKey(_selectedMonth)}';
                                                                              final dateText = _monthDateCache.containsKey(cacheKey) ? (_monthDateCache[cacheKey] ?? '') : '';
                                                                              return Text(dateText, style: TextStyle(color: Colors.black54, fontSize: 13 * scale));
                                                                            }),
                                                                          ),
                                                                          // Officer: show officerName from cache if an inspection exists for the month
                                                                          Expanded(
                                                                            child: Builder(builder: (ctx) {
                                                                              final cacheKey = '$sId::${_monthKey(_selectedMonth)}';
                                                                              final officer = _monthOfficerCache.containsKey(cacheKey) ? (_monthOfficerCache[cacheKey] ?? '') : '';
                                                                              return Text(officer, style: TextStyle(color: Colors.black54, fontSize: 13 * scale));
                                                                            }),
                                                                          ),
                                                                          SizedBox(
                                                                            width: 80 * scale,
                                                                            child: Center(
                                                                              child: FutureBuilder<String>(
                                                                                future: _getMonthStatus(sId, _selectedMonth),
                                                                                builder: (context, statusSnap) {
                                                                                  final raw = statusSnap.data ?? 'pending';
                                                                                  final status = raw.toString().toLowerCase();
                                                                                  final display = status.isNotEmpty ? (status[0].toUpperCase() + status.substring(1)) : 'Pending';
                                                                                  return Container(
                                                                                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                                                                                    decoration: BoxDecoration(
                                                                                      color: (status == 'done') ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                                                                                      borderRadius: BorderRadius.circular(6 * scale),
                                                                                    ),
                                                                                    child: Text(display, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * scale)),
                                                                                  );
                                                                                },
                                                                              ),
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
                                                  SizedBox(height: 12 * scale),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: GestureDetector(
                                                      onTap: _openInspection,
                                                      child: Text(
                                                        'See More',
                                                        style: TextStyle(
                                                          color: const Color(0xFF0B63B7),
                                                          fontWeight: FontWeight.bold,
                                                          decoration: TextDecoration.underline,
                                                          fontSize: 14 * scale,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: sectionSpacing),
                                          // Right column: Quick Access + compact calendar
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(12 * scale),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(12 * scale),
                                                    border: Border.all(color: const Color(0xFFE0E0E0)),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Quick Access', style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7))),
                                                      SizedBox(height: 12 * scale),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                        children: [
                                                          _ScheduleActionButton(
                                                            icon: Icons.check_circle,
                                                            label: 'Inspection',
                                                            onPressed: _openInspection,
                                                            scale: scale,
                                                          ),
                                                          _ScheduleActionButton(icon: Icons.calendar_month, label: 'Add', scale: scale, onPressed: _openAddSchedule),
                                                          _ScheduleActionButton(icon: Icons.people, label: 'Staff', onPressed: _openStaff, scale: scale),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(height: 18 * scale),
                                                // Number of Assigned Inspectors card (inserted below Quick Access)
                                                Container(
                                                  padding: EdgeInsets.all(12 * scale),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(12 * scale),
                                                    border: Border.all(color: const Color(0xFFE0E0E0)),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Number of Assigned Inspectors', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale)),
                                                      SizedBox(height: 12 * scale),
                                                      ...assignedLocations.map((loc) => Padding(
                                                            padding: EdgeInsets.symmetric(vertical: 6 * scale),
                                                            child: Row(
                                                              children: [
                                                                Expanded(child: Text(loc['name'].toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale))),
                                                                SizedBox(width: 8 * scale),
                                                                Container(
                                                                  padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
                                                                  decoration: BoxDecoration(color: const Color(0xFF0B63B7), borderRadius: BorderRadius.circular(6 * scale)),
                                                                  child: Text(loc['count'].toString(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14 * scale)),
                                                                )
                                                              ],
                                                            ),
                                                          )),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                          }),
          ),
        ),
        // Action buttons (kept minimal below)
        Padding(
          padding: EdgeInsets.only(bottom: 18 * scale, left: horizontalPadding, right: horizontalPadding),
        ),
      ],
    );
  }
}

// Schedule action button now accepts scale param and uses flexible sizing.
class _ScheduleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double scale;
  const _ScheduleActionButton({required this.icon, required this.label, this.onPressed, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28 * scale,
            backgroundColor: const Color(0xFFEAF6FF),
            child: Icon(icon, color: const Color(0xFF0B63B7), size: 32 * scale),
          ),
          SizedBox(height: 8 * scale),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF0B63B7),
              fontWeight: FontWeight.w500,
              fontSize: 14 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

// AddScheduleSubscreen moved to its own file: lib/LGU/add_schedule_subscreen.dart

// AssignmentSubscreen: use flexible left width and responsive paddings/sizes.
class AssignmentSubscreen extends StatefulWidget {
  final VoidCallback? onClose;
  const AssignmentSubscreen({super.key, this.onClose});

  @override
  State<AssignmentSubscreen> createState() => _AssignmentSubscreenState();
}

class _AssignmentSubscreenState extends State<AssignmentSubscreen> {
  final List<Map<String, dynamic>> _locations = [
    {'name': 'La Paz', 'count': 12},
    {'name': 'Mandurriao', 'count': 9},
    {'name': 'Molo', 'count': 10},
    {'name': 'Lapuz', 'count': 8},
    {'name': 'Arevalo', 'count': 11},
  ];

  final List<Map<String, String>> _rows = [
    {'no': '1', 'officer': 'Maria Santos', 'location': 'La Paz, Iloilo City', 'date': 'May 6, 2025', 'status': 'Done'},
    {'no': '2', 'officer': 'Luis Dela Cruz', 'location': 'La Paz, Iloilo City', 'date': 'May 5, 2025', 'status': 'Done'},
    {'no': '3', 'officer': 'Ramon Garcia', 'location': 'La Paz, Iloilo City', 'date': 'May 5, 2025', 'status': 'Done'},
    {'no': '4', 'officer': 'Teresa Mendoza', 'location': 'La Paz, Iloilo City', 'date': 'May 6, 2025', 'status': 'Pending'},
    {'no': '5', 'officer': 'Elena Villanueva', 'location': 'La Paz, Iloilo City', 'date': 'May 6, 2025', 'status': 'Pending'},
  ];

  int _page = 0;
  final int _perPage = 3;

  List<Map<String, String>> get _paged {
    final start = _page * _perPage;
    final end = (start + _perPage).clamp(0, _rows.length);
    if (start >= _rows.length) return [];
    return _rows.sublist(start, end).cast<Map<String, String>>();
  }

  void _nextPage() {
    final maxPage = ((_rows.length - 1) / _perPage).floor();
    setState(() {
      if (_page < maxPage) _page++;
    });
  }

  void _prevPage() {
    setState(() {
      if (_page > 0) _page--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 1200).clamp(0.75, 1.2);
    final leftWidth = (w * 0.22).clamp(160.0, 320.0);

    final paged = _paged;
    final totalPages = ((_rows.length - 1) / _perPage).floor() + 1;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8 * scale),
      child: Column(
        children: [
          // header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
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
                const Text('Assignment', style: TextStyle(color: Color(0xFF0B63B7), fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left stats column (responsive width)
                  Container(
                    width: leftWidth,
                    padding: EdgeInsets.all(16 * scale),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8 * scale),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Number of Assigned Inspectors', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 14 * scale)),
                        SizedBox(height: 12 * scale),
                        ..._locations.map((loc) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(child: Text(loc['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: const Color(0xFF0B63B7), borderRadius: BorderRadius.circular(6)),
                                    child: Text('${loc['count']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  SizedBox(width: 20 * scale),
                  // Right table (flexible)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8 * scale),
                        border: Border.all(color: const Color(0xFF0B63B7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LA PAZ', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7), fontSize: 16 * scale)),
                          SizedBox(height: 12 * scale),
                          // table header with responsive spacing and font sizes
                          Container(
                            color: const Color(0xFFF7FBFF),
                            padding: EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 8 * scale),
                            child: Row(
                              children: [
                                SizedBox(width: 36 * scale, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * scale))),
                                Expanded(child: Text('Officer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * scale))),
                                Expanded(child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * scale))),
                                SizedBox(width: 120 * scale, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * scale))),
                                SizedBox(width: 90 * scale, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * scale))),
                                SizedBox(width: 70 * scale, child: Text('Edit', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * scale))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // rows
                          Expanded(
                            child: paged.isEmpty
                                ? const Center(child: Text('No records'))
                                : ListView.separated(
                                    itemCount: paged.length,
                                    separatorBuilder: (_, __) => const Divider(color: Color(0xFFEEEEEE)),
                                    itemBuilder: (context, idx) {
                                      final r = paged[idx];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        child: Row(
                                          children: [
                                            SizedBox(width: 36, child: Text(r['no'] ?? '')),
                                            Expanded(child: Text(r['officer'] ?? '')),
                                            Expanded(child: Text(r['location'] ?? '', style: const TextStyle(color: Colors.black54))),
                                            SizedBox(width: 120, child: Text(r['date'] ?? '')),
                                            SizedBox(
                                              width: 90,
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: (r['status'] == 'Done') ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(r['status'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 70,
                                              child: Center(
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    // edit action
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFF0B63B7)),
                                                    backgroundColor: Colors.white,
                                                  ),
                                                  child: const Text('Edit', style: TextStyle(color: Color(0xFF0B63B7))),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          SizedBox(height: 12 * scale),
                          // pagination
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Page ${_page + 1} of ${_rows.isEmpty ? 0 : totalPages}', style: const TextStyle(color: Colors.black54)),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _page > 0 ? _prevPage : null,
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                                    child: const Text('Back'),
                                  ),
                                  SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: (_page + 1) < totalPages ? _nextPage : null,
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                                    child: const Text('Next'),
                                  ),
                                ],
                              )
                            ],
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

// StaffSubscreen moved to `lib/LGU/staff_subscreen.dart`

