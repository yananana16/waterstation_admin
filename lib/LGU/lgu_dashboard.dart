// import 'package:cloud_firestore/cloud_firestore.dart'; // unused - removed
import 'package:flutter/material.dart';
import 'package:waterstation_admin/LGU/water_stations_page.dart'; // moved Water Stations page to separate file
import 'package:waterstation_admin/LGU/schedule_page.dart';

class LguDashboard extends StatefulWidget {
  const LguDashboard({super.key});

  @override
  State<LguDashboard> createState() => _LguDashboardState();
}

class _LguDashboardState extends State<LguDashboard> {
  int selectedIndex = 0; // 0: Dashboard, 1: Water Stations, 2: Schedule, 3: Profile

  // Add logout method
  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      Navigator.of(context).pop(); // or pushReplacement to login page if available
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: Row(
        children: [
          // Sidebar (updated to match DistrictAdminDashboard style)
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: const Color(0xFFD6E8FD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top area (logo/tagline placeholder)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFD6E8FD),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      // ...optionally add logo/tagline...
                    ],
                  ),
                ),
                // User Info
                Container(
                  width: double.infinity,
                  color: const Color(0xFFD6E8FD),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Color(0xFF004687)),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "LGU Admin",
                        style: TextStyle(fontSize: 20, color: Color(0xFF004687), fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'admin@lgu.local', // adjust if dynamic email desired
                        style: const TextStyle(fontSize: 13, color: Color(0xFF004687)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF004687), thickness: 1, height: 10),
                // Navigation (reuse existing _SidebarButton widgets)
                _SidebarButton(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: selectedIndex == 0,
                  onTap: () => setState(() => selectedIndex = 0),
                ),
                _SidebarButton(
                  icon: Icons.local_drink,
                  label: 'Water Stations',
                  selected: selectedIndex == 1,
                  onTap: () => setState(() => selectedIndex = 1),
                ),
                _SidebarButton(
                  icon: Icons.calendar_today,
                  label: 'Schedule',
                  selected: selectedIndex == 2,
                  onTap: () => setState(() => selectedIndex = 2),
                ),
                _SidebarButton(
                  icon: Icons.person,
                  label: 'Profile',
                  selected: selectedIndex == 3,
                  onTap: () => setState(() => selectedIndex = 3),
                ),
                const Spacer(),
                // Log out button
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: 160,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Color(0xFF004687)),
                      label: const Text("Log out", style: TextStyle(color: Color(0xFF004687))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        side: const BorderSide(color: Color(0xFFD6E8FD)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _logout,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top Bar (copied style from DistrictAdminDashboard)
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E8FD),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 32),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ...optional logo/tagline...
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Color(0xFF1976D2), size: 28),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Color(0xFF1976D2), size: 28),
                            onPressed: () {},
                          ),
                          Positioned(
                            right: 8,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 5,
                                minHeight: 2,
                              ),
                              child: const Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                // Main page content (keeps existing pages but uses the new top bar)
                Expanded(
          child: selectedIndex == 0
            ? Column(
                          children: [
                            // Date + time strip
                            Container(
                              color: const Color(0xFFF2F4F8),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.black54, size: 20),
                                  const SizedBox(width: 8),
                                  const Text('Monday, May 5, 2025', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                                  const Spacer(),
                                  Icon(Icons.access_time, color: Colors.black54, size: 20),
                                  const SizedBox(width: 8),
                                  const Text('11:25 AM PST', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                                ],
                              ),
                            ),
                            // Greeting
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 18),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
                                ),
                                child: const Text("Hello, User!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                              ),
                            ),
                            // Main three-column content
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left: Calendar + Reminders
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: _CalendarWidget(), // existing calendar widget
                                          ),
                                          const SizedBox(height: 18),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Reminders", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                                                const SizedBox(height: 12),
                                                _ReminderCard(icon: Icons.circle, text: "Monthly bacteriological water analysis starts this week."),
                                                const SizedBox(height: 8),
                                                _ReminderCard(icon: Icons.circle, text: "Physical and chemical water analysis coming up in a month."),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // Center: vertical stacked stats
                                    SizedBox(
                                      width: 160,
                                      child: Column(
                                        children: [
                                          _SummaryCard(
                                            label: 'Total\nWater Refilling Stations',
                                            value: '398',
                                            color: Colors.white,
                                            valueColor: const Color(0xFF0B63B7),
                                            labelColor: const Color(0xFF0B63B7),
                                          ),
                                          const SizedBox(height: 12),
                                          _SummaryCard(
                                            label: 'Passed',
                                            value: '360',
                                            color: Colors.white,
                                            valueColor: const Color(0xFF0B63B7),
                                            labelColor: const Color(0xFF0B63B7),
                                          ),
                                          const SizedBox(height: 12),
                                          _SummaryCard(
                                            label: 'Failed',
                                            value: '38',
                                            color: Colors.white,
                                            valueColor: const Color(0xFF0B63B7),
                                            labelColor: const Color(0xFF0B63B7),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right: WRS list with bars
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("Water Refilling Stations\nIloilo City", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                                            const SizedBox(height: 12),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "La Paz", value: 24, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "Mandurriao", value: 24, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "Molo", value: 17, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "Lapuz", value: 30, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "Arevalo", value: 26, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "Jaro 1", value: 14, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "Jaro 2", value: 19, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "City Proper 1", value: 15, maxValue: 30),
                                            const SizedBox(height: 8),
                                            _AreaStatRow(label: "City Proper 2", value: 9, maxValue: 30),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
            : selectedIndex == 1
              ? const WaterStationsPage()
                : selectedIndex == 2
                ? const SchedulePage()
                : const _ProfilePage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Sidebar button widget
class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _SidebarButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: selected
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? const Color(0xFF0B63B7) : Colors.grey, // changed unselected icon color to grey
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0B63B7) : Colors.grey, // changed unselected label color to grey
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }
}

// Summary card widget
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color valueColor;
  final Color labelColor;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 120, // Increased height
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 12, // Smaller font
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 32, // Smaller font
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Calendar widget (static for May 2025)
class _CalendarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // larger cell size for better readability
    const double cellSize = 44.0;
    // Days of the week
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    // May 2025 starts on Thursday
    final weeks = [
      ['', '', '', '', '1', '2', '3'],
      ['4', '5', '6', '7', '8', '9', '10'],
      ['11', '12', '13', '14', '15', '16', '17'],
      ['18', '19', '20', '21', '22', '23', '24'],
      ['25', '26', '27', '28', '29', '30', '31'],
    ];
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'May',
                style: TextStyle(
                  color: Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Spacer(),
              Text(
                '2025',
                style: TextStyle(
                  color: Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Days of week
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days
                .map((d) => SizedBox(
                      width: cellSize,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          ...weeks.map(
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
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: Text(
                        day,
                        style: TextStyle(
                          color: day == '5' ? Colors.white : Colors.black87,
                          fontWeight: day == '5' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Area stations table widget
class _AreaStationsTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final areas = [
      ['La Paz', '24'],
      ['Mandurriao', '36'],
      ['Molo', '30'],
      ['Lapuz', '30'],
      ['Arevalo', '29'],
      ['Jaro 1', '14'],
      ['Jaro 2', '16'],
      ['City Proper 1', '18'],
      ['City Proper 2', '9'],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        double chipWidth = (constraints.maxWidth - 48) / 4;
        chipWidth = chipWidth.clamp(90, 140);
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: areas
              .map(
                (area) => Container(
                  width: chipWidth,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFEAF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          area[0],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0B63B7),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        area[1],
                        style: const TextStyle(
                          color: Color(0xFF0B63B7),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// Reminder card widget
class _ReminderCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ReminderCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF0B63B7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF0B63B7),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Compliance Page removed as requested.

// Schedule page moved to `lib/LGU/schedule_page.dart`.

class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  String name = 'User';
  String role = 'Sanitary Inspector';
  String contact = '(+63) 912 345 6789';
  String email = 'email@gmail.com';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
            ),
            child: const Text('Profile', style: TextStyle(color: Color(0xFF0B63B7), fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: avatar + change picture + save button
              Column(
                children: [
                  const CircleAvatar(radius: 48, backgroundColor: Color(0xFFEAF6FF), child: Icon(Icons.person, size: 48, color: Color(0xFF0B63B7))),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.edit, color: Color(0xFF0B63B7), size: 16),
                      SizedBox(width: 6),
                      Text('Change Profile Picture', style: TextStyle(color: Color(0xFF0B63B7))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 140,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B63B7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              // Right column: details list
              Expanded(
                child: Column(
                  children: [
                    _ProfileFieldRow(label: 'Name:', value: name, onEdit: () async {
                      final v = await _showEditDialog(context, 'Name', name);
                      if (v != null) setState(() => name = v);
                    }),
                    const SizedBox(height: 12),
                    _ProfileFieldRow(label: 'Role:', value: role, onEdit: () async {
                      final v = await _showEditDialog(context, 'Role', role);
                      if (v != null) setState(() => role = v);
                    }),
                    const SizedBox(height: 12),
                    _ProfileFieldRow(label: 'Contact Number:', value: contact, onEdit: () async {
                      final v = await _showEditDialog(context, 'Contact Number', contact);
                      if (v != null) setState(() => contact = v);
                    }),
                    const SizedBox(height: 12),
                    _ProfileFieldRow(label: 'Email:', value: email, onEdit: () async {
                      final v = await _showEditDialog(context, 'Email', email);
                      if (v != null) setState(() => email = v);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _showEditDialog(BuildContext context, String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }
}

// All Stations Table Page
// ignore: unused_element
class _AllStationsTable extends StatelessWidget {
  const _AllStationsTable();

  @override
  Widget build(BuildContext context) {
    final stations = [
      ['PureFlow Water Station', 'Mark Delacruz', 'Passed'],
      ['AquaSpring Refilling Hub', 'Julia Fernandez', 'Passed'],
      ['BlueWave Water Depot', 'Richard Gomez', 'Passed'],
      ['AquaPrime Refilling Station', 'Carlos Mendoza', 'Passed'],
      ['HydroPure H2O Haven', 'Isabella Reyes', 'Passed'],
    ];

    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              const Text(
                'All Water Stations',
                style: TextStyle(
                  color: Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              Icon(Icons.settings, color: Color(0xFF0B63B7)),
              const SizedBox(width: 20),
              Icon(Icons.notifications_none, color: Color(0xFF0B63B7)),
              const SizedBox(width: 20),
              Icon(Icons.person_outline, color: Color(0xFF0B63B7)),
            ],
          ),
        ),
        // Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE0E0E0)),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Name of Station',
                            style: TextStyle(
                              color: Color(0xFF0B63B7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Owner Name',
                            style: TextStyle(
                              color: Color(0xFF0B63B7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Status',
                            style: TextStyle(
                              color: Color(0xFF0B63B7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table rows
                  ...stations.map((row) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(row[0]),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(row[1]),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row[2],
                                style: TextStyle(
                                  color: row[2] == 'Passed'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Profile field row used on profile page
class _ProfileFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;
  const _ProfileFieldRow({required this.label, required this.value, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 6,
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF0B63B7)),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

// Add helper widget for right-side area bars
class _AreaStatRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  const _AreaStatRow({required this.label, required this.value, this.maxValue = 30});

  @override
  Widget build(BuildContext context) {
    final percent = (maxValue == 0) ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: const TextStyle(color: Color(0xFF0B63B7))),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B63B7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(value.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
