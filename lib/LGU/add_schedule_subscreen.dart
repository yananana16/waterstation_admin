import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_repository.dart';

class AddScheduleSubscreen extends StatefulWidget {
  final VoidCallback? onClose;
  const AddScheduleSubscreen({super.key, this.onClose});

  @override
  State<AddScheduleSubscreen> createState() => _AddScheduleSubscreenState();
}

class _AddScheduleSubscreenState extends State<AddScheduleSubscreen> {
  String? _selectedStationId;
  String? _selectedOfficerId;
  DateTime _selectedDate = DateTime.now();
  final String _status = 'Pending';
  bool _isSaving = false;
  String _stationSearch = '';
  List<QueryDocumentSnapshot>? _stationListCache;
  Set<String>? _assignedStationIds;
  bool _showPendingOnly = true;

  Future<List<QueryDocumentSnapshot>> _loadStations() async {
    final snap = await FirestoreRepository.instance.getCollectionOnce(
      'station_owners',
      () => FirebaseFirestore.instance.collection('station_owners').orderBy('stationName'),
    );
    return snap.docs;
  }

  @override
  void initState() {
    super.initState();
    // warm up station list cache
    _loadStations().then((list) {
      if (mounted) setState(() => _stationListCache = list);
    }).catchError((e) { debugPrint('Error loading stations: $e'); });
    // load assigned stations for current month
    _loadAssignedStationsForMonth(DateTime.now()).catchError((e) => debugPrint('Error loading assigned stations: $e'));
  }

