// ignore_for_file: unused_element, unused_local_variable
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firestore_repository.dart';
import 'package:waterstation_admin/LGU/water_stations_page.dart';
import 'package:waterstation_admin/LGU/schedule_page.dart';
import '../federated/logout_dialog.dart';

class LguDashboard extends StatefulWidget {
  const LguDashboard({super.key});

  @override
  State<LguDashboard> createState() => _LguDashboardState();
}

class _LguDashboardState extends State<LguDashboard> {
  int selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int totalOwners = 0;
  Map<String, int> areaCounts = {};
  int approvedCount = 0;
  int failedCount = 0;

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LogoutDialog(),
    );
    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } catch (e) {
        debugPrint('Error signing out: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTotalOwners();
  }

  Future<void> _fetchTotalOwners() async {
    try {
      final snapshot = await FirestoreRepository.instance.getCollectionOnce(
        'station_owners',
        () => FirebaseFirestore.instance.collection('station_owners'),
      );
      final Map<String, int> counts = {};
      int approved = 0;
      int failed = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final district = (data?['districtName'] ?? '').toString().trim();
        if (district.isNotEmpty) {
          counts[district] = (counts[district] ?? 0) + 1;
        }
        final status = (data?['status'] ?? '').toString().toLowerCase();
        if (status == 'approved') {
          approved++;
        } else {
          failed++;
        }
      }
      setState(() {
        totalOwners = snapshot.size;
        areaCounts = counts;
        approvedCount = approved;
        failedCount = failed;
      });
    } catch (e) {
      debugPrint('Failed to fetch station_owners count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F9FB),
      drawer: Drawer(
        child: SafeArea(child: _buildSidebarContent()),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final sidebarWidth = isWide ? (_isSidebarCollapsed ? 80.0 : 250.0) : 0.0;
          return Row(
            children: [
              if (isWide)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: sidebarWidth,
                  child: _buildSidebarContent(collapsed: _isSidebarCollapsed),
                ),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(isWide),
                    Expanded(child: _getSelectedPage()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD6E8FD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.18 * 255).round()),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF1976D2)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          if (isWide)
            IconButton(
              icon: Icon(_isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left, color: const Color(0xFF1976D2)),
              onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSidebarContent({bool collapsed = false}) {
    return Container(
      color: const Color(0xFFD6E8FD),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: collapsed ? const SizedBox(height: 20) : Column(children: []),
          ),
          if (!collapsed)
            Container(
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? 'admin@lgu.local',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF004687)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          const Divider(color: Color(0xFF004687), thickness: 1, height: 10),
          _sidebarNavTile('Dashboard', 0, collapsed),
          _sidebarNavTile('Water Stations', 1, collapsed),
          _sidebarNavTile('Schedule', 2, collapsed),
          const Spacer(),
          if (!collapsed) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: 160,
                height: 42,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person, color: Color(0xFF004687)),
                  label: const Text("Profile", style: TextStyle(color: Color(0xFF004687))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => setState(() => selectedIndex = 3),
                ),
              ),
            ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _logout,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sidebarNavTile(String label, int index, bool collapsed) {
    IconData icon;
    switch (label) {
      case 'Dashboard':
        icon = Icons.dashboard;
        break;
      case 'Water Stations':
        icon = Icons.local_drink;
        break;
      case 'Schedule':
        icon = Icons.calendar_today;
        break;
      case 'Profile':
        icon = Icons.person;
        break;
      default:
        icon = Icons.circle;
    }
    final isSelected = selectedIndex == index;
    if (collapsed) {
      return Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, color: isSelected ? const Color(0xFF004687) : Colors.blueGrey),
          onPressed: () => setState(() => selectedIndex = index),
        ),
      );
    }
    return _sidebarNavItem(label, index, icon);
  }

  Widget _sidebarNavItem(String label, int index, IconData icon) {
    bool isSelected = selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => selectedIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Color(0xFF004687) : Colors.blueGrey, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Color(0xFF004687) : Colors.blueGrey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getSelectedPage() {
    switch (selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return const WaterStationsPage();
      case 2:
        return const SchedulePage();
      case 3:
        return const _ProfilePage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildDashboardOverview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final now = DateTime.now().toUtc().add(const Duration(hours: 8));
        final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
        final formattedTime = DateFormat('hh:mm a').format(now);
        return Column(
          children: [
            // Date + time strip
            Container(
              color: const Color(0xFFF2F4F8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Color(0xFF0B63B7), size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      formattedDate,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xFF0B63B7)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, color: Color(0xFF0B63B7), size: 20),
                  const SizedBox(width: 8),
                  Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xFF0B63B7))),
                ],
              ),
            ),
            // Greeting
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8)],
                ),
                child: const Text("Hello, User!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
              ),
            ),
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
                ),
                padding: const EdgeInsets.all(16),
                child: _CalendarWidget(),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
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
        SizedBox(
          width: 160,
          child: Column(
            children: [
              _SummaryCard(
                label: 'Total\nWater Refilling Stations',
                value: totalOwners.toString(),
                color: Colors.white,
                valueColor: const Color(0xFF0B63B7),
                labelColor: const Color(0xFF0B63B7),
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                label: 'Passed',
                value: approvedCount.toString(),
                color: Colors.white,
                valueColor: const Color(0xFF0B63B7),
                labelColor: const Color(0xFF0B63B7),
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                label: 'Failed',
                value: failedCount.toString(),
                color: Colors.white,
                valueColor: const Color(0xFF0B63B7),
                labelColor: const Color(0xFF0B63B7),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Water Refilling Stations\nIloilo City", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                const SizedBox(height: 12),
                _AreaStatRow(label: "La Paz", value: areaCounts['La Paz'] ?? 0, maxValue: 30),
                const SizedBox(height: 8),
                _AreaStatRow(label: "Mandurriao", value: areaCounts['Mandurriao'] ?? 0, maxValue: 30),
                const SizedBox(height: 8),
                _AreaStatRow(label: "Molo", value: areaCounts['Molo'] ?? 0, maxValue: 30),
                const SizedBox(height: 8),
                _AreaStatRow(label: "Lapuz", value: areaCounts['Lapuz'] ?? 0, maxValue: 30),
                const SizedBox(height: 8),
                _AreaStatRow(label: "Arevalo", value: areaCounts['Arevalo'] ?? 0, maxValue: 30),
                const SizedBox(height: 8),
                _AreaStatRow(label: "Jaro", value: areaCounts['Jaro'] ?? 0, maxValue: 30),
                const SizedBox(height: 8),
                _AreaStatRow(label: "City Proper", value: areaCounts['City Proper'] ?? 0, maxValue: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _SummaryCard(
          label: 'Total Water Refilling Stations',
          value: totalOwners.toString(),
          color: Colors.white,
          valueColor: const Color(0xFF0B63B7),
          labelColor: const Color(0xFF0B63B7),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Passed',
                value: approvedCount.toString(),
                color: Colors.white,
                valueColor: const Color(0xFF0B63B7),
                labelColor: const Color(0xFF0B63B7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Failed',
                value: failedCount.toString(),
                color: Colors.white,
                valueColor: const Color(0xFF0B63B7),
                labelColor: const Color(0xFF0B63B7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
          ),
          padding: const EdgeInsets.all(16),
          child: _CalendarWidget(),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
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
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Water Refilling Stations\nIloilo City", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
              const SizedBox(height: 12),
              _AreaStatRow(label: "La Paz", value: areaCounts['La Paz'] ?? 0, maxValue: 30),
              const SizedBox(height: 8),
              _AreaStatRow(label: "Mandurriao", value: areaCounts['Mandurriao'] ?? 0, maxValue: 30),
              const SizedBox(height: 8),
              _AreaStatRow(label: "Molo", value: areaCounts['Molo'] ?? 0, maxValue: 30),
              const SizedBox(height: 8),
              _AreaStatRow(label: "Lapuz", value: areaCounts['Lapuz'] ?? 0, maxValue: 30),
              const SizedBox(height: 8),
              _AreaStatRow(label: "Arevalo", value: areaCounts['Arevalo'] ?? 0, maxValue: 30),
              const SizedBox(height: 8),
              _AreaStatRow(label: "Jaro", value: areaCounts['Jaro'] ?? 0, maxValue: 30),
              const SizedBox(height: 8),
              _AreaStatRow(label: "City Proper", value: areaCounts['City Proper'] ?? 0, maxValue: 30),
            ],
          ),
        ),
      ],
    );
  }
}

