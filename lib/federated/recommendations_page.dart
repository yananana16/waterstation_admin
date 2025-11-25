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
  final String districtSentiment;
  final double districtSentimentScore;
  final Map<String, dynamic> districtSentimentCount;

  Recommendation({
    required this.district,
    required this.lat,
    required this.lng,
    required this.rangeRadius,
    required this.priority,
    required this.insight,
    required this.districtSentiment,
    required this.districtSentimentScore,
    required this.districtSentimentCount,
  });

  /// Transform raw backend data into federated-safe insights
  factory Recommendation.fromRaw(Map<String, dynamic> data) {
    String priority = "";
    String safeInsight =
        "Recommended new station Location identified in ${data['district']} district";

    // Extract sentiment fields from backend
    String sentiment = data['district_sentiment'] ?? 'neutral';
    double sentimentScore = 0.0;
    if (data['district_sentiment_score'] != null) {
      try {
        sentimentScore = (data['district_sentiment_score'] as num).toDouble();
      } catch (_) {
        sentimentScore = 0.0;
      }
    }
    Map<String, dynamic> sentimentCount = {};
    if (data['district_sentiment_count'] != null && data['district_sentiment_count'] is Map) {
      sentimentCount = Map<String, dynamic>.from(data['district_sentiment_count']);
    }

    return Recommendation(
      district: data['district'] ?? "Unknown",
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      rangeRadius: data['range_radius'] ?? 50,
      priority: priority,
      insight: safeInsight,
      districtSentiment: sentiment,
      districtSentimentScore: sentimentScore,
      districtSentimentCount: sentimentCount,
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
  bool _showAbout = true;

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
                      colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Analysis and Recommendations",
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
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
          body: Column(
            children: [
              // Toggleable Explanation Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1976D2).withOpacity(0.1),
                      const Color(0xFF42A5F5).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          setState(() {
                                            _showAbout = !_showAbout;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1976D2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'About These Recommendations',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2D3748),
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(_showAbout ? Icons.expand_less : Icons.expand_more, color: Color(0xFF1976D2)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      AnimatedCrossFade(
                                        firstChild: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'These locations are generated by using multiple factors, including customer density, sales trends, and geographic distribution. Each recommendation is tailored to maximize business potential and coverage.',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF4A5568),
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              _buildBulletPoint('Customer density analysis – areas with high demand but limited supply'),
                                              _buildBulletPoint('Sales pattern trends – identifying underserved profitable zones'),
                                              _buildBulletPoint('Geographic distribution – optimal spacing to maximize coverage'),
                                              _buildBulletPoint('District-level insights – strategic expansion opportunities'),
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.tips_and_updates, size: 18, color: Colors.amber[700]),
                                                        const SizedBox(width: 10),
                                                        const Expanded(
                                                          child: Text(
                                                            'Use these recommendations to guide business expansion decisions and identify high-potential locations for new water station investments.',
                                                            style: TextStyle(
                                                              /* Lines 341-344 omitted */
                                                              height: 1.4,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(Icons.emoji_objects, color: Color(0xFF1976D2), size: 18),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: RichText(
                                                            text: TextSpan(
                                                              text: '• Positive',
                                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                                                              children: [
                                                                TextSpan(
                                                                  text: ' – Customers are happy with service/location.',
                                                                  style: TextStyle(fontWeight: FontWeight.normal, color: Color(0xFF4A5568)),
                                                                ),
                                                                TextSpan(
                                                                  text: '\n• Neutral',
                                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]),
                                                                ),
                                                                TextSpan(
                                                                  text: ' – Customers are neither satisfied nor dissatisfied.',
                                                                  style: TextStyle(fontWeight: FontWeight.normal, color: Color(0xFF4A5568)),
                                                                ),
                                                                TextSpan(
                                                                  text: '\n• Negative',
                                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
                                                                ),
                                                                TextSpan(
                                                                  text: ' – Customers express dissatisfaction or concerns about service or location.',
                                                                  style: TextStyle(fontWeight: FontWeight.normal, color: Color(0xFF4A5568)),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        secondChild: const SizedBox.shrink(),
                                        crossFadeState: _showAbout ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                        duration: const Duration(milliseconds: 250),
                                      ),
                                    ],
                                  ),
                                ),
              // Recommendations Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
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



                // Build a map of district -> sentiment info for the table (from recommendations)
                final Map<String, Map<String, dynamic>> districtSentiments = {};
                for (var r in recommendations) {
                  districtSentiments[r.district] = {
                    'sentiment': r.districtSentiment,
                    'score': r.districtSentimentScore,
                    'counts': r.districtSentimentCount,
                  };
                }

                // Small card with a horizontally-scrollable DataTable summarizing sentiments.
                // This also fetches `station_owners` to show per-station `average_sentiment`, grouped by district.
                Widget sentimentTable = Card(
                  color: Colors.grey[100],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('station_owners').get(),
                      builder: (context, ownersSnap) {
                        if (ownersSnap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                          );
                        }

                        // countsPerDistrict: { district: { 'positive': n, 'neutral': n, 'negative': n } }
                        final Map<String, Map<String, int>> countsPerDistrict = {};
                        // stationsPerDistrict: { district: [ 'Name (sentiment)', ... ] }
                        final Map<String, List<String>> stationsPerDistrict = {};

                        if (ownersSnap.hasData) {
                          for (var doc in ownersSnap.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final avg = (data['average_sentiment'] as String?)?.toLowerCase();
                            if (avg == null || avg.trim().isEmpty) continue; // skip nulls

                            final district = (data['districtName'] ?? data['district'] ?? data['districtName'] ?? 'Unknown') as String;

                            countsPerDistrict.putIfAbsent(district, () => {'positive': 0, 'neutral': 0, 'negative': 0});
                            if (avg == 'positive') {
                              countsPerDistrict[district]!['positive'] = countsPerDistrict[district]!['positive']! + 1;
                            } else if (avg == 'neutral') {
                              countsPerDistrict[district]!['neutral'] = countsPerDistrict[district]!['neutral']! + 1;
                            } else if (avg == 'negative') {
                              countsPerDistrict[district]!['negative'] = countsPerDistrict[district]!['negative']! + 1;
                            }

                            stationsPerDistrict.putIfAbsent(district, () => []);
                            final stationName = (data['stationName'] as String?)?.trim();
                            final first = (data['firstName'] as String?) ?? '';
                            final last = (data['lastName'] as String?) ?? '';
                            final name = (first + ' ' + last).trim();
                            final displayName = stationName != null && stationName.isNotEmpty ? stationName : (name.isNotEmpty ? name : (data['email'] as String?) ?? doc.id);
                            stationsPerDistrict[district]!.add('$displayName (${avg})');
                          }
                        }

                        // Combine district keys from recommendations and station owners
                        final districts = <String>{...districtSentiments.keys, ...countsPerDistrict.keys}.toList();
                        districts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                        // Improved, responsive card-based table with chips
                        final width = MediaQuery.of(context).size.width;
                        final tableWidth = width > 1000 ? 760.0 : (width * 0.85);

                        // Split the view: left card for District + Counts, right card for Stations (separate column)
                        return Center(
                          child: Container(
                            width: tableWidth,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            child: LayoutBuilder(builder: (ctx, box) {
                              final isWide = box.maxWidth > 700;

                              Widget leftCard = Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 2,
                                color: Colors.white, // Set white background
                                child: SizedBox(
                                  height: 220,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Districts', style: TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Scrollbar(
                                            thumbVisibility: true,
                                            child: ListView.separated(
                                              itemCount: districts.length,
                                              separatorBuilder: (_, __) => const Divider(height: 1),
                                              itemBuilder: (context, idx) {
                                                final d = districts[idx];
                                                final c = countsPerDistrict[d];
                                                final pos = c == null ? 0 : (c['positive'] ?? 0);
                                                final neu = c == null ? 0 : (c['neutral'] ?? 0);
                                                final neg = c == null ? 0 : (c['negative'] ?? 0);

                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  child: Row(
                                                    children: [
                                                      Expanded(flex: 3, child: Text(d, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Row(
                                                          children: [
                                                            if (pos > 0) Padding(
                                                              padding: const EdgeInsets.only(right: 6.0),
                                                              child: Chip(
                                                                backgroundColor: Colors.green.shade50,
                                                                label: Text('P $pos', style: TextStyle(color: Colors.green.shade800)),
                                                                visualDensity: VisualDensity.compact,
                                                              ),
                                                            ),
                                                            if (neu > 0) Padding(
                                                              padding: const EdgeInsets.only(right: 6.0),
                                                              child: Chip(
                                                                backgroundColor: Colors.orange.shade50,
                                                                label: Text('N $neu', style: TextStyle(color: Colors.orange.shade800)),
                                                                visualDensity: VisualDensity.compact,
                                                              ),
                                                            ),
                                                            if (neg > 0) Padding(
                                                              padding: const EdgeInsets.only(right: 6.0),
                                                              child: Chip(
                                                                backgroundColor: Colors.red.shade50,
                                                                label: Text('Neg $neg', style: TextStyle(color: Colors.red.shade800)),
                                                                visualDensity: VisualDensity.compact,
                                                              ),
                                                            ),
                                                            if (pos + neu + neg == 0) const Text('-', style: TextStyle(color: Colors.grey)),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              Widget rightCard = Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 2,
                                color: Colors.white, // Set white background
                                child: SizedBox(
                                  height: 220,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Stations', style: TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Scrollbar(
                                            thumbVisibility: true,
                                            child: ListView.builder(
                                              itemCount: districts.length,
                                              itemBuilder: (context, idx) {
                                                final d = districts[idx];
                                                final stations = stationsPerDistrict[d] ?? [];
                                                return ExpansionTile(
                                                  title: Text(d, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  children: stations.map((s) {
                                                    final lower = s.toLowerCase();
                                                    Color fg = Colors.grey.shade700;
                                                    if (lower.contains('(positive)')) fg = Colors.green.shade700;
                                                    if (lower.contains('(neutral)')) fg = Colors.orange.shade700;
                                                    if (lower.contains('(negative)')) fg = Colors.red.shade700;
                                                    return ListTile(
                                                      title: Text(s.replaceAll(RegExp(r"\s*\(positive\)|\s*\(neutral\)|\s*\(negative\)", caseSensitive: false), ''), overflow: TextOverflow.ellipsis),
                                                      trailing: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: fg.withOpacity(0.12),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(s.split('(').last.replaceAll(')', '').toUpperCase(), style: TextStyle(color: fg)),
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              if (isWide) {
                                return Container(
                                  color: const Color(0xFFF5F7FA), // Match Scaffold background
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 2, child: leftCard),
                                      const SizedBox(width: 12),
                                      Expanded(flex: 3, child: rightCard),
                                    ],
                                  ),
                                );
                              }

                              // stacked for narrow screens
                              return Container(
                                color: const Color(0xFFF5F7FA), // Match Scaffold background
                                child: Column(
                                  children: [
                                    leftCard,
                                    const SizedBox(height: 12),
                                    rightCard,
                                  ],
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                );

              return Column(
                children: [
                  sentimentTable,
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
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
                    ),
                  ),
                ],
              );
            },
          ),
        ),
            ],
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
                          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4A5568),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _sentimentColor(String sentiment) {
    final s = sentiment.toLowerCase();
    if (s.contains('positive')) return Colors.green.shade100;
    if (s.contains('neutral')) return Colors.orange.shade100;
    if (s.contains('negative')) return Colors.red.shade100;
    return Colors.grey.shade200;
  }

  

  /// Build each recommendation card
  Widget _buildRecommendationCard(BuildContext context, Recommendation rec) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showMapSheet(context, rec.lat, rec.lng, rec.district),
          child: Card(
            elevation: 6,
            shadowColor: Colors.blue.withOpacity(0.12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.blue.shade50.withOpacity(0.18)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rec.district,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3748)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            rec.districtSentiment,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          backgroundColor: _sentimentColor(rec.districtSentiment),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rec.insight,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'District Sentiment is ${rec.districtSentiment} for the whole district.',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.map_outlined, size: 20),
                          label: const Text('View Map', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () {
                            _showMapSheet(context, rec.lat, rec.lng, rec.district);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          district,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    height: 400,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.blue.shade100, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.08),
                          blurRadius: 14,
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
                              borderStrokeWidth: 2.5,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 44,
                              height: 44,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade50),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.my_location, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Text(
                              'Latitude: ${lat.toStringAsFixed(6)}',
                              style: TextStyle(fontSize: 15, color: Colors.grey[800], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.my_location, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Text(
                              'Longitude: ${lng.toStringAsFixed(6)}',
                              style: TextStyle(fontSize: 15, color: Colors.grey[800], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final url = 'https://www.google.com/maps/search/?api=1&query=$coords';
                                if (await canLaunch(url)) {
                                  await launch(url);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.share_location, color: Colors.white, size: 22),
                                    SizedBox(width: 10),
                                    Text('Share Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: coords));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Coordinates copied!'),
                                    backgroundColor: Colors.blueAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Icon(Icons.copy, color: Colors.grey[700], size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}