  Future<void> _loadAssignedStationsForMonth(DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));
    final firestore = FirebaseFirestore.instance;
    final seen = <String>{};

    try {
      // use collectionGroup to include both top-level 'inspections' and station subcollection 'inspections'
      final cacheKey = 'inspections_month_${month.year}-${month.month}';
      final snap = await FirestoreRepository.instance.getCollectionOnce(cacheKey, () => firestore.collectionGroup('inspections')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd)));
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>?;
        // determine station id - prefer explicit stationId field
        final stationId = (data?['stationId'] ?? data?['station'] ?? data?['station_owner_id'])?.toString();
        final officer = data?['officer'] ?? data?['officerId'] ?? data?['assignedOfficer'] ?? '';
        final status = data?['status'] ?? '';
        if (stationId != null) {
          // consider assigned if officer present or status Done
          if ((officer is String && officer.toString().trim().isNotEmpty) || status == 'Done') {
            seen.add(stationId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error querying inspections collectionGroup: $e');
    }

    if (mounted) setState(() => _assignedStationIds = seen);
  }

  List<QueryDocumentSnapshot> _filterStations(List<QueryDocumentSnapshot> list, String q) {
    if (q.trim().isEmpty) return list;
    final lq = q.toLowerCase();
    return list.where((d) {
      final map = d.data() as Map<String, dynamic>;
      final name = (map['stationName'] ?? map['displayName'] ?? '').toString().toLowerCase();
      final district = (map['districtName'] ?? '').toString().toLowerCase();
      final matches = name.contains(lq) || district.contains(lq) || d.id.toLowerCase().contains(lq);
      if (!matches) return false;
      // if showPendingOnly is enabled and assignedStationIds is loaded, exclude assigned stations
      if (_showPendingOnly && _assignedStationIds != null && _assignedStationIds!.contains(d.id)) return false;
      return true;
    }).toList();
  }

  Widget _buildStationList(List<QueryDocumentSnapshot> list, double scale) {
    if (list.isEmpty) return const Center(child: Text('No stations found'));
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: 6 * scale),
      itemBuilder: (context, idx) {
        final d = list[idx];
        final map = d.data() as Map<String, dynamic>;
        final title = (map['stationName'] ?? map['displayName'] ?? d.id).toString();
        final subtitle = (map['districtName'] ?? '').toString();
        final selected = _selectedStationId == d.id;
        return ListTile(
          tileColor: selected ? const Color(0xFFEAF6FF) : null,
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
          trailing: selected ? const Icon(Icons.check, color: Color(0xFF0B63B7)) : null,
          onTap: () => setState(() {
            _selectedStationId = d.id;
          }),
        );
      },
    );
  }

  Future<List<QueryDocumentSnapshot>> _loadInspectors() async {
    final snap = await FirestoreRepository.instance.getCollectionOnce(
      'inspectors',
      () => FirebaseFirestore.instance.collection('inspectors').orderBy('lastName'),
    );
    return snap.docs;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveSchedule() async {
    if (_selectedStationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a station')));
      return;
    }
    if (_selectedOfficerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an officer')));
      return;
    }

    setState(() => _isSaving = true);
  final firestore = FirebaseFirestore.instance;

    // create a new inspection doc id
    final insRef = firestore.collection('inspections').doc();
    final stationInsRef = firestore.collection('station_owners').doc(_selectedStationId).collection('inspections').doc(insRef.id);

    final inspectorDoc = await FirestoreRepository.instance.getDocumentOnce(
      'inspectors/$_selectedOfficerId',
      () => firestore.collection('inspectors').doc(_selectedOfficerId),
    );
    final inspectorName = (inspectorDoc.exists && inspectorDoc.data() != null)
        ? ((inspectorDoc.data() as Map<String, dynamic>)['displayName'] ?? '${inspectorDoc['firstName'] ?? ''} ${inspectorDoc['lastName'] ?? ''}')
        : '';

    // compute month key like "2025-09" based on selected date
    final monthKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';

    final payload = {
      'stationId': _selectedStationId,
      'officerId': _selectedOfficerId,
      'officerName': inspectorName,
      'date': Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)),
      'status': _status,
      // monthlyInspectionMonth stores canonical month key like '2025-09'
      'monthlyInspectionMonth': monthKey,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final stationRef = firestore.collection('station_owners').doc(_selectedStationId);

    try {
      // Pre-check: run a collectionGroup query to find any existing inspection
      // for the same station and month. This catches duplicates whether the
      // inspection was stored top-level or under station_owners/{id}/inspections.
      try {
        final existing = await firestore.collectionGroup('inspections')
          .where('stationId', isEqualTo: _selectedStationId)
          .where('monthlyInspectionMonth', isEqualTo: monthKey)
          .limit(1)
          .get();
        if (existing.docs.isNotEmpty) {
          // Very likely a duplicate already exists; abort early and notify.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A schedule already exists for $monthKey')));
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      } catch (e) {
        // If the pre-check fails (network/rules), continue to transaction which
        // will still enforce the monthKey guard stored on the station doc.
        debugPrint('Pre-check for duplicate inspections failed: $e');
      }

      // Use a transaction to avoid race conditions: read station doc and ensure monthKey not already present
      await firestore.runTransaction((tx) async {
        final stationSnap = await tx.get(stationRef);
        final existing = stationSnap.exists && stationSnap.data() != null ? stationSnap.data()!['monthlyInspections'] : null;
        if (existing is List && existing.contains(monthKey)) {
          // already scheduled for this month
          throw StateError('already_scheduled');
        }

        // write inspection docs and update station monthlyInspections atomically
        tx.set(insRef, payload);
        tx.set(stationInsRef, payload);
        tx.update(stationRef, {'monthlyInspections': FieldValue.arrayUnion([monthKey])});
      });

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule saved')));
  if (widget.onClose != null) widget.onClose!();
    } on StateError catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A schedule already exists for $monthKey')));
    } catch (e) {
      debugPrint('Error saving schedule: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving schedule')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
                    if (widget.onClose != null) widget.onClose!();
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
                    FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _loadStations(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
                        final stations = snap.data!;
                        return _fieldRow(
                          'Station:',
                          DropdownButton<String>(
                            value: _selectedStationId,
                            isExpanded: true,
                            hint: const Text('Select station'),
                            items: stations.map((d) {
                              final map = d.data() as Map<String, dynamic>;
                              final label = map['stationName'] ?? map['displayName'] ?? d.id;
                              return DropdownMenuItem(value: d.id, child: Text(label.toString()));
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedStationId = v),
                          ),
                          labelWidth,
                          scale,
                        );
                      },
                    ),
                    _fieldRow(
                      'Date',
                      Row(
                        children: [
                          Expanded(child: Text('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale))),
                          SizedBox(width: 8 * scale),
                          IconButton(onPressed: _pickDate, icon: Icon(Icons.calendar_today, color: const Color(0xFF0B63B7), size: 20 * scale)),
                        ],
                      ),
                      labelWidth,
                      scale,
                    ),
                    FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _loadInspectors(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
                        final inspectors = snap.data!;
                        return _fieldRow(
                          'Officer:',
                          DropdownButton<String>(
                            value: _selectedOfficerId,
                            isExpanded: true,
                            hint: const Text('Select officer'),
                            items: inspectors.map((d) {
                              final map = d.data() as Map<String, dynamic>;
                              final label = map['displayName'] ?? '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}';
                              return DropdownMenuItem(value: d.id, child: Text(label.toString()));
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedOfficerId = v),
                          ),
                          labelWidth,
                          scale,
                        );
                      },
                    ),
                    // Status is fixed to 'Pending' by default and cannot be changed in the scheduling UI.
                    _fieldRow(
                      'Status',
                      // Read-only display to prevent changes
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 12 * scale),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6 * scale), border: Border.all(color: Colors.grey.shade300)),
                        child: Text(_status, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
                      ),
                      labelWidth,
                      scale,
                    ),
                    const SizedBox(height: 18),
                    // Search field for stations
                    Container(
                      margin: EdgeInsets.only(bottom: 12 * scale),
                      child: Row(
                        children: [
                          Container(
                            width: labelWidth,
                            padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 16 * scale),
                            color: const Color(0xFFF2F6FA),
                            child: Text('Search Stations', style: TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF0B63B7), fontSize: 14 * scale)),
                          ),
                          SizedBox(width: 12 * scale),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search by name or district',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6 * scale)),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 12 * scale),
                              ),
                              onChanged: (v) => setState(() => _stationSearch = v.trim()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stations list (filtered)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12 * scale),
                      padding: EdgeInsets.all(12 * scale),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEEEEEE)), borderRadius: BorderRadius.circular(8 * scale)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stations', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0B63B7))),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 240 * scale,
                            child: Column(
                              children: [
                                // toggle to show only pending/unassigned stations
                                Row(
                                  children: [
                                    Expanded(child: SizedBox()),
                                    Text('Show pending only', style: TextStyle(color: const Color(0xFF0B63B7))),
                                    Switch(
                                      value: _showPendingOnly,
                                      activeThumbColor: const Color(0xFF0B63B7),
                                      onChanged: (v) async {
                                        setState(() => _showPendingOnly = v);
                                        // if we don't have assigned station ids yet, load them
                                        if (_assignedStationIds == null) await _loadAssignedStationsForMonth(DateTime.now());
                                      },
                                    ),
                                    SizedBox(width: 8 * scale),
                                  ],
                                ),
                                Expanded(
                                  child: _stationListCache == null
                                ? FutureBuilder<List<QueryDocumentSnapshot>>(
                                    future: _loadStations(),
                                    builder: (context, snap) {
                                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                      final list = snap.data!;
                                      final filtered = _filterStations(list, _stationSearch);
                                      return _buildStationList(filtered, scale);
                                    },
                                  )
                                : _buildStationList(_filterStations(_stationListCache!, _stationSearch), scale),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSchedule,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
                          child: _isSaving ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Add Schedule', style: TextStyle(fontSize: 14 * scale)),
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