// Widget classes remain the same
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
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const double cellSize = 44.0;
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final monthName = monthNames[now.month - 1];
    final year = now.year;
    final firstDayOfMonth = DateTime(year, now.month, 1);
    final startIndex = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(year, now.month + 1, 0).day;

    final List<List<String>> weeks = [];
    int day = 1;
    while (day <= daysInMonth) {
      final week = List<String>.filled(7, '');
      for (int i = 0; i < 7 && day <= daysInMonth; i++) {
        if (weeks.isEmpty && i < startIndex) continue;
        if (day <= daysInMonth) {
          week[i] = day.toString();
          day++;
        }
      }
      weeks.add(week);
    }

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(monthName, style: const TextStyle(color: Color(0xFF0B63B7), fontWeight: FontWeight.bold, fontSize: 20)),
              const Spacer(),
              Text(year.toString(), style: const TextStyle(color: Color(0xFF0B63B7), fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) => SizedBox(width: cellSize, child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)))).toList(),
          ),
          const SizedBox(height: 8),
          ...weeks.map((week) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: week.map((dayStr) {
                  final isToday = dayStr.isNotEmpty && int.tryParse(dayStr) == now.day;
                  return Container(
                    width: cellSize,
                    height: cellSize,
                    alignment: Alignment.center,
                    decoration: isToday ? BoxDecoration(color: const Color(0xFF0B63B7), borderRadius: BorderRadius.circular(10)) : null,
                    child: Text(dayStr, style: TextStyle(color: isToday ? Colors.white : (dayStr.isEmpty ? Colors.black38 : Colors.black87), fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                  );
                }).toList(),
              )),
        ],
      ),
    );
  }
}

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
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF0B63B7), fontWeight: FontWeight.w500, fontSize: 15))),
        ],
      ),
    );
  }
}

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
        Expanded(flex: 3, child: Text(label, style: const TextStyle(color: Color(0xFF0B63B7)))),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Container(height: 28, decoration: BoxDecoration(color: const Color(0xFFEAF6FF), borderRadius: BorderRadius.circular(6))),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(height: 28, decoration: BoxDecoration(color: const Color(0xFF0B63B7), borderRadius: BorderRadius.circular(6))),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(value.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage();
  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  String name = '';
  String role = '';
  String contact = '';
  String email = '';
  bool _loading = false;
  String? _docId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final col = FirebaseFirestore.instance.collection('cho_lgu');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await col.doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _docId = doc.id;
            name = (data?['name'] ?? data?['adminName'] ?? data?['displayName'] ?? '').toString();
            role = (data?['role'] ?? '').toString();
            contact = (data?['contact'] ?? data?['phone'] ?? '').toString();
            email = (data?['email'] ?? '').toString();
          });
          return;
        }
      }
      var snap = await col.where('admin', isEqualTo: true).limit(1).get();
      if (snap.docs.isEmpty) snap = await col.limit(1).get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first;
        final data = d.data();
        setState(() {
          _docId = d.id;
          name = (data['name'] ?? data['adminName'] ?? data['displayName'] ?? '').toString();
          role = (data['role'] ?? '').toString();
          contact = (data['contact'] ?? data['phone'] ?? '').toString();
          email = (data['email'] ?? '').toString();
        });
      }
    } catch (e) {
      debugPrint('Failed to load LGU profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      final col = FirebaseFirestore.instance.collection('cho_lgu');
      final data = {'name': name, 'role': role, 'contact': contact, 'email': email, 'admin': true, 'updatedAt': FieldValue.serverTimestamp()};
      final user = FirebaseAuth.instance.currentUser;
      if (_docId != null) {
        await col.doc(_docId).set(data, SetOptions(merge: true));
      } else if (user != null) {
        if ((data['email'] ?? '').toString().isEmpty && user.email != null) data['email'] = user.email!;
        await col.doc(user.uid).set(data, SetOptions(merge: true));
        _docId = user.uid;
      } else {
        final ref = await col.add(data);
        _docId = ref.id;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save profile')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
            ),
            child: const Text('Profile', style: TextStyle(color: Color(0xFF0B63B7), fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            onPressed: _loading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 32),
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
                );
              } else {
                return Column(
                  children: [
                    const CircleAvatar(radius: 48, backgroundColor: Color(0xFFEAF6FF), child: Icon(Icons.person, size: 48, color: Color(0xFF0B63B7))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.edit, color: Color(0xFF0B63B7), size: 16),
                        SizedBox(width: 6),
                        Text('Change Profile Picture', style: TextStyle(color: Color(0xFF0B63B7))),
                      ],
                    ),
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
                      ),
                    ),
                  ],
                );
              }
            },
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

class _ProfileFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;
  const _ProfileFieldRow({required this.label, required this.value, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))),
          Expanded(flex: 6, child: Text(value, style: const TextStyle(color: Colors.black87), overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.edit, color: Color(0xFF0B63B7)), onPressed: onEdit),
        ],
      ),
    );
  }
}
