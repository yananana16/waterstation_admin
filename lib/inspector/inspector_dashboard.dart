import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InspectorDashboard extends StatefulWidget {
  const InspectorDashboard({super.key});

  @override
  State<InspectorDashboard> createState() => _InspectorDashboardState();
}

class _InspectorDashboardState extends State<InspectorDashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0; // 0: Home, 1: Schedule, 2: Profile
  // Assigned stations will be loaded from Firestore (inspections assigned to the current inspector)
  List<Map<String, dynamic>> _assignedStations = [];
  bool _loadingAssigned = true;
  bool _showAllInspections = false;

  String _currentTime = DateFormat.jm().format(DateTime.now());
  late TabController _tabController;
  int _currentTab = 0; // 0: Today, 1: This Week, 2: This Month
  // Reusable color palette for the inspector dashboard
  static const Color _primary = Color(0xFF0B63B7);
  static const Color _doneColor = Color(0xFF2E8B57);
  static const Color _pendingColor = Color(0xFFF39C12);
  static const Color _missedColor = Color(0xFFEF4444);

  // Profile form state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String _profileEmail = '';
  String? _inspectorDocId;
  // Additional inspector fields to display
  String _displayName = '';
  String _firstName = '';
  String _lastName = '';
  String _inspectorNo = '';
  String _phone = '';
  String _inspectorUid = '';
  String _createdAtStr = '';
  String _updatedAtStr = '';
  // Editing state + controllers
  bool _editingProfile = false;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        _currentTab = _tabController.index;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tick();
      // Load assigned inspections; respect the current _showAllInspections flag
      _loadAssignedInspections(all: _showAllInspections);
      // also load inspector profile
      _loadInspectorProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _contactController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInspectorProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      _profileEmail = email;
      if (uid == null) return;

      // find inspector doc by uid where possible
      final snap = await FirebaseFirestore.instance.collection('inspectors').where('uid', isEqualTo: uid).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first;
        final data = d.data();
        _inspectorDocId = d.id;
        _displayName = (data['displayName'] ?? data['name'] ?? data['fullName'] ?? '').toString();
        _firstName = (data['firstName'] ?? '').toString();
        _lastName = (data['lastName'] ?? '').toString();
        _inspectorNo = (data['inspectorNo'] ?? data['inspectorNumber'] ?? '').toString();
        _phone = (data['phone'] ?? data['contact'] ?? '').toString();
        _inspectorUid = (data['uid'] ?? '').toString();
        // fill existing controllers for backward compatibility and edit fields
        _nameController.text = _displayName.isNotEmpty ? _displayName : ('${_firstName} ${_lastName}'.trim());
        _firstNameController.text = _firstName;
        _lastNameController.text = _lastName;
        _roleController.text = (data['role'] ?? '').toString();
        _contactController.text = _phone;
      } else {
        // optional: try to find by email if inspectors indexed differently
        final snap2 = await FirebaseFirestore.instance.collection('inspectors').where('email', isEqualTo: email).limit(1).get();
        if (snap2.docs.isNotEmpty) {
          final d = snap2.docs.first;
          final data = d.data();
          _inspectorDocId = d.id;
          _displayName = (data['displayName'] ?? data['name'] ?? data['fullName'] ?? '').toString();
          _firstName = (data['firstName'] ?? '').toString();
          _lastName = (data['lastName'] ?? '').toString();
          _inspectorNo = (data['inspectorNo'] ?? data['inspectorNumber'] ?? '').toString();
          _phone = (data['phone'] ?? data['contact'] ?? '').toString();
          _inspectorUid = (data['uid'] ?? '').toString();
          _nameController.text = _displayName.isNotEmpty ? _displayName : ('${_firstName} ${_lastName}'.trim());
          _firstNameController.text = _firstName;
          _lastNameController.text = _lastName;
          _roleController.text = (data['role'] ?? '').toString();
          _contactController.text = _phone;
        }
      }
      setState(() {});
    } catch (err) {
      debugPrint('Failed loading inspector profile: $err');
    }
  }

  Future<void> _saveInspectorProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      if (uid == null) return;

      final data = {
        'uid': uid,
        'email': email,
        'displayName': _nameController.text.trim(),
        'name': _nameController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'role': _roleController.text.trim(),
        'phone': _contactController.text.trim(),
        'contact': _contactController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_inspectorDocId != null) {
        await FirebaseFirestore.instance.collection('inspectors').doc(_inspectorDocId).set(data, SetOptions(merge: true));
      } else {
        // create new inspector doc with uid as id when possible
        try {
          await FirebaseFirestore.instance.collection('inspectors').doc(uid).set(data, SetOptions(merge: true));
          _inspectorDocId = uid;
        } catch (_) {
          final docRef = await FirebaseFirestore.instance.collection('inspectors').add(data);
          _inspectorDocId = docRef.id;
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      // update local state to reflect saved values
      _displayName = _nameController.text.trim();
      _firstName = _firstNameController.text.trim();
      _lastName = _lastNameController.text.trim();
      _phone = _contactController.text.trim();
      setState(() {
        _editingProfile = false;
      });
    } catch (err) {
      debugPrint('Failed saving inspector profile: $err');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: $err')));
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPwdController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newPwdController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmPwdController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final cur = currentPwdController.text;
                final nw = newPwdController.text;
                final cf = confirmPwdController.text;
                if (nw.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 6 characters')));
                  return;
                }
                if (nw != cf) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                try {
                  final email = user.email ?? _profileEmail;
                  if (email.isEmpty) throw 'No email available for reauthentication';
                  final cred = EmailAuthProvider.credential(email: email, password: cur);
                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(nw);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
                  Navigator.of(context).pop();
                } catch (err) {
                  debugPrint('Change password failed: $err');
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to change password: $err')));
                }
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
    currentPwdController.dispose();
    newPwdController.dispose();
    confirmPwdController.dispose();
  }

  /// Convert various stored date formats into a DateTime (if possible)
  DateTime? _toDateTime(dynamic raw) {
    if (raw == null) return null;
    try {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  /// Filter inspections based on the selected tab (today/this week/this month)
  List<Map<String, dynamic>> _filteredInspections() {
    final all = _assignedStations;
    final now = DateTime.now();
    DateTime start, end;
    if (_currentTab == 0) {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (_currentTab == 1) {
      // Week range (start = Monday)
      final weekday = now.weekday; // 1 = Monday
      start = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
      end = start.add(const Duration(days: 7));
    } else {
      // Month range
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 1);
    }

    return all.where((s) {
      final raw = s['date'];
      final dt = _toDateTime(raw);
      if (dt == null) return false;
      return (dt.isAtSameMomentAs(start) || (dt.isAfter(start) && dt.isBefore(end))) || (dt.isAfter(start) && dt.isBefore(end));
    }).toList();
  }

  /// Load inspections assigned to the current inspector.
  /// If [all] is true, list all inspections for that inspector, otherwise only upcoming (date >= today).
  Future<void> _loadAssignedInspections({bool all = false}) async {
    setState(() {
      _loadingAssigned = true;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Find inspector document by uid and read its 'id' field (preferred) to match inspections.officerId
      String inspectorLookupId = uid; // fallback to uid if inspector doc not found
      try {
        final inspSnap = await FirebaseFirestore.instance.collection('inspectors').where('uid', isEqualTo: uid).limit(1).get();
        if (inspSnap.docs.isNotEmpty) {
          final inspDoc = inspSnap.docs.first;
          // Use the inspector document id as the canonical lookup value. This
          // must match how inspections.officerId is stored in the DB so the
          // security rules can resolve /inspectors/{officerId}.
          inspectorLookupId = inspDoc.id;
        }
      } catch (err) {
        debugPrint('Error resolving inspector id by uid: $err');
      }

      final now = DateTime.now();
      // Build query: officerId == inspectorLookupId and optionally date >= today
      Query q = FirebaseFirestore.instance.collectionGroup('inspections').where('officerId', isEqualTo: inspectorLookupId).orderBy('date');
      if (!all) {
        q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, now.month, now.day)));
      }
      final snap = await q.limit(all ? 200 : 20).get();

      // Deduplicate collectionGroup results: some inspections are written
      // twice (top-level `inspections` and under `station_owners/{id}/inspections`).
      // We'll prefer the station-owner-scoped document when both exist for the
      // same station/month. Use a canonicalKey of '<stationId>::<monthlyInspectionMonth>' when available,
      // otherwise fall back to document path to dedupe.
      // First, collect raw inspection docs and determine any station_owner ids we
      // should fetch so we can enrich the UI with authoritative station/owner data.
      final raw = <Map<String, dynamic>>[];
      final ownerIds = <String>{};
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>?;
        final pathParts = d.reference.path.split('/');
        final isStationScoped = pathParts.length >= 4 && pathParts[pathParts.length - 3] != 'inspections';

        String candidateOwnerId = '';
        if (isStationScoped) {
          // path like 'station_owners/{ownerId}/inspections/{insId}'
          candidateOwnerId = pathParts[pathParts.length - 3];
        } else {
          candidateOwnerId = (data?['stationOwnerId'] ?? data?['ownerId'] ?? data?['stationOwner'] ?? '') as String? ?? '';
        }

  if (candidateOwnerId.isNotEmpty) ownerIds.add(candidateOwnerId);

        raw.add({'doc': d, 'data': data, 'pathParts': pathParts, 'isStationScoped': isStationScoped, 'ownerId': candidateOwnerId});
      }

      // Fetch owner documents in parallel (cache results)
      final Map<String, Map<String, dynamic>> ownerDocs = {};
      if (ownerIds.isNotEmpty) {
        await Future.wait(ownerIds.map((id) async {
          try {
            final snapOwner = await FirebaseFirestore.instance.collection('station_owners').doc(id).get();
            if (snapOwner.exists) ownerDocs[id] = snapOwner.data() as Map<String, dynamic>;
          } catch (err) {
            debugPrint('Error loading station_owner $id: $err');
          }
        }));
      }

      final Map<String, Map<String, dynamic>> keyed = {};
      for (final item in raw) {
        final d = item['doc'] as QueryDocumentSnapshot;
        final data = item['data'] as Map<String, dynamic>?;
  final isStationScoped = item['isStationScoped'] as bool;
        final candidateOwnerId = item['ownerId'] as String? ?? '';

        final stationId = (data?['stationId'] ?? data?['station'] ?? '') as String? ?? '';
        final monthKey = (data?['monthlyInspectionMonth'] ?? data?['month'] ?? '') as String? ?? '';
        final canonicalKey = (stationId != '' && monthKey != '') ? '$stationId::$monthKey' : d.reference.path;

        // Owner doc (if available)
        final ownerDoc = (candidateOwnerId.isNotEmpty && ownerDocs.containsKey(candidateOwnerId)) ? ownerDocs[candidateOwnerId] : null;

        // Build owner full name, preferring owner doc fields when present
        String ownerFirst = '';
        String ownerLast = '';
        if (ownerDoc != null) {
          ownerFirst = (ownerDoc['firstName'] ?? ownerDoc['stationOwnerFirstName'] ?? ownerDoc['ownerFirstName'] ?? '') as String? ?? '';
          ownerLast = (ownerDoc['lastName'] ?? ownerDoc['stationOwnerLastName'] ?? ownerDoc['ownerLastName'] ?? '') as String? ?? '';
        } else {
          ownerFirst = (data?['stationOwnerFirstName'] ?? data?['firstName'] ?? '') as String? ?? '';
          ownerLast = (data?['stationOwnerLastName'] ?? data?['lastName'] ?? '') as String? ?? '';
        }
  final ownerFull = ('$ownerFirst $ownerLast').trim();
        final ownerFallback = (data?['stationOwnerName'] ?? data?['ownerName'] ?? '') as String? ?? '';

        // Station name/address: prefer ownerDoc values when available
        final stationName = (ownerDoc != null ? (ownerDoc['stationName'] ?? ownerDoc['name']) : null) as String? ?? (data?['stationName'] ?? data?['stationNameOverride'] ?? data?['station'] ?? data?['stationId'] ?? 'Unknown Station');
        final address = (ownerDoc != null ? (ownerDoc['address'] ?? ownerDoc['location']) : null) as String? ?? (data?['address'] ?? data?['location'] ?? '');

        final entry = {
          'id': d.id,
          'stationName': stationName,
          'address': address,
          'location': data?['address'] ?? data?['location'] ?? '',
          'status': data?['status'] ?? 'Pending',
          'owner': ownerFull.isNotEmpty ? ownerFull : ownerFallback,
          'date': data?['date'],
          // Keep a list of all document paths that correspond to this inspection
          // so we can update both top-level and station-scoped copies when needed.
          'documentPaths': <String>[d.reference.path],
          'ownerId': candidateOwnerId,
          'isStationScoped': isStationScoped,
        };

        if (!keyed.containsKey(canonicalKey)) {
          keyed[canonicalKey] = entry;
        } else {
          final existing = keyed[canonicalKey]!;
          final existingScoped = existing['isStationScoped'] as bool? ?? false;
          // Merge documentPaths so we can update all copies later
          final List<String> existingPaths = List<String>.from(existing['documentPaths'] ?? <String>[]);
          if (!existingPaths.contains(d.reference.path)) existingPaths.add(d.reference.path);
          existing['documentPaths'] = existingPaths;

          // Prefer station-scoped doc when replacing base values, but still keep merged paths
          if (!existingScoped && isStationScoped) {
            // preserve merged documentPaths when replacing
            entry['documentPaths'] = existing['documentPaths'];
            keyed[canonicalKey] = entry;
          } else {
            // keep original entry but ensure its documentPaths are up-to-date
            existing['documentPaths'] = existingPaths;
            keyed[canonicalKey] = existing;
          }
        }
      }

      // Convert keyed map to list
      final list = keyed.values.map((e) {
        // convert to plain map (keep documentPaths so we can update all copies)
        final copy = Map<String, dynamic>.from(e);
        // ensure documentPaths exists and is a List<String>
        copy['documentPaths'] = List<String>.from(copy['documentPaths'] ?? <String>[]);
        return copy;
      }).toList();

      if (mounted) {
        setState(() {
        _assignedStations = list;
        _loadingAssigned = false;
      });
      }
    } catch (e) {
      debugPrint('Error loading assigned inspections: $e');
      if (mounted) {
        setState(() {
        _assignedStations = [];
        _loadingAssigned = false;
      });
      }
    }
  }

  void _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) break;
      setState(() {
        _currentTime = DateFormat.jm().format(DateTime.now());
      });
    }

  }

  // (removed unused modal helper to keep code focused on tabbed UI)

  // detail row helper removed (was used by a modal that's no longer present)

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
  // Color palette for consistent UI (use shared constants)
  final Color primary = _primary;
  final Color sidebarBg = const Color(0xFFF1F6FB); // softer, neutral sidebar
  // Softer backgrounds for lists and items - updated for better contrast
  final Color listBg = const Color(0xFFF8FAFB); // very light neutral tint for assigned-stations area
  final Color contentBg = const Color(0xFFF4F7F9); // page background slightly off-white
  final Color cardBg = const Color(0xFFFFFFFF); // card background (white)

    /// Sidebar
    Widget leftNav = Container(
      width: isWide ? 250 : null,
      decoration: BoxDecoration(
        color: sidebarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.10 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top spacer to match screenshot padding
            const SizedBox(height: 18),
            // Centered user info (avatar + labels)
            Container(
              width: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 28, backgroundColor: primary, child: const Icon(Icons.person, color: Colors.white, size: 28)),
                  const SizedBox(height: 8),
                  Text(_firstName.isNotEmpty ? _firstName : 'Admin', style: const TextStyle(color: Color(0xFF0B63B7), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(FirebaseAuth.instance.currentUser?.email ?? '', style: const TextStyle(color: Color(0xFF7A93B4), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE8F0FA), thickness: 1, height: 20),
            // Navigation centered
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  InkWell(onTap: () { setState(() => _selectedIndex = 0); if (!isWide) { Navigator.of(context).pop(); } }, child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text('Home', style: TextStyle(color: _selectedIndex == 0 ? const Color(0xFF0B63B7) : const Color(0xFF7A93B4), fontWeight: _selectedIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                  )),
                  InkWell(onTap: () { setState(() => _selectedIndex = 1); if (!isWide) { Navigator.of(context).pop(); } }, child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text('Schedule', style: TextStyle(color: _selectedIndex == 1 ? const Color(0xFF0B63B7) : const Color(0xFF7A93B4))),
                  )),
                  InkWell(onTap: () { setState(() => _selectedIndex = 2); if (!isWide) { Navigator.of(context).pop(); } }, child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text('Profile', style: TextStyle(color: _selectedIndex == 2 ? const Color(0xFF0B63B7) : const Color(0xFF7A93B4))),
                  )),
                ],
              ),
            ),
            const Spacer(),
            // Logout rounded pill
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0),
              child: SizedBox(
                width: 140,
                child: ElevatedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout, color: Color(0xFF0B63B7)),
                  label: const Text('Log out', style: TextStyle(color: Color(0xFF0B63B7))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    /// Header bar (styled similar to LGU dashboard top bar)
    Widget header = Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (!isWide)
              Builder(builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, color: primary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            }),
          const SizedBox(width: 3),
          Row(
            children: [
              // place date/time strip look similar to LGU dashboard (small rounded container)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  children: [
                    Text(_currentTime, style: TextStyle(fontWeight: FontWeight.w600, color: primary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
    );

    /// Main content
    Widget mainContent = Container(
      color: contentBg, // updated page background for softer contrast
      child: Padding(
        padding: EdgeInsets.all(isWide ? 16.0 : 12.0),
        child: Column(
          children: [
            if (_selectedIndex == 0) ...[
              // Date strip / greeting
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: isWide ? 18 : 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.03 * 255).round()), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    SizedBox(width: isWide ? 12 : 8),
                    Expanded(
                      child: Text('Hello, Inspector!', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: isWide ? 16 : 14)),
                    ),
                  ],
                ),
              ),

              // Main two-column layout (or stacked on mobile)
              Expanded(
                child: isWide 
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Assigned stations + reminders
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              // Assigned Stations card with date header
                              Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              color: listBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE6EDF2)),
                            ),
                            child: Column(
                              children: [
                                // header row (search + count + toggle)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.assignment_turned_in, color: primary),
                                            const SizedBox(width: 8),
                                            Text('Assigned Stations', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(width: 12),
                                            // small count badge
                                            if (!_loadingAssigned) Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: primary.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(12)),
                                              child: Text('${_assignedStations.length} items', style: TextStyle(fontSize: 12, color: primary)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // inline search (small)
                                      Container(
                                        width: 220,
                                        padding: const EdgeInsets.only(left: 8),
                                        child: TextField(
                                          decoration: InputDecoration(
                                            hintText: 'Search station',
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF0B63B7)),
                                          ),
                                          onChanged: (v) {
                                            // client-side filter; simple approach — re-filter list
                                            // (keeps original list in-state if you want server search later)
                                            setState(() {
                                              if (v.trim().isEmpty) {
                                                // reload to reset; could cache original list instead
                                                _loadAssignedInspections(all: _showAllInspections);
                                              } else {
                                                _assignedStations = _assignedStations.where((s) => (s['stationName'] ?? '').toString().toLowerCase().contains(v.toLowerCase())).toList();
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Toggle to show all inspections or only upcoming
                                      IconButton(
                                        tooltip: 'Toggle show all inspections',
                                        onPressed: () {
                                          setState(() => _showAllInspections = !_showAllInspections);
                                          _loadAssignedInspections(all: _showAllInspections);
                                        },
                                        icon: Icon(_showAllInspections ? Icons.list : Icons.filter_list, color: primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: Color(0xFFECECEC)),
                                // TabBar for Today / This Week / This Month
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: TabBar(
                                    controller: _tabController,
                                    labelColor: _primary,
                                    unselectedLabelColor: Colors.black54,
                                    indicatorColor: _primary,
                                    tabs: const [
                                      Tab(text: 'Today'),
                                      Tab(text: 'This Week'),
                                      Tab(text: 'This Month'),
                                    ],
                                  ),
                                ),
                                // Animated content area
                                SizedBox(
                                  height: 320,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    transitionBuilder: (child, animation) {
                                      final inAnim = Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation);
                                      return FadeTransition(opacity: animation, child: SlideTransition(position: inAnim, child: child));
                                    },
                                    child: _loadingAssigned
                                        ? Center(key: const ValueKey('loading'), child: Padding(padding: const EdgeInsets.all(24.0), child: CircularProgressIndicator(color: _primary)))
                                        : _buildInspectionsView(_filteredInspections(), key: ValueKey('list_${_currentTab}_${_assignedStations.length}'), isWide: isWide),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Reminders card
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right: Calendar + Profile summary
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Summary cards row
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  color: cardBg,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('This Week', style: TextStyle(fontSize: 12, color: Color(0xFF0B63B7))),
                                        const SizedBox(height: 8),
                                        Text(
                                          (() {
                                            final now = DateTime.now().toUtc().add(const Duration(hours: 8));
                                            final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
                                            final endOfWeek = startOfWeek.add(const Duration(days: 7));
                                            return _assignedStations.where((s) {
                                              final dt = _toDateTime(s['date']);
                                              if (dt == null) return false;
                                              return dt.isAfter(startOfWeek) && dt.isBefore(endOfWeek);
                                            }).length.toString();
                                          })(),
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Scheduled', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Card(
                                  color: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pending', style: TextStyle(fontSize: 12, color: Color(0xFF0B63B7))),
                                        const SizedBox(height: 8),
                                        Text(
                                          (() {
                                            final now = DateTime.now().toUtc().add(const Duration(hours: 8));
                                            final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
                                            final endOfWeek = startOfWeek.add(const Duration(days: 7));
                                            return _assignedStations.where((s) {
                                              final status = (s['status'] ?? '').toString().toLowerCase();
                                              final dt = _toDateTime(s['date']);
                                              if (dt == null) return false;
                                              return status == 'pending' && dt.isAfter(startOfWeek) && dt.isBefore(endOfWeek);
                                            }).length.toString();
                                          })(),
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Needs action', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Card(
                                  color: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Completed', style: TextStyle(fontSize: 12, color: Color(0xFF0B63B7))),
                                        const SizedBox(height: 8),
                                        Text(
                                          (() {
                                            final now = DateTime.now().toUtc().add(const Duration(hours: 8));
                                            final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
                                            final endOfWeek = startOfWeek.add(const Duration(days: 7));
                                            return _assignedStations.where((s) {
                                              final status = (s['status'] ?? '').toString().toLowerCase();
                                              final dt = _toDateTime(s['date']);
                                              if (dt == null) return false;
                                              return status == 'done' && dt.isAfter(startOfWeek) && dt.isBefore(endOfWeek);
                                            }).length.toString();
                                          })(),
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('This week', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Calendar card (simple placeholder like LGU)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(DateFormat.MMMM().format(DateTime.now()), style: const TextStyle(color: Color(0xFF0B63B7), fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Text(DateTime.now().year.toString(), style: const TextStyle(color: Colors.black54)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(height: 160, child: Center(child: Text('📅 Calendar placeholder', style: TextStyle(color: Colors.black54)))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Profile summary
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFFE0E0E0))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Email: ${_profileEmail.isNotEmpty ? _profileEmail : "-"}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          // Summary cards (mobile)
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  color: cardBg,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Done', style: TextStyle(fontSize: 11, color: Color(0xFF2E8B57))),
                                        const SizedBox(height: 6),
                                        Text(
                                          _assignedStations.where((s) {
                                            final status = (s['status'] ?? '').toString().toLowerCase();
                                            final dt = _toDateTime(s['date']);
                                            if (dt == null) return false;
                                            final now = DateTime.now();
                                            return status == 'done' && dt.month == now.month && dt.year == now.year;
                                          }).length.toString(),
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Card(
                                  color: cardBg,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pending', style: TextStyle(fontSize: 11, color: Color(0xFFF39C12))),
                                        const SizedBox(height: 6),
                                        Text(
                                          _assignedStations.where((s) => (s['status'] ?? '').toString().toLowerCase() == 'pending').length.toString(),
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Card(
                                  color: cardBg,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Missed', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                                        const SizedBox(height: 6),
                                        Text(
                                          _assignedStations.where((s) {
                                            final status = (s['status'] ?? '').toString().toLowerCase();
                                            return status == 'missed';
                                          }).length.toString(),
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Assigned Stations (mobile)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              color: listBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE6EDF2)),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(Icons.assignment_turned_in, color: primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Assigned Stations', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const Spacer(),
                                      if (!_loadingAssigned)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: primary.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(12)),
                                          child: Text('${_assignedStations.length}', style: TextStyle(fontSize: 11, color: primary)),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        iconSize: 20,
                                        tooltip: 'Toggle show all',
                                        onPressed: () {
                                          setState(() => _showAllInspections = !_showAllInspections);
                                          _loadAssignedInspections(all: _showAllInspections);
                                        },
                                        icon: Icon(_showAllInspections ? Icons.list : Icons.filter_list, color: primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: Color(0xFFECECEC)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: TabBar(
                                    controller: _tabController,
                                    labelColor: _primary,
                                    unselectedLabelColor: Colors.black54,
                                    indicatorColor: _primary,
                                    labelStyle: const TextStyle(fontSize: 12),
                                    tabs: const [
                                      Tab(text: 'Today'),
                                      Tab(text: 'Week'),
                                      Tab(text: 'Month'),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 320,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    transitionBuilder: (child, animation) {
                                      final inAnim = Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation);
                                      return FadeTransition(opacity: animation, child: SlideTransition(position: inAnim, child: child));
                                    },
                                    child: _loadingAssigned
                                        ? Center(key: const ValueKey('loading'), child: Padding(padding: const EdgeInsets.all(24.0), child: CircularProgressIndicator(color: _primary)))
                                        : _buildInspectionsView(_filteredInspections(), key: ValueKey('list_${_currentTab}_${_assignedStations.length}'), isWide: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Reminders (mobile)
                        ],
                      ),
                    ),
              ),
            ] else if (_selectedIndex == 1) ...[
              _whiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Row(
                          children: [
                            const Text('Show all'),
                            const SizedBox(width: 8),
                            Switch(
                              value: _showAllInspections,
                              onChanged: (v) async {
                                setState(() {
                                  _showAllInspections = v;
                                });
                                await _loadAssignedInspections(all: _showAllInspections);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Content: either loading, empty-calendar placeholder, or inspections list
                    if (_loadingAssigned)
                      SizedBox(height: 240, child: Center(child: CircularProgressIndicator(color: _primary)))
                    else if (_assignedStations.isEmpty)
                      SizedBox(height: 240, child: Center(child: Text('No scheduled inspections found.', style: TextStyle(color: Colors.black54))))
                    else
                      // show list of assigned inspections in a table-like layout
                      SizedBox(
                        height: isWide ? 360 : 400,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              // header row (only on wide screens)
                              if (isWide)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                                  child: Row(
                                    children: const [
                                    Expanded(flex: 3, child: Text('Station', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('Owner', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    SizedBox(width: 56),
                                    ],
                                  ),
                                ),
                              if (isWide)
                                const Divider(height: 1),
                              // rows
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 4),
                                  itemCount: _assignedStations.length,
                                  separatorBuilder: (_, __) => isWide ? const Divider(height: 1) : const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final s = _assignedStations[i];
                                    if (!isWide) {
                                      // Mobile: use inspection cards
                                      return _inspectionCard(s, onTap: () => _showInspectionModal(s));
                                    }
                                    // Desktop: use table row
                                    final dt = _toDateTime(s['date']);
                                    final status = (s['status'] ?? 'Pending').toString();
                                    final done = status.toLowerCase().contains('done');
                                    final bg = i.isEven ? Colors.white : const Color(0xFFF8FAFB);
                                    final initials = (s['stationName'] ?? '').toString().trim().split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
                                    return Material(
                                      color: bg,
                                      child: InkWell(
                                        onTap: () => _showInspectionModal(s),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
                                          child: Row(
                                            children: [
                                              // avatar + station name
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(radius: 18, backgroundColor: _primary, child: Text(initials.isEmpty ? 'S' : initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                                    const SizedBox(width: 10),
                                                    Flexible(child: Text(s['stationName'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                                  ],
                                                ),
                                              ),
                                              Expanded(flex: 2, child: Text(s['owner'] ?? '', style: const TextStyle(fontSize: 13))),
                                              Expanded(flex: 2, child: Text(_formatDateTime(dt), style: const TextStyle(fontSize: 13, color: Colors.black54))),
                                              Expanded(
                                                flex: 1,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: _statusColor(status).withAlpha((0.14 * 255).round()),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700, fontSize: 12)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 48,
                                                child: IconButton(
                                                  tooltip: 'Mark as Done',
                                                  icon: Icon(Icons.check, color: done ? Colors.grey : _doneColor),
                                                  onPressed: done ? null : () => _markAsDoneQuick(s['id'] ?? ''),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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
            ] else ...[
              _whiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Row(children: [
                              if (!_editingProfile)
                                TextButton.icon(onPressed: () { setState(() { _editingProfile = true; }); }, icon: const Icon(Icons.edit), label: const Text('Edit')),
                              const SizedBox(width: 6),
                              OutlinedButton.icon(onPressed: _showChangePasswordDialog, icon: const Icon(Icons.lock_outline), label: const Text('Change Password')),
                            ])
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_editingProfile) ...[
                          // editable fields
                          TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First name')),
                          const SizedBox(height: 8),
                          TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last name')),
                          const SizedBox(height: 8),
                          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display name')),
                          const SizedBox(height: 8),
                          TextField(controller: _roleController, decoration: const InputDecoration(labelText: 'Role')),
                          const SizedBox(height: 8),
                          TextField(controller: _contactController, decoration: const InputDecoration(labelText: 'Phone')),
                          const SizedBox(height: 12),
                          Row(children: [
                            ElevatedButton(onPressed: () async { await _saveInspectorProfile(); }, child: const Text('Save')),
                            const SizedBox(width: 8),
                            OutlinedButton(onPressed: () { 
                              // revert changes
                              _firstNameController.text = _firstName;
                              _lastNameController.text = _lastName;
                              _nameController.text = _displayName.isNotEmpty ? _displayName : ('${_firstName} ${_lastName}'.trim());
                              _roleController.text = _roleController.text; // keep current
                              _contactController.text = _phone;
                              setState(() { _editingProfile = false; });
                            }, child: const Text('Cancel')),
                          ]),
                        ] else ...[
                          // read-only display
                          _profileLine('Display Name', _displayName),
                          const SizedBox(height: 8),
                          _profileLine('First Name', _firstName),
                          const SizedBox(height: 8),
                          _profileLine('Last Name', _lastName),
                          const SizedBox(height: 8),
                          _profileLine('Inspector No.', _inspectorNo),
                          const SizedBox(height: 8),
                          _profileLine('Role', _roleController.text),
                          const SizedBox(height: 8),
                          _profileLine('Email', _profileEmail),
                          const SizedBox(height: 8),
                          _profileLine('Phone', _phone),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      drawer: isWide ? null : Drawer(child: leftNav),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide) leftNav,
            Expanded(
              child: Column(
                children: [
                  header,
                  Expanded(child: mainContent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _profileLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text('$label', style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 12),
        Expanded(child: Text(value.isNotEmpty ? value : '-', style: const TextStyle(color: Colors.black87))),
      ],
    );
  }

  /// Sign out the current user and navigate to the first route
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }


  /// Build inspections view: responsive layout and empty state
  Widget _buildInspectionsView(List<Map<String, dynamic>> items, {Key? key, bool isWide = true}) {
    if (items.isEmpty) {
      return Container(
        key: key,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 120, child: Image.asset('assets/location_illustration.png', fit: BoxFit.contain)),
              const SizedBox(height: 16),
              Text('No inspections found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
              const SizedBox(height: 8),
              const Text('You have no inspections for the selected period. Enjoy your free time!'),
            ],
          ),
        ),
      );
    }

    // Responsive: list on narrow, grid on wide
    if (!isWide) {
      return ListView.separated(
        key: key,
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _inspectionCard(items[i], onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InspectionDetailPage(data: items[i])))),
      );
    }

    // Grid for wide screens
    return Padding(
      key: key,
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 3),
        itemCount: items.length,
        itemBuilder: (context, i) => _inspectionCard(items[i], onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InspectionDetailPage(data: items[i])))),
      ),
    );
  }

  Widget _inspectionCard(Map<String, dynamic> s, {required VoidCallback onTap}) {
    final stationName = s['stationName'] ?? 'Unknown Station';
    final owner = s['owner'] ?? '';
    final status = (s['status'] ?? 'Pending') as String;
    final dt = _toDateTime(s['date']);
    final datetimeStr = _formatDateTime(dt);

    Color badgeColor = _statusColor(status);
  // improved colors: use neutral white card background by default
  final Color cardTint = Colors.white;
    final Color avatarBg = _primary; // keep primary blue for avatar
    final Color nameColor = const Color(0xFF0F1724); // dark slate for title
    final Color ownerColor = Colors.blueGrey.shade600;

    return GestureDetector(
      onTap: () => _showInspectionModal(s),
      child: Card(
        color: cardTint,
  shadowColor: Colors.black.withAlpha((0.06 * 255).round()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(radius: 26, backgroundColor: avatarBg, child: Text(_initials(stationName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(stationName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: nameColor)),
                    const SizedBox(height: 4),
                    Text(owner, style: TextStyle(color: ownerColor, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.blueGrey.shade300),
                        const SizedBox(width: 6),
                        Text(datetimeStr, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha((0.14 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withAlpha((0.20 * 255).round())),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: HSLColor.fromColor(badgeColor).withLightness((HSLColor.fromColor(badgeColor).lightness - 0.08).clamp(0.0, 1.0)).toColor(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInspectionModal(Map<String, dynamic> inspection) {
    final id = inspection['id'] as String? ?? '';
    final stationName = inspection['stationName'] ?? 'Unknown Station';
    final owner = inspection['owner'] ?? '';
    final status = (inspection['status'] ?? 'Pending').toString();
    final dt = _toDateTime(inspection['date']);
    final datetimeStr = _formatDateTime(dt);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Inspection details',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6, maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.08 * 255).round()), blurRadius: 24)]),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // header strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)), color: Color(0xFFF3F7FB)),
                    child: Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: _primary, child: Text(_initials(stationName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(stationName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1724)))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _statusColor(status).withAlpha((0.12 * 255).round()), borderRadius: BorderRadius.circular(18)), child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Color(0xFF6B7280))),
                    ]),
                  ),

                  // body
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.person_outline, size: 18, color: Colors.blueGrey.shade300),
                        const SizedBox(width: 8),
                        Text(owner, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Icon(Icons.schedule, size: 18, color: Colors.blueGrey.shade300),
                        const SizedBox(width: 8),
                        Text(datetimeStr, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                      ]),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 12),
                      // Placeholder for extra details — keep minimal and readable
                      Text('Inspection details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                      const SizedBox(height: 8),
                      Text(inspection['notes'] ?? 'No additional notes available.', style: const TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(height: 18),
                      // actions
                      Row(children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Close', style: TextStyle(color: Color(0xFF0B63B7))),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: status.toLowerCase().contains('done')
                              ? null
                              : () async {
                                  // optimistic UI: mark done locally and close modal
                                  setState(() {
                                    for (var i = 0; i < _assignedStations.length; i++) {
                                      if ((_assignedStations[i]['id'] ?? '') == id) {
                                        _assignedStations[i]['status'] = 'Done';
                                        break;
                                      }
                                    }
                                  });
                                  Navigator.of(context).pop();

                                  // find the local item we changed to get its documentPaths
                                  final localIdx = _assignedStations.indexWhere((it) => (it['id'] ?? '') == id);
                                  final List<String> docPaths = localIdx != -1 ? List<String>.from(_assignedStations[localIdx]['documentPaths'] ?? <String>[]) : <String>[];

                                  // Try to update all recorded document paths in a batch
                                  bool updateSucceeded = false;
                                  String prevStatus = status;
                                  if (docPaths.isNotEmpty) {
                                    try {
                                      final batch = FirebaseFirestore.instance.batch();
                                      for (final p in docPaths) {
                                        final ref = FirebaseFirestore.instance.doc(p);
                                        batch.update(ref, {'status': 'Done'});
                                      }
                                      await batch.commit();
                                      updateSucceeded = true;
                                    } catch (err) {
                                      debugPrint('Batch update failed, will try individual updates: $err');
                                      // fallback: try one-by-one
                                      for (final p in docPaths) {
                                        try {
                                          await FirebaseFirestore.instance.doc(p).update({'status': 'Done'});
                                          updateSucceeded = true;
                                        } catch (e) {
                                          debugPrint('Failed updating $p: $e');
                                        }
                                      }
                                    }
                                  }

                                  final snack = SnackBar(
                                    content: Text('Marked "$stationName" as done.${updateSucceeded ? '' : ' (local only — failed to update server)'}'),
                                    action: SnackBarAction(label: 'Undo', onPressed: () async {
                                      // revert locally first
                                      setState(() {
                                        for (var i = 0; i < _assignedStations.length; i++) {
                                          if ((_assignedStations[i]['id'] ?? '') == id) {
                                            _assignedStations[i]['status'] = prevStatus;
                                            break;
                                          }
                                        }
                                      });

                                      // revert on server if we succeeded earlier
                                      if (updateSucceeded && docPaths.isNotEmpty) {
                                        try {
                                          final batch = FirebaseFirestore.instance.batch();
                                          for (final p in docPaths) {
                                            final ref = FirebaseFirestore.instance.doc(p);
                                            batch.update(ref, {'status': prevStatus});
                                          }
                                          await batch.commit();
                                        } catch (err) {
                                          debugPrint('Failed to undo updates on server: $err');
                                          // best-effort: try individually
                                          for (final p in docPaths) {
                                            try {
                                              await FirebaseFirestore.instance.doc(p).update({'status': prevStatus});
                                            } catch (_) {}
                                          }
                                        }
                                      }
                                    }),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(snack);
                                },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Mark as Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _doneColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ])
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final tween = Tween(begin: const Offset(0, 0.03), end: Offset.zero).chain(CurveTween(curve: Curves.easeOut));
        return FadeTransition(opacity: anim, child: SlideTransition(position: anim.drive(tween), child: child));
      },
    );
  }

  /// Quick mark-as-done helper used by the table action button.
  Future<void> _markAsDoneQuick(String id) async {
    if (id.isEmpty) return;
    // optimistic UI update
    String prevStatus = 'Pending';
    final idx = _assignedStations.indexWhere((it) => (it['id'] ?? '') == id);
    if (idx == -1) return;
    prevStatus = (_assignedStations[idx]['status'] ?? 'Pending').toString();
    setState(() {
      _assignedStations[idx]['status'] = 'Done';
    });

    // try to update all recorded document paths
    final List<String> docPaths = List<String>.from(_assignedStations[idx]['documentPaths'] ?? <String>[]);
    bool updateSucceeded = false;
    if (docPaths.isNotEmpty) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final p in docPaths) {
          final ref = FirebaseFirestore.instance.doc(p);
          batch.update(ref, {'status': 'Done'});
        }
        await batch.commit();
        updateSucceeded = true;
      } catch (err) {
        debugPrint('Batch update failed: $err');
        // fallback: try individually
        for (final p in docPaths) {
          try {
            await FirebaseFirestore.instance.doc(p).update({'status': 'Done'});
            updateSucceeded = true;
          } catch (e) {
            debugPrint('Failed updating $p: $e');
          }
        }
      }
    }

    final snack = SnackBar(
      content: Text('Marked "${_assignedStations[idx]['stationName'] ?? ''}" as done.${updateSucceeded ? '' : ' (local only)'}'),
      action: SnackBarAction(label: 'Undo', onPressed: () async {
        setState(() {
          _assignedStations[idx]['status'] = prevStatus;
        });
        if (updateSucceeded && docPaths.isNotEmpty) {
          try {
            final batch = FirebaseFirestore.instance.batch();
            for (final p in docPaths) {
              final ref = FirebaseFirestore.instance.doc(p);
              batch.update(ref, {'status': prevStatus});
            }
            await batch.commit();
          } catch (err) {
            debugPrint('Failed to undo on server: $err');
            for (final p in docPaths) {
              try {
                await FirebaseFirestore.instance.doc(p).update({'status': prevStatus});
              } catch (_) {}
            }
          }
        }
      }),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'TBD';
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('done') || s.contains('completed')) return _doneColor;
    if (s.contains('miss') || s.contains('missed')) return _missedColor;
    // default pending
    return _pendingColor;
  }

}

/// Placeholder detail page for an inspection
class InspectionDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const InspectionDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final dt = data['date'];
    String datetimeStr = '';
    try {
      if (dt is Timestamp) {
        datetimeStr = DateFormat.yMMMd().add_jm().format(dt.toDate());
      } else if (dt is DateTime) datetimeStr = DateFormat.yMMMd().add_jm().format(dt);
      else if (dt is String) datetimeStr = dt;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(title: Text(data['stationName'] ?? 'Inspection')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['stationName'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Owner: ${data['owner'] ?? ''}'),
          const SizedBox(height: 8),
          Text('Scheduled: $datetimeStr'),
          const SizedBox(height: 12),
          Text('Status: ${data['status'] ?? 'Pending'}'),
          const SizedBox(height: 20),
          const Text('Details placeholder — implement inspection details here.'),
        ]),
      ),
    );
  }

// Sidebar button widget removed — sidebar now uses centered InkWell text items to match design.
}