import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplianceFilesViewer extends StatefulWidget {
  final String stationOwnerDocId;
  const ComplianceFilesViewer({super.key, required this.stationOwnerDocId});

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

      // After updating, check if all statuses are "partially"
      final doc = await FirebaseFirestore.instance
          .collection('compliance_uploads')
          .doc(widget.stationOwnerDocId)
          .get();
      final data = doc.data() ?? {};
      // Get all status fields (ending with _status)
      final statusValues = data.entries
          .where((e) => e.key.endsWith('_status'))
          .map((e) => (e.value ?? '').toString().toLowerCase())
          .toList();
      if (statusValues.isNotEmpty &&
          statusValues.every((s) => s == 'passed')) {
        // Update station_owners status to "district_approved"
        await FirebaseFirestore.instance
            .collection('station_owners')
            .doc(widget.stationOwnerDocId)
            .update({'status': 'approved'});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All statuses are "partially". Station marked as approved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  /// Returns a tuple: (categoryKey, displayLabel)
  (String, String) _extractCategoryKeyAndLabel(String fileName, String docId) {
    final prefix = '${docId}_';
    if (fileName.startsWith(prefix)) {
      final rest = fileName.substring(prefix.length);
      final categoryKey = rest.split('.').first.toLowerCase();
      final displayLabel = categoryKey
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
          .join(' ');
      return (categoryKey, displayLabel);
    }
    return ('unknown', 'Unknown Category');
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

                              return Container(
                                width: 220,
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        categoryLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        file.name,
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: () {
                                          _showFileDialog(file, fileUrl, isImage, isPdf, isWord);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE3F2FD),
                                          foregroundColor: Colors.blue,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text('View File', style: TextStyle(color: Colors.blue)),
                                      ),
                                      const SizedBox(height: 8),
                                      const SizedBox(height: 18),
                                      DropdownButtonFormField<String>(
                                        value: status == 'Unknown' ? null : status,
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        items: [
                                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                          DropdownMenuItem(value: 'Passed', child: Text('Passed')),
                                          DropdownMenuItem(value: 'Partially', child: Text('Partially')),
                                          DropdownMenuItem(value: 'Failed', child: Text('Failed')),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            if (value != null) {
                                              statusEdits[statusKey] = value;
                                            }
                                          });
                                        },
                                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                                        dropdownColor: Colors.white,
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: statusEdits.containsKey(statusKey)
                                              ? () {
                                                  final newStatus = statusEdits[statusKey]!;
                                                  updateStatus(statusKey, newStatus);
                                                }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Save', style: TextStyle(fontSize: 14)),
                                        ),
                                      ),
                                    ],
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