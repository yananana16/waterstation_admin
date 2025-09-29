import 'package:flutter/material.dart';
import 'inspection_page.dart'; // added import
import 'add_schedule_subscreen.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

enum _ActiveSubscreen { none, inspection, addSchedule, assignment, staff } // added staff

class _SchedulePageState extends State<SchedulePage> {
  _ActiveSubscreen _activeSubscreen = _ActiveSubscreen.none;
  // Monthly inspection state: sample stations and per-station per-month schedule
  DateTime _selectedMonth = DateTime(2025, 9); // example: September 2025

  final List<Map<String, String>> _stations = [
    {'id': 'station_001', 'name': 'Crystal Clear Refills', 'location': 'La Paz'},
    {'id': 'station_002', 'name': 'HydroPure Station', 'location': 'Lapuz'},
    {'id': 'station_003', 'name': 'EverFresh Water Refilling', 'location': 'City Proper 1'},
  ];

  // schedule[stationId][monthKey] => { 'date': '2025-09-05', 'officer': 'T. Andres', 'status': 'Pending' }
  final Map<String, Map<String, Map<String, String>>> _schedule = {};

  String _monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

  Map<String, String> _getScheduleFor(String stationId, DateTime month) {
    final mk = _monthKey(month);
    _schedule.putIfAbsent(stationId, () => {});
    return _schedule[stationId]!.putIfAbsent(mk, () => {
      'date': '${month.year}-${month.month.toString().padLeft(2, '0')}-05',
      'officer': '',
      'status': 'Pending',
    });
  }

