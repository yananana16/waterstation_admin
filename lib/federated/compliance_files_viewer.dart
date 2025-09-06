import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplianceFilesViewer extends StatefulWidget {
  final String stationOwnerDocId;
  final VoidCallback? onStatusChanged; // Add this line
  const ComplianceFilesViewer({super.key, required this.stationOwnerDocId, this.onStatusChanged});

  @override
  State<ComplianceFilesViewer> createState() => _ComplianceFilesViewerState();
}

class _ComplianceFilesViewerState extends State<ComplianceFilesViewer> {
  List<FileObject> uploadedFiles = [];
  bool isLoading = true;
  // ignore: unused_field
  final Set<int> _expandedIndexes = {};
  Map<String, dynamic> complianceStatuses = {};
  Map<String, String> statusEdits = {}; // Track dropdown edits
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchComplianceFiles(widget.stationOwnerDocId);
    fetchComplianceStatuses(widget.stationOwnerDocId);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> fetchComplianceFiles(String docId) async {
    try {
      final response = await Supabase.instance.client.storage
          .from('compliance_docs')
          .list(path: 'uploads/$docId');
      setState(() {
        uploadedFiles = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchComplianceStatuses(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(docId)
          .get();
      if (doc.exists) {
        setState(() {
          complianceStatuses = doc.data() ?? {};
        });
      }
    } catch (e) {
      // ignore error, just leave complianceStatuses empty
    }
  }

  Future<void> updateStatus(String statusKey, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(widget.stationOwnerDocId)
          .set({statusKey: newStatus}, SetOptions(merge: true));
      setState(() {
        complianceStatuses[statusKey] = newStatus;
        statusEdits.remove(statusKey);
      });

      // After updating, check statuses
      final doc = await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(widget.stationOwnerDocId)
          .get();
      final data = doc.data() ?? {};
      final statusValues = data.entries
          .where((e) => e.key.endsWith('_status'))
          .map((e) => (e.value ?? '').toString().toLowerCase())
          .toList();

      String stationStatus;
      String message;

      if (statusValues.isNotEmpty && statusValues.every((s) => s == 'partially')) {
        stationStatus = 'district_approved';
        message = 'Station marked as District Approved.';
      } else if (statusValues.any((s) => s == 'failed')) {
        stationStatus = 'failed';
        message = 'Station marked as Failed.';
      } else if (statusValues.any((s) => s == 'pending')) {
        stationStatus = 'pending_approval';
        message = 'Station marked as Pending Approval.';
      } else if (statusValues.isNotEmpty && statusValues.every((s) => s == 'passed')) {
        stationStatus = 'approved';
        message = 'Station marked as Approved.';
      } else {
        stationStatus = 'district_approved';
        message = 'Status updated. Station marked as District Approved.';
      }

      // Fetch previous status before updating
      final prevStationDoc = await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(widget.stationOwnerDocId)
          .get();
      final prevStatus = prevStationDoc.data()?['status']?.toString() ?? '';

      await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(widget.stationOwnerDocId)
          .update({'status': stationStatus});

      // Only show dialog if status actually changed
      if (prevStatus != stationStatus) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: Colors.white,
            child: SizedBox(
              width: 340,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.blueAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Status Updated',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (widget.onStatusChanged != null) {
                            widget.onStatusChanged!(); // Notify parent to refresh
                          }
                        },
                        child: const Text('OK', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      // else do nothing (no dialog)
    } catch (e) {
      // Improved error dialog design
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to update status',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  /// Returns a tuple: (categoryKey, displayLabel)
  (String, String) _extractCategoryKeyAndLabel(String fileName, String docId) {
    // Normalize and remove extension
    final base = fileName.split('/').last;
    final noExt = base.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final lower = noExt.toLowerCase();

    // Known categories -> clean display labels
    const known = <String, String>{
      'business_permit': 'Business Permit',
      'certificate_of_association': 'Certificate Of Association',
      'finished_bacteriological': 'Finished Bacteriological',
      'finished_physical_chemical': 'Finished Physical Chemical',
      'sanitary_permit': 'Sanitary Permit',
      'source_bacteriological': 'Source Bacteriological',
      'source_physical_chemical': 'Source Physical Chemical',
    };

    // Fast path: if any known key is already present anywhere in the raw lower name
    for (final k in known.keys) {
      if (lower.contains(k)) {
        return (k, known[k]!);
      }
    }

    // Build a sanitized string removing common prefixes and date/id parts
    String sanitized = lower;

    // Drop leading "station_owner", optional separators, and the docId if present
    sanitized = sanitized.replaceFirst(RegExp(r'^station_owner[_-]?'), '');
    if (docId.isNotEmpty) {
      sanitized = sanitized.replaceFirst(RegExp('^${RegExp.escape(docId)}[_-]?'), '');
    }

    // Remove leading date-like tokens and generic numeric prefixes:
    // YYYY-MM-DD_, MM-DD_, YYYYMMDD_, or any leading digits_
    sanitized = sanitized
        .replaceFirst(RegExp(r'^\d{4}[-_]\d{2}[-_]\d{2}[-_]?'), '')
        .replaceFirst(RegExp(r'^\d{2}[-_]\d{2}[-_]?'), '')
        .replaceFirst(RegExp(r'^\d{8}[-_]?'), '')
        .replaceFirst(RegExp(r'^\d+[-_]?'), '');

    // Try matching known keys again on the sanitized form
    for (final k in known.keys) {
      if (sanitized.contains(k)) {
        return (k, known[k]!);
      }
    }

    // Try building candidates from right-most segments (handles multi-word keys)
    final parts = sanitized.split(RegExp(r'[_-]+')).where((e) => e.isNotEmpty).toList();
    for (int i = 0; i < parts.length; i++) {
      final candidate = parts.sublist(i).join('_');
      if (known.containsKey(candidate)) {
        return (candidate, known[candidate]!);
      }
    }

    // Fallback: humanize sanitized string
    final displayLabel = parts
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ')
        .trim();
    return (sanitized.isEmpty ? 'unknown' : sanitized, displayLabel.isEmpty ? 'Unknown Category' : displayLabel);
  }

  void _showFileDialog(FileObject file, String fileUrl, bool isImage, bool isPdf, bool isWord) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: 600,
            height: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: isImage
                        ? Image.network(
                            fileUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Failed to load image'),
                                ),
                          )
                        : isPdf
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 64),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open PDF'),
                                    onPressed: () async {
                                      if (await canLaunchUrl(Uri.parse(fileUrl))) {
                                        await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not open file')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              )
                            : isWord
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.description, color: Colors.blue, size: 64),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Open Document'),
                                        onPressed: () async {
                                          if (await canLaunchUrl(Uri.parse(fileUrl))) {
                                            await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Could not open file')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : const Text('Unsupported file type', style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(fileUrl))) {
                      await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not download file')),
                      );
                    }
                  },
                ),
              ],
            ),
          ));
        },
      );
  }

  // Visual helpers
  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'passed':
        return const Color(0xFF2E7D32); // green
      case 'failed':
        return const Color(0xFFC62828); // red
      case 'pending':
        return const Color(0xFFF9A825); // amber
      case 'partially':
      default:
        return const Color(0xFF1565C0); // blue
    }
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _fileIconColor(String ext) {
    switch (ext) {
      case 'pdf':
        return const Color(0xFFD32F2F);
      case 'doc':
      case 'docx':
        return const Color(0xFF1565C0);
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF5E5E5E);
    }
  }

  // UPDATED: add compact variant (to match district dropdown design)
  Widget _buildStatusChip(String? status, {bool compact = false}) {
    final color = _statusColor(status);
    final text = (status ?? 'Partially');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(compact ? 0.08 : 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(compact ? 0.30 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: compact ? 5 : 6, height: compact ? 5 : 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : uploadedFiles.isEmpty
              ? const Center(child: Text('No uploaded compliance files found.'))
              : Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(uploadedFiles.length, (index) {
                              final file = uploadedFiles[index];
                              final fileUrl = Supabase.instance.client.storage
                                  .from('compliance_docs')
                                  .getPublicUrl('uploads/${widget.stationOwnerDocId}/${file.name}');
                              final extension = file.name.split('.').last.toLowerCase();
                              final isImage = ['png', 'jpg', 'jpeg'].contains(extension);
                              final isPdf = extension == 'pdf';
                              final isWord = extension == 'doc' || extension == 'docx';
                              final (categoryKey, categoryLabel) = _extractCategoryKeyAndLabel(file.name, widget.stationOwnerDocId);

                              final statusKey = '${categoryKey}_status';
                              final rawStatus = (statusEdits[statusKey] ?? complianceStatuses[statusKey] ?? 'Partially').toString();
                              final status = rawStatus.isNotEmpty
                                  ? '${rawStatus[0].toUpperCase()}${rawStatus.substring(1).toLowerCase()}'
                                  : null;

                              // NEW: derive accent colors/icons
                              final accent = _statusColor(status);
                              final icon = _fileIcon(extension);
                              final iconColor = _fileIconColor(extension);

                              // New: read-only date fields
                              final dateIssued = (complianceStatuses['${categoryKey}_date_issued'] ?? '').toString();
                              final validUntil = (complianceStatuses['${categoryKey}_valid_until'] ?? '').toString();

                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Container(
                                  width: 240,
                                  height: 360,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        const Color(0xFFF7FAFF),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    // left accent
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: accent.withOpacity(0.85), width: 5),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header: icon + category + status chip
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: iconColor.withOpacity(0.10),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(icon, color: iconColor, size: 20),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  categoryLabel,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0D47A1),
                                                    fontSize: 14,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatusChip(status),
                                            ],
                                          ),

                                          const SizedBox(height: 14),

                                          // File type hero icon (subtle)
                                          Expanded(
                                            child: Center(
                                              child: Icon(
                                                icon,
                                                color: iconColor.withOpacity(0.35),
                                                size: 64,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          // View button
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                _showFileDialog(file, fileUrl, isImage, isPdf, isWord);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF1565C0),
                                                side: const BorderSide(color: Color(0xFFBBDEFB)),
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              icon: const Icon(Icons.visibility_outlined),
                                              label: const Text('View File'),
                                            ),
                                          ),

                                          // New: display-only issued/validity
                                          const SizedBox(height: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.event_note, size: 16, color: Colors.black54),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'Date Issued: ${dateIssued.isEmpty ? '—' : dateIssued}',
                                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.event_available, size: 16, color: Colors.black54),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'Validity Until: ${validUntil.isEmpty ? '—' : validUntil}',
                                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          // REPLACED: dropdown with district design, keeping federated options
                                          DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            alignment: Alignment.centerLeft,
                                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                                            menuMaxHeight: 320,
                                            // Only set initialValue if it is a supported option
                                            initialValue: const ['Pending', 'Passed', 'Partially', 'Failed'].contains(status) ? status : null,
                                            decoration: InputDecoration(
                                              labelText: 'Status',
                                              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                                              hintText: 'Select status',
                                              filled: true,
                                              fillColor: accent.withOpacity(0.05),
                                              prefixIcon: Padding(
                                                padding: const EdgeInsets.only(left: 12, right: 8),
                                                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                                              ),
                                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: accent.withOpacity(0.30)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: accent, width: 1.6),
                                              ),
                                            ),
                                            selectedItemBuilder: (context) {
                                              // Must match items length (header + divider + 4 options)
                                              final opts = ['__header', '__div', 'Pending', 'Passed', 'Partially', 'Failed'];
                                              return opts.map((opt) {
                                                switch (opt) {
                                                  case '__header':
                                                  case '__div':
                                                    return const SizedBox.shrink();
                                                  default:
                                                    return Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: _buildStatusChip(opt, compact: true),
                                                    );
                                                }
                                              }).toList();
                                            },
                                            items: [
                                              // Header (not selectable)
                                              DropdownMenuItem<String>(
                                                value: '__header',
                                                enabled: false,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: const [
                                                      Text('Select a status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87)),
                                                      SizedBox(height: 2),
                                                      Text('Choose the current evaluation result', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Divider (not selectable)
                                              const DropdownMenuItem<String>(
                                                value: '__div',
                                                enabled: false,
                                                child: Divider(height: 1, thickness: 1),
                                              ),
                                              // Options (federated keeps Passed)
                                              ...['Pending', 'Passed', 'Partially', 'Failed'].map((opt) {
                                                final color = _statusColor(opt);
                                                final subtitle = {
                                                  'Pending': 'Waiting for review',
                                                  'Passed': 'Meets requirements',
                                                  'Partially': 'Some requirements incomplete',
                                                  'Failed': 'Does not meet requirements',
                                                }[opt]!;
                                                final isSelected = opt == status;
                                                return DropdownMenuItem<String>(
                                                  value: opt,
                                                  child: Row(
                                                    children: [
                                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(opt, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                            const SizedBox(height: 2),
                                                            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                                          ],
                                                        ),
                                                      ),
                                                      if (isSelected) ...[
                                                        const SizedBox(width: 10),
                                                        Icon(Icons.check_rounded, size: 18, color: color),
                                                      ],
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                if (value != null && value != '__header' && value != '__div') {
                                                  statusEdits[statusKey] = value;
                                                }
                                              });
                                            },
                                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                                            dropdownColor: Colors.white,
                                          ),

                                          const SizedBox(height: 10),

                                          // Save button
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: statusEdits.containsKey(statusKey)
                                                  ? () {
                                                      final newStatus = statusEdits[statusKey]!;
                                                      updateStatus(statusKey, newStatus);
                                                    }
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: accent,
                                                disabledBackgroundColor: const Color(0xFFB0BEC5),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                elevation: 0,
                                              ),
                                              icon: const Icon(Icons.save_outlined),
                                              label: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}