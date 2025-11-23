// All imports are now at the top
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_repository.dart';

import 'package:url_launcher/url_launcher.dart';
import '../utils/email_sender.dart';
const String backendUrl = 'https://email-backend-qhq3.onrender.com/send-email';
class ComplianceFilesViewer extends StatefulWidget {
  final String stationOwnerDocId;
  final VoidCallback? onStatusChanged; // callback when a status is saved
  final bool isDistrictAdmin; // role flag: true => restrict 'Passed' selection & disable when already passed
  const ComplianceFilesViewer({
    super.key,
    required this.stationOwnerDocId,
    this.onStatusChanged,
    this.isDistrictAdmin = false,
  });

  @override
  State<ComplianceFilesViewer> createState() => _ComplianceFilesViewerState();
}

class _ComplianceFilesViewerState extends State<ComplianceFilesViewer> {
  DateTime? _tryParseFlexibleDate(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (isoMatch != null) {
      final y = int.tryParse(isoMatch.group(1)!);
      final m = int.tryParse(isoMatch.group(2)!);
      final d = int.tryParse(isoMatch.group(3)!);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    final parts = s.split('/');
    if (parts.length == 3) {
      final mm = int.tryParse(parts[0]);
      final dd = int.tryParse(parts[1]);
      final yy = int.tryParse(parts[2]);
      if (mm != null && dd != null && yy != null) {
        try {
          return DateTime(yy, mm, dd);
        } catch (_) {}
      }
    } else if (parts.length == 2) {
      final mm = int.tryParse(parts[0]);
      final yy = int.tryParse(parts[1]);
      if (mm != null && yy != null) {
        try {
          return DateTime(yy, mm, 1);
        } catch (_) {}
      }
    }
    final rawDigits = RegExp(r'^(\d{8})$').firstMatch(s);
    if (rawDigits != null) {
      final str = rawDigits.group(1)!;
      final y = int.tryParse(str.substring(0, 4));
      final m = int.tryParse(str.substring(4, 6));
      final d = int.tryParse(str.substring(6, 8));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return null;
  }

  String _formatIso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isExpired(String? validUntilStr) {
    if (validUntilStr == null || validUntilStr.isEmpty) return false;
    final validDate = _tryParseFlexibleDate(validUntilStr);
    if (validDate == null) return false;
    return validDate.isBefore(DateTime.now());
  }

  Future<void> sendFailedFilesEmail(Map<String, dynamic> complianceStatuses) async {
    // Fetch owner info
    final ownerDoc = await FirestoreRepository.instance.getDocumentOnce(
      'station_owners/${widget.stationOwnerDocId}',
      () => FirebaseFirestore.instance.collection('station_owners').doc(widget.stationOwnerDocId),
    );
  final ownerData = ownerDoc.data() as Map<String, dynamic>?;
  final recipientEmail = ownerData?['email']?.toString() ?? '';
  final stationName = ownerData?['stationName']?.toString() ?? '';
    if (recipientEmail.isEmpty) return;

    // Collect failed files with details (normalize dates to ISO where possible)
    final failedFiles = complianceStatuses.entries
        .where((e) => e.key.endsWith('_status') && (e.value?.toString().toLowerCase() == 'failed'))
        .map((e) {
          final key = e.key.replaceAll('_status', '');
          final category = key.replaceAll('_', ' ').replaceFirst(key[0], key[0].toUpperCase());
          final rawDate = (complianceStatuses['${key}_date_issued'] ?? '').toString();
          final rawValid = (complianceStatuses['${key}_valid_until'] ?? '').toString();
          final parsedDate = _tryParseFlexibleDate(rawDate);
          final parsedValid = _tryParseFlexibleDate(rawValid);
          return {
            'category': category,
            'dateIssued': parsedDate != null ? _formatIso(parsedDate) : rawDate,
            'validUntil': parsedValid != null ? _formatIso(parsedValid) : rawValid,
          };
        })
        .toList();
    if (failedFiles.isEmpty) return;

    // Build HTML table rows
    final rows = failedFiles.map((f) =>
      '<tr>'
        '<td style="padding:8px 12px;border:1px solid #e0e0e0;">${f['category']}</td>'
        '<td style="padding:8px 12px;border:1px solid #e0e0e0;">${f['dateIssued']}</td>'
      '</tr>'
    ).join();

    final body = '''
    <div style="font-family: Arial, sans-serif; background: #f4f8fb; padding: 32px;">
      <div style="max-width: 520px; margin: auto; background: #fff; border-radius: 12px; box-shadow: 0 2px 8px #0001; padding: 32px 24px;">
        <div style="text-align: center; margin-bottom: 18px;">
          <div style="font-size: 48px; color: #c62828;">⚠️</div>
          <h2 style="color: #c62828; margin: 0 0 8px 0;">Compliance File(s) Failed</h2>
        </div>
        <p style="font-size: 16px; color: #222; margin-bottom: 18px;">Dear Station Owner,</p>
        <p style="font-size: 15px; color: #444; margin-bottom: 18px;">
          The following compliance file(s) for your station <b>${stationName.isNotEmpty ? stationName : ''}</b> did not meet the necessary requirements. Please check the validity and the date issued, and re-upload the correct documents.
        </p>
        <table style="width:100%;border-collapse:collapse;margin-bottom:24px;">
          <thead>
            <tr style="background:#fbe9e7;">
              <th style="padding:10px 12px;border:1px solid #e0e0e0;text-align:left;">Category</th>
              <th style="padding:10px 12px;border:1px solid #e0e0e0;text-align:left;">Date Issued</th>
              <th style="padding:10px 12px;border:1px solid #e0e0e0;text-align:left;">Valid Until</th>
            </tr>
          </thead>
          <tbody>
            $rows
          </tbody>
        </table>
        <p style="font-size: 15px; color: #555; margin-bottom: 0;">Thank you for your attention.<br><b>H2OGO Compliance Team</b></p>
      </div>
    </div>
    ''';
    sendApprovalEmail(
      recipientEmail,
      stationName,
      customBody: body,
      customSubject: 'Some Compliance Files Failed Requirements',
    );
  }
  bool get _hasFailedFiles => complianceStatuses.entries.any((e) => e.key.endsWith('_status') && (e.value?.toString().toLowerCase() == 'failed'));
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
      final doc = await FirestoreRepository.instance.getDocumentOnce(
        'compliance_uploads/$docId',
        () => FirebaseFirestore.instance.collection('compliance_uploads').doc(docId),
      );
      if (doc.exists) {
        setState(() {
          complianceStatuses = (doc.data() as Map<String, dynamic>?) ?? {};
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
      final doc = await FirestoreRepository.instance.getDocumentOnce(
        'compliance_uploads/${widget.stationOwnerDocId}',
        () => FirebaseFirestore.instance.collection('compliance_uploads').doc(widget.stationOwnerDocId),
      );
    final data = doc.data() as Map<String, dynamic>? ?? {};
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
        stationStatus = 'submitreq';
        message = 'Station marked as Submit Failed.';
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
      final prevStationDoc = await FirestoreRepository.instance.getDocumentOnce(
        'station_owners/${widget.stationOwnerDocId}',
        () => FirebaseFirestore.instance.collection('station_owners').doc(widget.stationOwnerDocId),
      );
      final prevStatus = (prevStationDoc.data() as Map<String, dynamic>?)?['status']?.toString() ?? '';

      await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(widget.stationOwnerDocId)
          .update({'status': stationStatus});

      // Only show dialog and send email if status actually changed
      if (prevStatus != stationStatus) {
        // Send email if approved
        if (stationStatus == 'approved') {
          // Fetch email and station name from Firestore
          final ownerDoc = await FirestoreRepository.instance.getDocumentOnce(
            'station_owners/${widget.stationOwnerDocId}',
            () => FirebaseFirestore.instance.collection('station_owners').doc(widget.stationOwnerDocId),
          );
          final ownerData = ownerDoc.data() as Map<String, dynamic>?;
          final recipientEmail = ownerData?['email']?.toString() ?? '';
          final stationName = ownerData?['station_name']?.toString() ?? '';
          if (recipientEmail.isNotEmpty) {
            sendApprovalEmail(recipientEmail, stationName);
          }
        }
        // Ensure station is marked active when approved
        await FirebaseFirestore.instance
            .collection('station_owners')
            .doc(widget.stationOwnerDocId)
            .update({'status': stationStatus, 'isActive': true});

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
      'health_card': 'Health Card',
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
                                      final uri = Uri.parse(fileUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context).showSnackBar(
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
                                          final uri = Uri.parse(fileUrl);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          } else {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(this.context).showSnackBar(
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
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Enlarge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (isImage) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _FullScreenImageViewer(imageUrl: fileUrl, title: file.name),
                      ));
                    } else {
                      final uri = Uri.parse(fileUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Could not open file')),
                        );
                      }
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
  Color _statusColor(String? status, {bool isExpired = false}) {
    if (isExpired) return const Color(0xFF8B0000); // dark red for expired
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }

  // UPDATED: add compact variant (to match district dropdown design)
  Widget _buildStatusChip(String? status, {bool compact = false, bool isExpired = false}) {
    final color = _statusColor(status, isExpired: isExpired);
    final text = isExpired ? 'Expired' : (status ?? 'Partially');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
  color: color.withAlpha(((compact ? 0.08 : 0.10) * 255).round()),
        borderRadius: BorderRadius.circular(100),
  border: Border.all(color: color.withAlpha(((compact ? 0.30 : 0.35) * 255).round())),
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
                    if (_hasFailedFiles)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.email),
                          label: const Text('Send Email'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => sendFailedFilesEmail(complianceStatuses),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status Legend:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _buildLegendItem('Passed', const Color(0xFF2E7D32)),
                                _buildLegendItem('Failed', const Color(0xFFC62828)),
                                _buildLegendItem('Pending', const Color(0xFFF9A825)),
                                _buildLegendItem('Partially', const Color(0xFF1565C0)),
                                _buildLegendItem('Expired', const Color(0xFF8B0000)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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

                              // New: read-only date fields (normalize to ISO if possible)
                              final rawDateIssued = (complianceStatuses['${categoryKey}_date_issued'] ?? '').toString();
                              final rawValidUntil = (complianceStatuses['${categoryKey}_valid_until'] ?? '').toString();
                              final parsedDateIssued = _tryParseFlexibleDate(rawDateIssued);
                              final parsedValidUntil = _tryParseFlexibleDate(rawValidUntil);
                              final dateIssued = parsedDateIssued != null ? _formatIso(parsedDateIssued) : rawDateIssued;
                              final validUntil = parsedValidUntil != null ? _formatIso(parsedValidUntil) : rawValidUntil;

                              // Check if file is expired
                              final isExpired = _isExpired(rawValidUntil);

                              // NEW: derive accent colors/icons
                              final accent = _statusColor(status, isExpired: isExpired);
                              final icon = _fileIcon(extension);
                              final iconColor = _fileIconColor(extension);

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
                                        color: Colors.black.withAlpha((0.04 * 255).round()),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    // left accent
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: accent.withAlpha((0.85 * 255).round()), width: 5),
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
                                                  color: iconColor.withAlpha((0.10 * 255).round()),
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
                                              _buildStatusChip(status, isExpired: isExpired),
                                            ],
                                          ),

                                          const SizedBox(height: 14),

                                          // File type hero icon (subtle)
                                          Expanded(
                                            child: Center(
                                              child: Icon(
                                                icon,
                                                color: iconColor.withAlpha((0.35 * 255).round()),
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
                                            // Role-based options
                                            // Federated: Pending, Passed, Partially, Failed
                                            // District: Pending, Partially, Failed (exclude Passed)
                                            // If district and status == Passed we disable dropdown entirely.
                                            initialValue: widget.isDistrictAdmin
                                                ? (const ['Pending', 'Partially', 'Failed'].contains(status) ? status : null)
                                                : (const ['Pending', 'Passed', 'Partially', 'Failed'].contains(status) ? status : null),
                                            decoration: InputDecoration(
                                              labelText: 'Status',
                                              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                                              hintText: 'Select status',
                                              filled: true,
                                              fillColor: accent.withAlpha((0.05 * 255).round()),
                                              prefixIcon: Padding(
                                                padding: const EdgeInsets.only(left: 12, right: 8),
                                                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                                              ),
                                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: accent.withAlpha((0.30 * 255).round())),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: accent, width: 1.6),
                                              ),
                                            ),
                                            selectedItemBuilder: (context) {
                                              // Build list matching item sequence
                                              final baseOpts = widget.isDistrictAdmin
                                                  ? ['Pending', 'Partially', 'Failed']
                                                  : ['Pending', 'Passed', 'Partially', 'Failed'];
                                              final opts = ['__header', '__div', ...baseOpts];
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
                                              // Role-based options
                                              ...(widget.isDistrictAdmin
                                                  ? ['Pending', 'Partially', 'Failed']
                                                  : ['Pending', 'Passed', 'Partially', 'Failed']).map((opt) {
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
                                            onChanged: (widget.isDistrictAdmin && (status?.toLowerCase() == 'passed'))
                                                ? null
                                                : (value) {
                                                    setState(() {
                                                      if (value != null && value != '__header' && value != '__div') {
                                                        statusEdits[statusKey] = value;
                                                      }
                                                    });
                                                  },
                                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                                            dropdownColor: Colors.white,
                                            disabledHint: Align(
                                              alignment: Alignment.centerLeft,
                                              child: _buildStatusChip(status, compact: true),
                                            ),
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

/// Full screen image viewer used when user taps "Enlarge"
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String title;
  const _FullScreenImageViewer({required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stack) => const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.white))),
          ),
        ),
      ),
    );
  }
}
