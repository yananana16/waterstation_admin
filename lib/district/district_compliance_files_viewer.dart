import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:url_launcher/url_launcher.dart';
import '../utils/email_sender.dart';

class ComplianceFilesViewer extends StatefulWidget {
  final String stationOwnerDocId;
  final VoidCallback? onStatusChanged; // optional callback for parent refresh
  const ComplianceFilesViewer({super.key, required this.stationOwnerDocId, this.onStatusChanged});

  @override
  State<ComplianceFilesViewer> createState() => _ComplianceFilesViewerState();
}

class _ComplianceFilesViewerState extends State<ComplianceFilesViewer> {
  bool _isSendingEmail = false;
  bool _emailSent = false;
  bool get _hasFailedFiles => complianceStatuses.entries.any((e) => e.key.endsWith('_status') && (e.value?.toString().toLowerCase() == 'failed'));

  Future<void> sendFailedFilesEmail(Map<String, dynamic> complianceStatuses) async {
    if (_emailSent || _isSendingEmail) return;
    setState(() {
      _isSendingEmail = true;
    });
    // Fetch owner info
    final ownerDoc = await FirebaseFirestore.instance
        .collection('station_owners')
        .doc(widget.stationOwnerDocId)
        .get();
    final ownerData = ownerDoc.data();
    final recipientEmail = ownerData?['email']?.toString() ?? '';
    final stationName = ownerData?['station_name']?.toString() ?? '';
    if (recipientEmail.isEmpty) return;

    // Collect failed files with details
    final failedFiles = complianceStatuses.entries
        .where((e) => e.key.endsWith('_status') && (e.value?.toString().toLowerCase() == 'failed'))
        .map((e) {
          final key = e.key.replaceAll('_status', '');
          final category = key.replaceAll('_', ' ').replaceFirst(key[0], key[0].toUpperCase());
          final dateIssued = complianceStatuses['${key}_date_issued'] ?? '';
          final validUntil = complianceStatuses['${key}_valid_until'] ?? '';
          return {
            'category': category,
            'dateIssued': dateIssued,
            'validUntil': validUntil,
          };
        })
        .toList();
    if (failedFiles.isEmpty) return;

    // Build HTML table rows
    final rows = failedFiles.map((f) =>
      '<tr>'
        '<td style="padding:8px 12px;border:1px solid #e0e0e0;">${f['category']}</td>'
        '<td style="padding:8px 12px;border:1px solid #e0e0e0;">${f['dateIssued']}</td>'
        '<td style="padding:8px 12px;border:1px solid #e0e0e0;">${f['validUntil']}</td>'
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
        <p style="font-size: 15px; color: #555; margin-bottom: 0;">
          Thank you for your attention.<br>
          <b>From the District President</b><br>
          <b>H2OGO Compliance Team</b>
        </p>
      </div>
    </div>
    ''';
    await sendApprovalEmail(
      recipientEmail,
      stationName,
      customBody: body,
      customSubject: 'Some Compliance Files Failed Requirements',
    );
    setState(() {
      _emailSent = true;
      _isSendingEmail = false;
    });
    // Improved dialog design
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_read_rounded, color: Colors.green, size: 48),
                const SizedBox(height: 14),
                const Text(
                  'Email Sent Successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'The station owner has been notified about the failed compliance files.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('OK', style: TextStyle(fontSize: 15)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  List<FileObject> uploadedFiles = [];
  bool isLoading = true;
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

      // Derive overall station status from all *_status fields
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
        stationStatus = 'submitreq'; // Backend status for failed
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

      // Compare with previous status
      final prevStationDoc = await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(widget.stationOwnerDocId)
          .get();
      final prevStatus = prevStationDoc.data()?['status']?.toString() ?? '';

      await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(widget.stationOwnerDocId)
          .update({'status': stationStatus});

      // Show success dialog only if changed
      if (prevStatus != stationStatus) {
        if (!mounted) return;
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
                          widget.onStatusChanged?.call();
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
    } catch (e) {
      if (!mounted) return;
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
        ));
    }
  }

  /// Returns a tuple: (canonicalCategoryKey, displayLabel)
  /// canonicalCategoryKey is guaranteed to match Firestore fields like:
  ///   <canonicalCategoryKey>_status (e.g., business_permit_status)
  (String, String) _extractCategoryKeyAndLabel(String fileName, String docId) {
    // Lowercase everything for matching
    String lower = fileName.toLowerCase();
    final prefix = '${docId}_'.toLowerCase();

    // Strip the "<docId>_" prefix if present, otherwise use the whole filename
    String rest = lower.startsWith(prefix) ? lower.substring(prefix.length) : lower;

    // Remove extension for matching
    String base = rest.split('.').first;

    const known = <String, String>{
      'business_permit': 'Business Permit',
      'certificate_of_association': 'Certificate Of Association',
      'finished_bacteriological': 'Finished Bacteriological',
      'finished_physical_chemical': 'Finished Physical Chemical',
      'sanitary_permit': 'Sanitary Permit',
      'source_bacteriological': 'Source Bacteriological',
      'source_physical_chemical': 'Source Physical Chemical',
    };

    // First pass: direct contains on base
    for (final entry in known.entries) {
      if (base.contains(entry.key)) {
        // Return canonical key so "<key>_status" matches Firestore fields
        return (entry.key, entry.value);
        }
    }

    // Normalize separators and strip leading dates/ids like "2024-09-01_" or "123_"
    var cleaned = base
        .replaceAll('-', '_')
        .replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}[_\-]'), '')
        .replaceFirst(RegExp(r'^\d+[_\-]'), '');

    // Second pass: after normalization
    for (final entry in known.entries) {
      if (cleaned.contains(entry.key)) {
        return (entry.key, entry.value);
      }
    }

    // Fallback: build a friendly label, but use cleaned as the key
    final displayLabel = cleaned
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return (cleaned, displayLabel.isEmpty ? 'Unknown Category' : displayLabel);
  }

  void _showFileDialog(FileObject file, String fileUrl, bool isImage, bool isPdf, bool isWord, String categoryKey) {
    showDialog(
      context: context,
      builder: (context) {
        // Local state for the date field within the dialog
        final dateKey = '${categoryKey}_date_issued';
        final validKey = '${categoryKey}_valid_until';
        String dateText = (complianceStatuses[dateKey] ?? '').toString();
        // infer from format
        bool monthYearOnly = RegExp(r'^\d{1,2}/\d{4}$').hasMatch(dateText);
        DateTime? selectedDate;
        bool savingDate = false;

        String fmt(DateTime d, bool monthOnly) {
          final mm = d.month.toString().padLeft(2, '0');
          final dd = d.day.toString().padLeft(2, '0');
          return monthOnly ? '$mm/${d.year}' : '$mm/$dd/${d.year}';
        }

        // Helpers to parse/compute validity
        DateTime? tryParseDate(String s) {
          final parts = s.split('/');
          if (parts.length == 3) {
            // MM/DD/YYYY
            final mm = int.tryParse(parts[0]);
            final dd = int.tryParse(parts[1]);
            final yy = int.tryParse(parts[2]);
            if (mm != null && dd != null && yy != null) {
              try {
                return DateTime(yy, mm, dd);
              } catch (_) {
                return null;
              }
            }
          } else if (parts.length == 2) {
            // MM/YYYY -> use day 1
            final mm = int.tryParse(parts[0]);
            final yy = int.tryParse(parts[1]);
            if (mm != null && yy != null) {
              try {
                return DateTime(yy, mm, 1);
              } catch (_) {
                return null;
              }
            }
          }
          return null;
        }

        DateTime addMonthsPreserveDay(DateTime dt, int months) {
          int y = dt.year;
          int m = dt.month + months;
          y += (m - 1) ~/ 12;
          m = ((m - 1) % 12) + 1;
          int d = dt.day;
          final lastDay = DateTime(y, m + 1, 0).day;
          if (d > lastDay) d = lastDay;
          return DateTime(y, m, d);
        }

        // Initialize selectedDate and validity text
        selectedDate = dateText.isNotEmpty ? tryParseDate(dateText) : null;
        String validUntilText = '';
        if (selectedDate != null) {
          validUntilText = _computeValidityUntil(categoryKey, selectedDate, monthYearOnly);
        } else {
          validUntilText = (complianceStatuses[validKey] ?? '').toString();
        }

        return StatefulBuilder(
          builder: (context, setStateSB) {
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
                                              final uri = Uri.parse(fileUrl);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
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

                    // Date Reported/Issued input
                    const Text(
                      'Date Reported/Issued',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        dateText.isEmpty ? 'Select date' : dateText,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime(now.year, now.month, now.day),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked != null) {
                          setStateSB(() {
                            selectedDate = picked;
                            dateText = fmt(picked, monthYearOnly);
                            validUntilText = _computeValidityUntil(categoryKey, picked, monthYearOnly);
                          });
                        }
                      },
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Month/Year only'),
                      value: monthYearOnly,
                      onChanged: (v) {
                        if (v == null) return;
                        setStateSB(() {
                          monthYearOnly = v;
                          final baseDate = selectedDate ?? (dateText.isNotEmpty ? tryParseDate(dateText) : null);
                          if (baseDate != null) {
                            dateText = fmt(baseDate, monthYearOnly);
                            validUntilText = _computeValidityUntil(categoryKey, baseDate, monthYearOnly);
                          }
                        });
                      },
                    ),

                    // New: Validity Until (derived)
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.event_available, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validUntilText.isEmpty ? 'Validity Until: —' : 'Validity Until: $validUntilText',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: savingDate
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(savingDate ? 'Saving...' : 'Save Date'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: savingDate
                            ? null
                            : () async {
                                // Ensure we have a valid selected date (parse if needed)
                                DateTime? baseDate = selectedDate ?? (dateText.isNotEmpty ? tryParseDate(dateText) : null);
                                if (baseDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select a valid date')),
                                  );
                                  return;
                                }
                                final validText = _computeValidityUntil(categoryKey, baseDate, monthYearOnly);

                                setStateSB(() => savingDate = true);
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('compliance_uploads')
                                      .doc(widget.stationOwnerDocId)
                                      .set({
                                        dateKey: fmt(baseDate, monthYearOnly),
                                        validKey: validText,
                                      }, SetOptions(merge: true));

                                  if (!mounted) return;
                                  setState(() {
                                    complianceStatuses[dateKey] = fmt(baseDate, monthYearOnly);
                                    complianceStatuses[validKey] = validText;
                                  });
                                  setStateSB(() {
                                    dateText = fmt(baseDate, monthYearOnly);
                                    validUntilText = validText;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Date and validity saved')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to save date')),
                                  );
                                } finally {
                                  setStateSB(() => savingDate = false);
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Download button (existing)
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
                        final uri = Uri.parse(fileUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not download file')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Add this helper function inside _ComplianceFilesViewerState
  String _computeValidityUntil(String categoryKey, DateTime issuedDate, bool monthYearOnly) {
    // All keys are lowercased
    switch (categoryKey) {
      case 'business_permit':
        // Always January 20 of next year
        final nextYear = issuedDate.year + 1;
        return monthYearOnly
            ? '01/$nextYear'
            : '01/20/$nextYear';
      case 'sanitary_permit':
      case 'certificate_of_association':
        // Always December 31 of the same year
        return monthYearOnly
            ? '12/${issuedDate.year}'
            : '12/31/${issuedDate.year}';
      case 'finished_bacteriological':
        // Valid for 1 month
        final valid = DateTime(issuedDate.year, issuedDate.month + 1, issuedDate.day);
        return monthYearOnly
            ? '${valid.month.toString().padLeft(2, '0')}/${valid.year}'
            : '${valid.month.toString().padLeft(2, '0')}/${valid.day.toString().padLeft(2, '0')}/${valid.year}';
      case 'source_bacteriological':
        // Valid for 6 months
        final valid = DateTime(issuedDate.year, issuedDate.month + 6, issuedDate.day);
        return monthYearOnly
            ? '${valid.month.toString().padLeft(2, '0')}/${valid.year}'
            : '${valid.month.toString().padLeft(2, '0')}/${valid.day.toString().padLeft(2, '0')}/${valid.year}';
      case 'source_physical_chemical':
      case 'finished_physical_chemical':
        // Valid for 1 year
        final valid = DateTime(issuedDate.year + 1, issuedDate.month, issuedDate.day);
        return monthYearOnly
            ? '${valid.month.toString().padLeft(2, '0')}/${valid.year}'
            : '${valid.month.toString().padLeft(2, '0')}/${valid.day.toString().padLeft(2, '0')}/${valid.year}';
      default:
        // Default: 1 month
        final valid = DateTime(issuedDate.year, issuedDate.month + 1, issuedDate.day);
        return monthYearOnly
            ? '${valid.month.toString().padLeft(2, '0')}/${valid.year}'
            : '${valid.month.toString().padLeft(2, '0')}/${valid.day.toString().padLeft(2, '0')}/${valid.year}';
    }
  }

  // Visual helpers (copied design)
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

  Widget _buildStatusChip(String? status, {bool compact = false}) {
    // If backend status is 'submitreq', display as 'Failed' in UI
    String displayStatus = status ?? 'Partially';
    if (displayStatus.toLowerCase() == 'submitreq') {
      displayStatus = 'Failed';
    }
    final color = _statusColor(displayStatus);
    final text = displayStatus;
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
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
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
                    if (_hasFailedFiles && !_emailSent)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 180,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: _isSendingEmail
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.email),
                            label: Text(_isSendingEmail ? 'Sending...' : 'Send Email'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSendingEmail ? null : () => sendFailedFilesEmail(complianceStatuses),
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
                              // ...existing code...
                              final file = uploadedFiles[index];
                              final fileUrl = Supabase.instance.client.storage
                                  .from('compliance_docs')
                                  .getPublicUrl('uploads/${widget.stationOwnerDocId}/${file.name}');
                              final extension = file.name.split('.').last.toLowerCase();
                              final isImage = ['png', 'jpg', 'jpeg'].contains(extension);
                              final isPdf = extension == 'pdf';
                              final isWord = extension == 'doc' || extension == 'docx';
                              final (categoryKey, categoryLabel) =
                                  _extractCategoryKeyAndLabel(file.name, widget.stationOwnerDocId);

                              final statusKey = '${categoryKey}_status';
                              final rawStatus = (statusEdits[statusKey] ?? complianceStatuses[statusKey] ?? 'Partially').toString();
                              final status = rawStatus.isNotEmpty
                                  ? '${rawStatus[0].toUpperCase()}${rawStatus.substring(1).toLowerCase()}'
                                  : null;

                              final accent = _statusColor(status);
                              final icon = _fileIcon(extension);
                              final iconColor = _fileIconColor(extension);

                              // --- Add these lines to get date issued and valid until ---
                              final dateIssued = (complianceStatuses['${categoryKey}_date_issued'] ?? '').toString();
                              final validUntil = (complianceStatuses['${categoryKey}_valid_until'] ?? '').toString();
                              // --------------------------------------------------------- 

                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Container(
                                  width: 240,
                                  height: 360,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Colors.white, Color(0xFFF7FAFF)],
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
                                          Expanded(
                                            child: Center(
                                              child: Icon(
                                                icon,
                                                color: iconColor.withOpacity(0.35),
                                                size: 64,
                                              ),
                                            ),
                                          ),
                                          // --- Add this block to display date issued and valid until ---
                                          if (dateIssued.isNotEmpty || validUntil.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    dateIssued.isNotEmpty
                                                        ? 'Date Issued: $dateIssued'
                                                        : 'Date Issued: —',
                                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(Icons.event_available, size: 16, color: Colors.green),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    validUntil.isNotEmpty
                                                        ? 'Valid Until: $validUntil'
                                                        : 'Valid Until: —',
                                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          // ------------------------------------------------------------
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                _showFileDialog(file, fileUrl, isImage, isPdf, isWord, categoryKey);
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
                                          const SizedBox(height: 10),
                                          DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            alignment: Alignment.centerLeft,
                                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                                            menuMaxHeight: 320,
                                            initialValue: const ['Pending', 'Partially', 'Failed'].contains(status) ? status : null,
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
                                              // Must match items length (header + divider + 3 options)
                                              final opts = ['__header', '__div', 'Pending', 'Partially', 'Failed'];
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
                                              DropdownMenuItem<String>(
                                                value: '__div',
                                                enabled: false,
                                                child: const Divider(height: 1, thickness: 1),
                                              ),
                                              // Options
                                              ...['Pending', 'Partially', 'Failed'].map((opt) {
                                                final color = _statusColor(opt);
                                                final subtitle = {
                                                  'Pending': 'Waiting for review',
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
                                            onChanged: (status?.toLowerCase() == 'passed')
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