import 'package:flutter/material.dart';
import 'inspection_page.dart'; // added import

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

enum _ActiveSubscreen { none, inspection, addSchedule, assignment } // added assignment

class _SchedulePageState extends State<SchedulePage> {
  _ActiveSubscreen _activeSubscreen = _ActiveSubscreen.none;

  void _openInspection() => setState(() => _activeSubscreen = _ActiveSubscreen.inspection);
  void _openAddSchedule() => setState(() => _activeSubscreen = _ActiveSubscreen.addSchedule);
  void _openAssignment() => setState(() => _activeSubscreen = _ActiveSubscreen.assignment); // new
  void _closeSubscreen() => setState(() => _activeSubscreen = _ActiveSubscreen.none);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    // scale based on a 1200px reference width, clamped to reasonable range
    final scale = (w / 1200).clamp(0.75, 1.2);
    final horizontalPadding = (w * 0.03).clamp(12.0, 48.0);
    final sectionSpacing = (w * 0.02).clamp(12.0, 28.0);
    final titleFontSize = 28.0 * scale;
    final headerFontSize = 22.0 * scale;

    final inspectionRows = [
      ['1', 'Station A', 'Lapaz', 'May 5', 'Officer 1', 'Done'],
      ['2', 'Station B', 'Molo', 'May 6', 'Officer 2', 'Done'],
      ['3', 'Station C', 'Jaro', 'May 7', 'Officer 3', 'Done'],
      ['4', '', '', '', '', 'Pending'],
      ['5', '', '', '', '', 'Pending'],
    ];
    return Column(
      children: [
        // Header
        Container(
          color: const Color(0xFFEAF6FF),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16 * scale),
          child: Row(
            children: [
              Text(
                'Schedule',
                style: TextStyle(
                  color: const Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                ),
              ),
              const Spacer(),
              Icon(Icons.settings, color: const Color(0xFF0B63B7), size: 20 * scale),
              SizedBox(width: 20 * scale),
              Icon(Icons.notifications_none, color: const Color(0xFF0B63B7), size: 20 * scale),
              SizedBox(width: 20 * scale),
              Icon(Icons.person_outline, color: const Color(0xFF0B63B7), size: 20 * scale),
            ],
          ),
        ),
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
                                              Text(
                                                'May 5 - 9',
                                                style: TextStyle(
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14 * scale,
                                                ),
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
                                                      // rows (scrollable)
                                                      Expanded(
                                                        child: ListView.separated(
                                                          physics: const AlwaysScrollableScrollPhysics(),
                                                          padding: EdgeInsets.zero,
                                                          itemCount: inspectionRows.length,
                                                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF0B63B7)),
                                                          itemBuilder: (context, idx) {
                                                            final row = inspectionRows[idx];
                                                            return Padding(
                                                              padding: EdgeInsets.symmetric(vertical: 14 * scale, horizontal: 8 * scale),
                                                              child: Row(
                                                                children: [
                                                                  SizedBox(width: 28 * scale, child: Text(row[0], style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13 * scale))),
                                                                  Expanded(child: Text(row[1], style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13 * scale))),
                                                                  Expanded(child: Text(row[2], style: TextStyle(color: Colors.black54, fontSize: 13 * scale))),
                                                                  Expanded(child: Text(row[3], style: TextStyle(color: Colors.black54, fontSize: 13 * scale))),
                                                                  Expanded(child: Text(row[4], style: TextStyle(color: Colors.black54, fontSize: 13 * scale))),
                                                                  SizedBox(
                                                                    width: 80 * scale,
                                                                    child: Center(
                                                                      child: Container(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                                                                        decoration: BoxDecoration(
                                                                          color: row[5] == 'Done' ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                                                                          borderRadius: BorderRadius.circular(6 * scale),
                                                                        ),
                                                                        child: Text(
                                                                          row[5],
                                                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * scale),
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
                                                      _ScheduleActionButton(icon: Icons.people, label: 'Staff', scale: scale),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 18 * scale),
                                            // Constrain calendar height and allow internal scrolling
                                            Container(
                                              padding: EdgeInsets.all(12 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12 * scale),
                                                border: Border.all(color: const Color(0xFF0B63B7)),
                                              ),
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight: (availableHeight * 0.6).clamp(180.0, availableHeight - 80.0),
                                                ),
                                                child: SingleChildScrollView(
                                                  child: _ScheduleCalendar(scale: scale, availableWidth: constraints.maxWidth / 3, availableHeight: (availableHeight * 0.6).clamp(180.0, availableHeight - 80.0)),
                                                ),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScheduleActionButton(icon: Icons.check_circle, label: 'Inspection', onPressed: _openInspection, scale: scale),
              SizedBox(width: 24 * scale),
              _ScheduleActionButton(icon: Icons.calendar_month, label: 'Add Schedule', onPressed: _openAddSchedule, scale: scale),
              SizedBox(width: 24 * scale),
              _ScheduleActionButton(icon: Icons.assignment, label: 'Assignment', onPressed: _openAssignment, scale: scale),
              SizedBox(width: 24 * scale),
              _ScheduleActionButton(icon: Icons.people, label: 'Staffs', scale: scale),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleCalendar extends StatelessWidget {
  final double scale;
  final double? availableWidth;
  final double? availableHeight; // added
  const _ScheduleCalendar({this.scale = 1.0, this.availableWidth, this.availableHeight, super.key});

  @override
  Widget build(BuildContext context) {
    // responsive cell size based on available width or screen width
    final w = availableWidth ?? MediaQuery.of(context).size.width;
    // if availableHeight provided, reduce cellSize to fit better
    final h = availableHeight ?? MediaQuery.of(context).size.height * 0.3;
    double cellSize = (w / 20).clamp(24.0, 48.0) * scale;
    // limit grid height if necessary by capping number of rows visible; we'll allow vertical scrolling via parent ConstrainedBox/SingleChildScrollView
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final weeks = [
      ['', '', '', '', '1', '2', '3'],
      ['4', '5', '6', '7', '8', '9', '10'],
      ['11', '12', '13', '14', '15', '16', '17'],
      ['18', '19', '20', '21', '22', '23', '24'],
      ['25', '26', '27', '28', '29', '30', '31'],
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: const Color(0xFFB0C4DE)),
      ),
      padding: EdgeInsets.all(18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'May',
                style: TextStyle(
                  color: const Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: 20 * scale,
                ),
              ),
              const Spacer(),
              Text(
                '2025',
                style: TextStyle(
                  color: const Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: 20 * scale,
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          // day labels
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: days
                  .map((d) => SizedBox(
                        width: cellSize,
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12 * scale,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 8 * scale),
          // weeks grid - wrapped in Column; parent constrains height and allows scrolling
          Column(
            children: weeks
                .map(
                  (week) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: week
                        .map(
                          (day) => Container(
                            width: cellSize,
                            height: cellSize,
                            alignment: Alignment.center,
                            decoration: day == '5'
                                ? BoxDecoration(
                                    color: const Color(0xFF0B63B7),
                                    borderRadius: BorderRadius.circular(10 * scale),
                                  )
                                : null,
                            child: Text(
                              day,
                              style: TextStyle(
                                color: day == '5' ? Colors.white : Colors.black87,
                                fontWeight: day == '5' ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13 * scale,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ],
      ),
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

// AddScheduleSubscreen: use responsive label width.
class AddScheduleSubscreen extends StatelessWidget {
  final VoidCallback? onClose;
  const AddScheduleSubscreen({super.key, this.onClose});

  Widget _fieldRow(String label, Widget right, double labelWidth, double scale) {
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      child: Row(
        children: [
          Container(
            width: labelWidth,
            padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 16 * scale),
            color: const Color(0xFFF2F6FA),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF0B63B7), fontSize: 14 * scale)),
          ),
          SizedBox(width: 12 * scale),
          Expanded(child: right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 1200).clamp(0.75, 1.2);
    final labelWidth = (w * 0.18).clamp(120.0, 300.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8 * scale),
      child: Column(
        children: [
          // header inside subscreen
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF6FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: const Color(0xFF0B63B7), size: 20 * scale),
                  onPressed: () {
                    if (onClose != null) onClose!();
                  },
                ),
                SizedBox(width: 8 * scale),
                Text('Add Schedule', style: TextStyle(color: const Color(0xFF0B63B7), fontSize: 18 * scale, fontWeight: FontWeight.bold)),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20 * scale),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _fieldRow(
                      'Inspection number:',
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 14 * scale),
                        color: const Color(0xFFF2F6FA),
                        child: Text('0168', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Station:',
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 14 * scale),
                              color: const Color(0xFFF2F6FA),
                              child: Text('PureFlow Water Station', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          IconButton(onPressed: () {}, icon: Icon(Icons.edit, color: const Color(0xFF0B63B7), size: 20 * scale)),
                        ],
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Location',
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 8 * scale),
                        color: const Color(0xFFF2F6FA),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: 'Mandurriao',
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'Mandurriao', child: Text('Mandurriao')),
                            DropdownMenuItem(value: 'La Paz', child: Text('La Paz')),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Date',
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 14 * scale),
                              color: const Color(0xFFF2F6FA),
                              child: Text('May 8, 2025', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          IconButton(onPressed: () { /* pick date */ }, icon: Icon(Icons.calendar_today, color: const Color(0xFF0B63B7), size: 20 * scale)),
                        ],
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Officer:',
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 8 * scale),
                        color: const Color(0xFFF2F6FA),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: 'T. Andres',
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'T. Andres', child: Text('T. Andres')),
                            DropdownMenuItem(value: 'J. Alonzo', child: Text('J. Alonzo')),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                      labelWidth,
                      scale,
                    ),
                    SizedBox(height: 18 * scale),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          // perform add schedule action
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
                          child: Text('Add Schedule', style: TextStyle(fontSize: 14 * scale)),
                        ),
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

