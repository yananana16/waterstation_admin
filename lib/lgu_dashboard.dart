import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firebase import
import 'package:flutter/material.dart';

class LguDashboard extends StatefulWidget {
  const LguDashboard({Key? key}) : super(key: key);

  @override
  State<LguDashboard> createState() => _LguDashboardState();
}

class _LguDashboardState extends State<LguDashboard> {
  int selectedIndex = 0; // 0: Dashboard, 1: Water Stations, 2: Compliance, 3: Schedule, 4: Officers

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
          // Sidebar
          Container(
            width: 220,
            color: const Color(0xFF0B63B7),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // User icon and name
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 48, color: Color(0xFF0B63B7)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 30),
                // Navigation
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
                  icon: Icons.verified_user,
                  label: 'Compliance',
                  selected: selectedIndex == 2,
                  onTap: () => setState(() => selectedIndex = 2),
                ),
                _SidebarButton(
                  icon: Icons.calendar_today,
                  label: 'Schedule',
                  selected: selectedIndex == 3,
                  onTap: () => setState(() => selectedIndex = 3),
                ),
                _SidebarButton(
                  icon: Icons.people,
                  label: 'Officers',
                  selected: selectedIndex == 4,
                  onTap: () => setState(() => selectedIndex = 4),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _SidebarButton(
                    icon: Icons.logout,
                    label: 'Log out',
                    onTap: _logout, // <-- wire up logout
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: selectedIndex == 0
                ? Column(
                    children: [
                      // Header
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        child: Row(
                          children: [
                            const Text(
                              'Dashboard',
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
                      // Date and time row
                      Container(
                        color: const Color(0xFFF2F4F8),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.black54, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Monday, May 5, 2025',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                            ),
                            const Spacer(),
                            Icon(Icons.access_time, color: Colors.black54, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '11:25 AM PST',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      // Main dashboard content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Summary and calendar
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Summary cards
                                    Row(
                                      children: [
                                        _SummaryCard(
                                          label: 'Total\nWater Refilling Stations',
                                          value: '398',
                                          color: Color(0xFF0B63B7),
                                          valueColor: Colors.white,
                                          labelColor: Colors.white70,
                                        ),
                                        const SizedBox(width: 20),
                                        _SummaryCard(
                                          label: 'Passed',
                                          value: '368',
                                          color: Color(0xFFEAF6FF),
                                          valueColor: Color(0xFF0B63B7),
                                          labelColor: Color(0xFF0B63B7),
                                        ),
                                        const SizedBox(width: 20),
                                        _SummaryCard(
                                          label: 'Failed',
                                          value: '30',
                                          color: Color(0xFFFFF0F0),
                                          valueColor: Color(0xFFD32F2F),
                                          labelColor: Color(0xFFD32F2F),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 30),
                                    // Calendar
                                    _CalendarWidget(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              // Right: Station numbers and reminders
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Number of stations per area
                                    const Text(
                                      'Number of Water Refilling Stations\nIloilo City',
                                      style: TextStyle(
                                        color: Color(0xFF0B63B7),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _AreaStationsTable(),
                                    const SizedBox(height: 32),
                                    // Reminders
                                    const Text(
                                      'Reminders:',
                                      style: TextStyle(
                                        color: Color(0xFF0B63B7),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _ReminderCard(
                                      icon: Icons.check_circle_outline,
                                      text: 'Monthly bacteriological water analysis starts this week.',
                                    ),
                                    const SizedBox(height: 12),
                                    _ReminderCard(
                                      icon: Icons.warning_amber_outlined,
                                      text: 'Physical and chemical water analysis coming up in a month.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : selectedIndex == 1
                    ? const _WaterStationsPage()
                    : selectedIndex == 2
                        ? const _CompliancePage()
                        : selectedIndex == 3
                            ? const _SchedulePage()
                            : const _OfficersPage(),
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
        leading: Icon(icon, color: selected ? Color(0xFF0B63B7) : Colors.white),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? Color(0xFF0B63B7) : Colors.white,
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
    // Days of the week
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    // May 2025 starts on Thursday, so first row: [ , , , , 1, 2, 3]
    final weeks = [
      ['', '', '', '', '1', '2', '3'],
      ['4', '5', '6', '7', '8', '9', '10'],
      ['11', '12', '13', '14', '15', '16', '17'],
      ['18', '19', '20', '21', '22', '23', '24'],
      ['25', '26', '27', '28', '29', '30', '31'],
    ];
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE0E0E0)),
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
                  fontSize: 18,
                ),
              ),
              Spacer(),
              Text(
                '2025',
                style: TextStyle(
                  color: Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Days of week
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days
                .map((d) => Text(
                      d,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          // Calendar days
          ...weeks.map(
            (week) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: week
                  .map(
                    (day) => Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: day == '5'
                          ? BoxDecoration(
                              color: Color(0xFF0B63B7),
                              borderRadius: BorderRadius.circular(8),
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

// Water Stations Page (table UI)
class _WaterStationsPage extends StatelessWidget {
  const _WaterStationsPage();

  @override
  Widget build(BuildContext context) {
    const int rowsPerPage = 6; // Pagination rows per page
    return StatefulBuilder(
      builder: (context, setState) {
        int currentPage = 0; // Track current page
        String searchQuery = ""; // Track search query
        String selectedDistrict = 'All Districts'; // Track selected district for filtering

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
                      value: selectedDistrict,
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
                  future: FirebaseFirestore.instance.collection('station_owners').get(),
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
                              headingRowColor: MaterialStateProperty.all(const Color(0xFFEAF6FF)),
                              dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.selected)) {
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
                                color: Color(0xFFE0E0E0),
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
                                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                                              : const Color(0xFFD32F2F).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: status == 'approved'
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFD32F2F),
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
                                onPressed: currentPage > 0
                                    ? () => setState(() => currentPage--)
                                    : null,
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
                                onPressed: (currentPage < totalPages - 1)
                                    ? () => setState(() => currentPage++)
                                    : null,
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
      },
    );
  }
}

// Compliance Page (table UI)
class _CompliancePage extends StatelessWidget {
  const _CompliancePage();

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
                'Compliance Report',
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
        // Date and time row
        Container(
          color: const Color(0xFFF2F4F8),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.black54, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Monday, May 5, 2025',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
              const Spacer(),
              Icon(Icons.access_time, color: Colors.black54, size: 20),
              const SizedBox(width: 8),
              const Text(
                '11:25 AM PST',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ],
          ),
        ),
        // Search and filter row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          child: Row(
            children: [
              // Search box
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search, color: Color(0xFF0B63B7)),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Filter button
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Color(0xFFE0E0E0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: Color(0xFF0B63B7)),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter',
                      style: TextStyle(
                        color: Color(0xFF0B63B7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
                          flex: 3,
                          child: Text(
                            'Compliance Report',
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
                              flex: 3,
                              child: Row(
                                children: [
                                  // Status button
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: row[2] == 'Passed'
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFD32F2F),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'View Report',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Upload button
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEAF6FF),
                                      foregroundColor: const Color(0xFF0B63B7),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Upload',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  // Pagination and navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                        const Spacer(),
                        const Text(
                          'Page 1 / 20',
                          style: TextStyle(
                            color: Color(0xFF0B63B7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B63B7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Next'),
                        ),
                      ],
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

// Schedule Page
class _SchedulePage extends StatelessWidget {
  const _SchedulePage();

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              const Text(
                'Schedule',
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
        // Date and time row
        Container(
          color: const Color(0xFFF2F4F8),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.black54, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Monday, May 5, 2025',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
              const Spacer(),
              Icon(Icons.access_time, color: Colors.black54, size: 20),
              const SizedBox(width: 8),
              const Text(
                '11:25 AM PST',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ],
          ),
        ),
        // Main content: Calendar and Inspection Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar
                Container(
                  width: 340,
                  child: _ScheduleCalendar(),
                ),
                const SizedBox(width: 32),
                // Inspection Table
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFFE0E0E0)),
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
                        const Text(
                          'Inspection',
                          style: TextStyle(
                            color: Color(0xFF0B63B7),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'May 5 - 9',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Table
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Table header
                              Row(
                                children: const [
                                  SizedBox(width: 28, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                  Expanded(child: Text('Station', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                  Expanded(child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                  Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                  Expanded(child: Text('Officer', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                  SizedBox(width: 60, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B63B7)))),
                                ],
                              ),
                              const Divider(),
                              // Table rows
                              ...inspectionRows.map((row) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 28, child: Text(row[0])),
                                        Expanded(child: Text(row[1])),
                                        Expanded(child: Text(row[2])),
                                        Expanded(child: Text(row[3])),
                                        Expanded(child: Text(row[4])),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            row[5],
                                            style: TextStyle(
                                              color: row[5] == 'Done'
                                                  ? Colors.green
                                                  : row[5] == 'Pending'
                                                      ? Colors.orange
                                                      : Colors.black,
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'See More',
                            style: TextStyle(
                              color: Color(0xFF0B63B7),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
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
        // Action buttons
        Padding(
          padding: const EdgeInsets.only(bottom: 18, left: 32, right: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScheduleActionButton(icon: Icons.check_circle, label: 'Inspection'),
              const SizedBox(width: 24),
              _ScheduleActionButton(icon: Icons.calendar_month, label: 'Add Schedule'),
              const SizedBox(width: 24),
              _ScheduleActionButton(icon: Icons.assignment, label: 'Assignment'),
              const SizedBox(width: 24),
              _ScheduleActionButton(icon: Icons.people, label: 'Staffs'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFB0C4DE)),
      ),
      padding: const EdgeInsets.all(18),
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
                  fontSize: 18,
                ),
              ),
              Spacer(),
              Text(
                '2025',
                style: TextStyle(
                  color: Color(0xFF0B63B7),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days
                .map((d) => Text(
                      d,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          ...weeks.map(
            (week) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: week
                  .map(
                    (day) => Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: day == '5'
                          ? BoxDecoration(
                              color: Color(0xFF0B63B7),
                              borderRadius: BorderRadius.circular(8),
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

class _ScheduleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ScheduleActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFFEAF6FF),
          child: Icon(icon, color: Color(0xFF0B63B7), size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0B63B7),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _OfficersPage extends StatelessWidget {
  const _OfficersPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Officers Page',
        style: TextStyle(
          color: Color(0xFF0B63B7),
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
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

// Add a helper widget for displaying details in rows
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
