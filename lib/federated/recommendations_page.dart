import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Model for a federated-safe recommendation
class Recommendation {
  final String district;
  final double lat;
  final double lng;
  final int rangeRadius;
  final String priority;
  final String insight;

  Recommendation({
    required this.district,
    required this.lat,
    required this.lng,
    required this.rangeRadius,
    required this.priority,
    required this.insight,
  });

  /// Transform raw backend data into federated-safe insights
  factory Recommendation.fromRaw(Map<String, dynamic> data) {
    String priority = "";

    String safeInsight =
        "Recommended Location identified in ${data['district']} district";

    return Recommendation(
      district: data['district'] ?? "Unknown",
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      rangeRadius: data['range_radius'] ?? 50,
      priority: priority,
      insight: safeInsight,
    );
  }
}

/// Recommendations Page
class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  bool _isRunning = false;
  http.Client? _httpClient;

  /// Trigger FastAPI backend to regenerate recommendations
  Future<void> _triggerServicePy() async {
    setState(() {
      _isRunning = true;
    });

    // Create a new HTTP client for this request
    _httpClient = http.Client();

    try {
      final url = Uri.parse(
        "https://ai-recommendation-model.onrender.com/generate_recommendations",
      );

      final response = await _httpClient!.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"mode": "firestore"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text("Recommendations generated successfully!")),
              ],
            ),
            backgroundColor: const Color(0xFF48BB78),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${response.statusCode} ${response.body}"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if this is a cancellation
        if (e.toString().contains('Connection closed') || 
            e.toString().contains('ClientException')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Generation cancelled by user'),
                ],
              ),
              backgroundColor: Color(0xFFED8936),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error triggering service: $e"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      _httpClient?.close();
      _httpClient = null;
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  void _cancelGeneration() {
    // Close the HTTP client to cancel the ongoing request
    _httpClient?.close();
    _httpClient = null;
    
    setState(() {
      _isRunning = false;
    });
  }

  @override
  void dispose() {
    // Clean up HTTP client if widget is disposed
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text("AI-Powered Recommendations"),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.black.withOpacity(0.1),
            iconTheme: const IconThemeData(color: Colors.black87),
            titleTextStyle: const TextStyle(
                color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _isRunning
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _triggerServicePy,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.refresh, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    "Regenerate",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("station_recommendations")
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.radar,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "No recommendations available",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Click regenerate to create new recommendations",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final recommendations = snapshot.data!.docs.map((doc) {
                return Recommendation.fromRaw(
                    doc.data() as Map<String, dynamic>);
              }).toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 600;

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isWide
                        ? GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              childAspectRatio: 2.6,
                            ),
                            itemCount: recommendations.length,
                            itemBuilder: (context, index) {
                              return AnimatedScale(
                                scale: 1.0,
                                duration: Duration(milliseconds: 300 + (index * 50)),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 520,
                                      minWidth: 300,
                                      maxHeight: 250,
                                    ),
                                    child: _buildRecommendationCard(
                                        context, recommendations[index]),
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            itemCount: recommendations.length,
                            itemBuilder: (context, index) {
                              return AnimatedOpacity(
                                opacity: 1.0,
                                duration: Duration(milliseconds: 300 + (index * 50)),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 700,
                                        minWidth: 280,
                                        maxHeight: 220,
                                      ),
                                      child: _buildRecommendationCard(
                                          context, recommendations[index]),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
              );
            },
          ),
        ),
        // Loading overlay
        if (_isRunning)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Generating Recommendations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3748),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Please don\'t cancel',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4A5568),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This may take a few moments...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelGeneration,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel Anyway'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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

  /// Build each recommendation card
  Widget _buildRecommendationCard(
      BuildContext context, Recommendation rec) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rec.district,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF2D3748)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Do not display the priority chip when priority is "High"
                  if (rec.priority != "High")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _priorityColor(rec.priority),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _priorityColor(rec.priority).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        rec.priority,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rec.insight,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'AI-powered analysis based on customer density, sales patterns, and geographic distribution',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _showMapSheet(context, rec.lat, rec.lng, rec.district);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.map, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "View on Map",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Helper for chip colors
  Color _priorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.redAccent;
      case "Medium":
        return Colors.orange;
      case "Low":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showMapSheet(BuildContext context, double lat, double lng, String district) async {
    final coords = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 600,
              maxHeight: 700,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          district,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                
                // Map
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 400,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 17.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(lat, lng),
                              useRadiusInMeter: true,
                              radius: 50,
                              color: Colors.blue.withAlpha((0.18 * 255).round()),
                              borderColor: Colors.blueAccent.withAlpha((0.6 * 255).round()),
                              borderStrokeWidth: 1.5,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Coordinates info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.my_location, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 10),
                            Text(
                              'Latitude: ${lat.toStringAsFixed(6)}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.my_location, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 10),
                            Text(
                              'Longitude: ${lng.toStringAsFixed(6)}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final googleUrl = Uri.parse('geo:$coords?q=$coords(${Uri.encodeComponent(district)})');
                                final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$coords');
                                try {
                                  if (await canLaunchUrl(googleUrl)) {
                                    await launchUrl(googleUrl);
                                  } else if (await canLaunchUrl(webUrl)) {
                                    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not open maps')),
                                      );
                                    }
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open maps')),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.map_outlined, color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'Open in Google Maps',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: coords));
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text('Coordinates copied'),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF48BB78),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Icon(Icons.copy, color: Colors.grey[700], size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
