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
  final String explanation;

  Recommendation({
    required this.district,
    required this.lat,
    required this.lng,
    required this.rangeRadius,
    required this.priority,
    required this.insight,
    required this.explanation,
  });

  /// Transform raw backend data into federated-safe insights
  factory Recommendation.fromRaw(Map<String, dynamic> data) {
    String explanation = data['explanation'] ?? "";
    String priority = "Medium";

    if (explanation.contains("highest sales")) {
      priority = "High";
    } else if (explanation.contains("low")) {
      priority = "Low";
    }

    String safeInsight =
        "High demand cluster identified in ${data['district']} district";

    return Recommendation(
      district: data['district'] ?? "Unknown",
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      rangeRadius: data['range_radius'] ?? 50,
      priority: priority,
      insight: safeInsight,
      explanation: explanation,
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

  /// Trigger FastAPI backend to regenerate recommendations
  Future<void> _triggerServicePy() async {
    setState(() => _isRunning = true);

    try {
      final url = Uri.parse(
        "https://ai-recommendation-model.onrender.com/generate_recommendations",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"mode": "firestore"}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Response: ${response.body}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode} ${response.body}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error triggering service.py: $e")),
        );
      }
    }

    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("AI-Powered Recommendations"),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
            color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _isRunning
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black87,
                        strokeWidth: 2.2,
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: _triggerServicePy,
                    icon: const Icon(Icons.refresh, color: Colors.black87),
                    tooltip: "Generate Recommendations",
                  ),
          )
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
            return const Center(
              child: Text(
                "No recommendations available",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
                child: Container(
                  color: Colors.white,
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
                          return Align(
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
                          );
                        },
                      )
                    : ListView.builder(
                        itemCount: recommendations.length,
                        itemBuilder: (context, index) {
                          return Padding(
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
                          );
                        },
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Build each recommendation card
  Widget _buildRecommendationCard(
      BuildContext context, Recommendation rec) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.location_on, color: Colors.blue, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec.district,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Do not display the priority chip when priority is "High"
                if (rec.priority != "High")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _priorityColor(rec.priority),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rec.priority,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rec.insight,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Text(
              rec.explanation,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text("View on Map"),
                  onPressed: () {
                    _showMapSheet(context, rec.lat, rec.lng, rec.district);
                  },
                )
              ],
            )
          ],
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
  // center coordinate available as lat/lng variables
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.48,
          minChildSize: 0.28,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) {
            return Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    district,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    width: double.infinity,
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
                              borderStrokeWidth: 1,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Lat: ${lat.toStringAsFixed(6)}'),
                  Text('Lng: ${lng.toStringAsFixed(6)}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Open in Google Maps'),
                          onPressed: () async {
                            final googleUrl = Uri.parse('geo:$coords?q=$coords(${Uri.encodeComponent(district)})');
                            final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$coords');
                            try {
                              if (await canLaunchUrl(googleUrl)) {
                                await launchUrl(googleUrl);
                              } else if (await canLaunchUrl(webUrl)) {
                                await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
                                }
                              }
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: coords));
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordinates copied')));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