  void _openInspection() => setState(() => _activeSubscreen = _ActiveSubscreen.inspection);
  void _openAddSchedule() => setState(() => _activeSubscreen = _ActiveSubscreen.addSchedule);
  void _openAssignment() => setState(() => _activeSubscreen = _ActiveSubscreen.assignment);
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
        // Date and time row
        Container(
          color: const Color(0xFFF2F4F8),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10 * scale),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.black54, size: 18 * scale),
              SizedBox(width: 8 * scale),
              Text(
                'Monday, May 5, 2025',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16 * scale),
              ),
              const Spacer(),
              Icon(Icons.access_time, color: Colors.black54, size: 18 * scale),
              SizedBox(width: 8 * scale),
              Text(
                '11:25 AM PST',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16 * scale),
              ),
            ],
          ),
        ),
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
                                final availableHeight = constraints.maxHeight; // use to bound inner sections
                                return isNarrow
                                    ? SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            // ...existing code for narrow layout (keeps content scrollable)...
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
                                                            child: ListView.separated(
                                                              physics: const AlwaysScrollableScrollPhysics(),
                                                              padding: EdgeInsets.zero,
                                                              itemCount: _stations.length,
                                                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF0B63B7)),
                                                              itemBuilder: (context, idx) {
                                                                final s = _stations[idx];
                                                                final sched = _getScheduleFor(s['id']!, _selectedMonth);
                                                                return Padding(
                                                                  padding: EdgeInsets.symmetric(vertical: 14 * scale, horizontal: 8 * scale),
                                                                  child: Row(
                                                                    children: [
                                                                      SizedBox(width: 28 * scale, child: Text('${idx + 1}', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13 * scale))),
                                                                      Expanded(child: Text(s['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13 * scale))),
                                                                      Expanded(child: Text(s['location'] ?? '', style: TextStyle(color: Colors.black54, fontSize: 13 * scale))),
                                                                      Expanded(child: Text(sched['date'] ?? '', style: TextStyle(color: Colors.black54, fontSize: 13 * scale))),
                                                                      Expanded(child: Text(sched['officer'] ?? '', style: TextStyle(color: Colors.black54, fontSize: 13 * scale))),
                                                                      SizedBox(
                                                                        width: 80 * scale,
                                                                        child: Center(
                                                                          child: GestureDetector(
                                                                            onTap: () async {
                                                                              // open assign dialog
                                                                              final res = await showDialog<Map<String, String>>(
                                                                                context: context,
                                                                                builder: (context) {
                                                                                  final officerCtrl = TextEditingController(text: sched['officer']);
                                                                                  var status = sched['status'] ?? 'Pending';
                                                                                  return AlertDialog(
                                                                                    title: const Text('Assign / Update'),
                                                                                    content: Column(
                                                                                      mainAxisSize: MainAxisSize.min,
                                                                                      children: [
                                                                                        TextField(controller: officerCtrl, decoration: const InputDecoration(labelText: 'Officer')),
                                                                                        const SizedBox(height: 8),
                                                                                        DropdownButton<String>(
                                                                                          value: status,
                                                                                          items: const [DropdownMenuItem(value: 'Pending', child: Text('Pending')), DropdownMenuItem(value: 'Done', child: Text('Done'))],
                                                                                          onChanged: (v) {
                                                                                            if (v != null) status = v;
                                                                                          },
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                    actions: [
                                                                                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                                                                                      ElevatedButton(
                                                                                        onPressed: () {
                                                                                          Navigator.of(context).pop({'officer': officerCtrl.text, 'status': status});
                                                                                        },
                                                                                        child: const Text('Save'),
                                                                                      ),
                                                                                    ],
                                                                                  );
                                                                                },
                                                                              );
                                                                              if (res != null) {
                                                                                setState(() {
                                                                                  sched['officer'] = res['officer'] ?? '';
                                                                                  sched['status'] = res['status'] ?? 'Pending';
                                                                                });
                                                                              }
                                                                            },
                                                                            child: Container(
                                                                              padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                                                                              decoration: BoxDecoration(
                                                                                color: (sched['status'] == 'Done') ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                                                                                borderRadius: BorderRadius.circular(6 * scale),
                                                                              ),
                                                                              child: Text(
                                                                                sched['status'] ?? 'Pending',
                                                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * scale),
                                                                              ),
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
                                                          _ScheduleActionButton(icon: Icons.assignment, label: 'Assign', onPressed: _openAssignment, scale: scale),
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

// New: StaffSubscreen widget
class StaffSubscreen extends StatefulWidget {
  final VoidCallback? onClose;
  const StaffSubscreen({super.key, this.onClose});

  @override
  State<StaffSubscreen> createState() => _StaffSubscreenState();
}

class _StaffSubscreenState extends State<StaffSubscreen> {
  final List<Map<String, String>> _rows = [
    {'id': '0001', 'first': 'Maria', 'last': 'Santos', 'phone': '(+63) 912 3456 789', 'email': 'email@email.com', 'role': 'Sanitary Inspector'},
    {'id': '0002', 'first': 'Luis', 'last': 'Dela Cruz', 'phone': '(+63) 912 3456 789', 'email': 'email@email.com', 'role': 'Sanitary Inspector'},
    {'id': '0003', 'first': 'Ramon', 'last': 'Garcia', 'phone': '(+63) 912 3456 789', 'email': 'email@email.com', 'role': 'Sanitary Inspector'},
    {'id': '0004', 'first': 'Teresa', 'last': 'Mendoza', 'phone': '(+63) 912 3456 789', 'email': 'email@email.com', 'role': 'Sanitary Inspector'},
    {'id': '0005', 'first': 'Elena', 'last': 'Villanueva', 'phone': '(+63) 912 3456 789', 'email': 'email@email.com', 'role': 'Sanitary Inspector'},
    // ...add more sample rows if desired...
  ];

  int _page = 0;
  final int _perPage = 10; // limit to 10 per page

  List<Map<String, String>> get _paged {
    final start = _page * _perPage;
    final end = (start + _perPage).clamp(0, _rows.length);
    if (start >= _rows.length) return [];
    return _rows.sublist(start, end);
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
    final paged = _paged;
    final totalPages = ((_rows.length - 1) / _perPage).floor() + 1;
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
                            setState(() {
                              _page = 0;
                            });
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
                  // table
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
                                SizedBox(width: 80, child: Text('ID No.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('First Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Last Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                Expanded(child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                SizedBox(width: 140, child: Text('Role', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                SizedBox(width: 70, child: Text('Edit', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                              ],
                            ),
                          ),
                          if (paged.isEmpty)
                            const Expanded(child: Center(child: Text('No records found', style: TextStyle(color: Colors.black54))))
                          else
                            Expanded(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: paged.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                itemBuilder: (context, idx) {
                                  final r = paged[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 80, child: Text(r['id'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                        Expanded(child: Text(r['first'] ?? '')),
                                        Expanded(child: Text(r['last'] ?? '')),
                                        Expanded(child: Text(r['phone'] ?? '', style: const TextStyle(color: Colors.black54))),
                                        Expanded(child: Text(r['email'] ?? '', style: const TextStyle(color: Colors.black54))),
                                        SizedBox(width: 140, child: Text(r['role'] ?? '', textAlign: TextAlign.center)),
                                        SizedBox(
                                          width: 70,
                                          child: Center(
                                            child: OutlinedButton(
                                              onPressed: () {},
                                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0B63B7))),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}

