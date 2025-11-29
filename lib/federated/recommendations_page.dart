import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
// 'dart:ui' removed (not used after sparkline removal)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Shared color palette and UI constants to keep visuals consistent
const Color kPrimaryColor = Color(0xFF1976D2);
const Color kSecondaryColor = Color(0xFF42A5F5);
// Lighter neutral background used for subtle panels (replaces pinkish tint)
const Color kScaffoldBg = Color(0xFFF3F4F6);
const Color kSuccessColor = Color(0xFF48BB78);
const Color kWarningColor = Color(0xFFED8936);

/// Model for a federated-safe recommendation
class Recommendation {
  final String district;
  final double lat;
  final double lng;
  final int rangeRadius;
  final int highestDemandCluster;
  final double districtTotalM3;
  final double districtForecastNextMonthM3;
  final double districtForecast12mM3;
  final String districtTrend;
  final String explanation;
  final List<double>? historySeries;
  final int? districtRankByNextMonthDemand;

  Recommendation({
    required this.district,
    required this.lat,
    required this.lng,
    required this.rangeRadius,
    required this.highestDemandCluster,
    required this.districtTotalM3,
    required this.districtForecastNextMonthM3,
    required this.districtForecast12mM3,
    required this.districtTrend,
    required this.explanation,
    this.districtRankByNextMonthDemand,
    this.historySeries,
  });

  factory Recommendation.fromRaw(Map<String, dynamic> data) {
    // Helper to safely parse int
    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }
    // Helper to safely parse double
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    // Helper to parse monthly_trend_current_year map into List<double>
    List<double>? parseMonthlyTrendMap(dynamic monthlyTrend) {
      if (monthlyTrend is Map) {
        final keys = monthlyTrend.keys.map((k) => k.toString()).toList()..sort();
        final out = <double>[];
        for (final k in keys) {
          final entry = monthlyTrend[k];
          double v = 0.0;
          if (entry is Map) {
            final actual = entry['actual_m3'];
            final forecast = entry['forecast_m3'];
            final hasActual = actual != null;
            final hasForecast = forecast != null;
            if (hasActual && hasForecast) {
              // If both actual and forecast are present, sum them as requested.
              v = parseDouble(actual) + parseDouble(forecast);
            } else if (hasActual) {
              v = parseDouble(actual);
            } else if (hasForecast) {
              v = parseDouble(forecast);
            }
          }
          out.add(v);
        }
        return out;
      }
      return null;
    }

    return Recommendation(
      district: data['district']?.toString() ?? "Unknown",
      lat: parseDouble(data['lat']),
      lng: parseDouble(data['lng']),
      rangeRadius: parseInt(data['range_radius'], 50),
      highestDemandCluster: parseInt(data['highest_demand_cluster'], 0),
      districtTotalM3: parseDouble(data['district_total_m3']),
      districtForecastNextMonthM3: parseDouble(data['district_forecast_next_month_m3']),
      districtForecast12mM3: parseDouble(data['district_forecast_12m_m3']),
      districtTrend: data['district_trend']?.toString() ?? "Unknown",
      explanation: data['explanation']?.toString() ?? "",
      districtRankByNextMonthDemand: data['district_rank_by_next_month_demand'] != null
          ? parseInt(data['district_rank_by_next_month_demand'])
          : null,
      historySeries: (() {
        // Prefer monthly_trend_current_year map (YYYY-MM -> {actual_m3, forecast_m3})
        final fromMap = parseMonthlyTrendMap(data['monthly_trend_current_year'] ?? data['monthly_trend_current_year_map'] ?? data['monthly_trend']);
        if (fromMap != null) return fromMap;

        // fallback: explicit history_series list
        if (data['history_series'] is List) {
          return (data['history_series'] as List).map((e) => parseDouble(e)).toList();
        }
        if (data['monthly_series'] is List) {
          return (data['monthly_series'] as List).map((e) => parseDouble(e)).toList();
        }
        // legacy keys
        if (data['monthly_series_m3'] is List) {
          return (data['monthly_series_m3'] as List).map((e) => parseDouble(e)).toList();
        }
        return null;
      })(),
    );
  }
}

  /// Small district overview card that shows the selected district's mini-chart and stats.
  Widget _buildDistrictOverviewCard(BuildContext context, Recommendation rec) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF42A5F5)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.district, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (rec.historySeries != null && rec.historySeries!.isNotEmpty)
                    SizedBox(height: 140, child: _OverviewLineChart(points: rec.historySeries!))
                  else
                    SizedBox(height: 140, child: Center(child: Text('No series data for ${rec.district}'))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('History: ${rec.districtTotalM3.toStringAsFixed(2)} m³', style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 12),
                      Chip(label: Text('Trend: ${rec.districtTrend}'), backgroundColor: Colors.blue.shade50),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
              child: const Text('Details'),
            ),
          ],
        ),
      ),
    );
  }

/// Lightweight OverallSummary model for the top card
class OverallSummary {
  final double total;
  final double nextMonth;
  final double next12;
  final String top;
  final String low;
  final List<double>? series;

  OverallSummary({required this.total, required this.nextMonth, required this.next12, required this.top, required this.low, this.series});

  factory OverallSummary.fromRaw(Map<String, dynamic> data) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    List<double>? parseMonthlyTrendMap(dynamic monthlyTrend) {
      if (monthlyTrend is Map) {
        final keys = monthlyTrend.keys.map((k) => k.toString()).toList()..sort();
        final out = <double>[];
        for (final k in keys) {
          final entry = monthlyTrend[k];
          double v = 0.0;
          if (entry is Map) {
            final actual = entry['actual_m3'];
            final forecast = entry['forecast_m3'];
            final hasActual = actual != null;
            final hasForecast = forecast != null;
            if (hasActual && hasForecast) {
              v = parseDouble(actual) + parseDouble(forecast);
            } else if (hasActual) {
              v = parseDouble(actual);
            } else if (hasForecast) {
              v = parseDouble(forecast);
            }
          }
          out.add(v);
        }
        return out;
      }
      return null;
    }

    final total = parseDouble(data['overall_total_m3'] ?? data['overall_total'] ?? data['total_m3']);
    final nextMonth = parseDouble(data['overall_forecast_next_month_m3'] ?? data['overall_forecast_next_month']);
    final next12 = parseDouble(data['overall_forecast_12m_m3'] ?? data['overall_forecast_12m']);
    final top = data['highest_next_month_district']?.toString() ?? '';
    final low = data['lowest_next_month_district']?.toString() ?? '';

    List<double>? series;
    // prefer monthly_trend_current_year map
    series = parseMonthlyTrendMap(data['monthly_trend_current_year'] ?? data['monthly_trend']);

    // fallback to list-like keys
    if (series == null) {
      final possibleSeriesKeys = [
        'monthly_series',
        'monthly_trend_current_year',
        'overall_monthly_series',
        'monthly_series_m3',
        'monthly_trend',
      ];
      for (final key in possibleSeriesKeys) {
        if (data[key] is List) {
          series = (data[key] as List).map((e) => parseDouble(e)).toList();
          break;
        }
      }
    }

    // convert liters->m3 if obviously in liters
    if (series != null && series.isNotEmpty) {
      final maxV = series.reduce((a, b) => a > b ? a : b);
      if (maxV > 1000) series = series.map((v) => v / 1000.0).toList();
    }

    return OverallSummary(total: total, nextMonth: nextMonth, next12: next12, top: top, low: low, series: series);
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
  // Toggle whether to show the PNG image for the overall chart (if available).
  bool _overviewShowImage = false;
  // Track which recommendation cards have their explanation expanded
  final Set<String> _expandedCards = {};
  // Selected district filter for charts/listing. 'All' shows everything.
  String _selectedDistrictFilter = 'All';

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
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryColor, kSecondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Analysis and Recommendations",
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kPrimaryColor, kSecondaryColor],
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
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Toggleable Explanation Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(0),
                    decoration: BoxDecoration(
                      // use a neutral light-gray panel instead of a faint colored gradient
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kScaffoldBg,
                          Colors.white,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: kPrimaryColor.withOpacity(0.3),
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
                                    color: kPrimaryColor,
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
                                Icon(_showAbout ? Icons.expand_less : Icons.expand_more, color: kPrimaryColor),
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
                                                height: 1.4,
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
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("station_recommendations").snapshots(),
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

                      // Prepare an overall summary card (if present) and the top 7 districts
                      Map<String, dynamic>? overallData;
                      final districtRecs = <Recommendation>[];
                      for (var i = 0; i < snapshot.data!.docs.length; i++) {
                        final doc = snapshot.data!.docs[i];
                        final id = doc.id;
                        if (id.toString().toLowerCase() == 'overall') {
                          overallData = doc.data() as Map<String, dynamic>?;
                        } else {
                          districtRecs.add(Recommendation.fromRaw(doc.data() as Map<String, dynamic>));
                        }
                      }

                      districtRecs.sort((a, b) {
                        final aKey = a.districtForecastNextMonthM3 > 0 ? a.districtForecastNextMonthM3 : a.districtTotalM3;
                        final bKey = b.districtForecastNextMonthM3 > 0 ? b.districtForecastNextMonthM3 : b.districtTotalM3;
                        return bKey.compareTo(aKey);
                      });

                      // Apply selected district filter if any
                      List<Recommendation> displayList;
                      if (_selectedDistrictFilter != 'All') {
                        displayList = districtRecs.where((r) => r.district == _selectedDistrictFilter).take(7).toList();
                      } else {
                        displayList = districtRecs.take(7).toList();
                      }

                      return Column(
                        children: [
                          const SizedBox(height: 12),
                          // District filter control
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                            child: Row(
                              children: [
                                const Text('Filter:'),
                                const SizedBox(width: 12),
                                DropdownButton<String>(
                                  value: _selectedDistrictFilter,
                                  items: [
                                    const DropdownMenuItem(value: 'All', child: Text('All districts')),
                                    ...districtRecs.map((r) => DropdownMenuItem(value: r.district, child: Text(r.district))).toList(),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _selectedDistrictFilter = v;
                                    });
                                  },
                                ),
                                const Spacer(),
                                // If a specific district is selected and exists, show a small hint
                                if (_selectedDistrictFilter != 'All')
                                  Text('Showing: $_selectedDistrictFilter', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          // Show overall summary or a district-specific overview when filtered
                          if (_selectedDistrictFilter == 'All' && overallData != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                              child: _buildOverviewCardFromData(context, overallData),
                            )
                          else if (_selectedDistrictFilter != 'All')
                            // find the selected district recommendation to render its chart
                            (() {
                              final rec = districtRecs.firstWhere((r) => r.district == _selectedDistrictFilter, orElse: () => Recommendation(
                                district: _selectedDistrictFilter,
                                lat: 0.0,
                                lng: 0.0,
                                rangeRadius: 0,
                                highestDemandCluster: 0,
                                districtTotalM3: 0.0,
                                districtForecastNextMonthM3: 0.0,
                                districtForecast12mM3: 0.0,
                                districtTrend: '',
                                explanation: '',
                              ));

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                                child: _buildDistrictOverviewCard(context, rec),
                              );
                            })(),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // using Wrap-based layout below (constraints used in inner LayoutBuilder)

                              return Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: LayoutBuilder(builder: (ctx, childConstraints) {
                                  final double totalW = childConstraints.maxWidth;
                                  final double paddingAll = 12.0;
                                  final double spacing = 16.0;
                                  final int columns = totalW > 600 ? 2 : 1;
                                  final double rawItemWidth = (totalW - paddingAll * 2 - spacing * (columns - 1)) / columns;
                                  final double itemWidth = math.max(280.0, math.min(rawItemWidth, 720.0));

                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children: List.generate(displayList.length, (index) {
                                      final rec = displayList[index];
                                      return SizedBox(
                                        width: itemWidth,
                                        child: AnimatedScale(
                                          scale: 1.0,
                                          duration: Duration(milliseconds: 250 + (index * 40)),
                                          child: _buildRecommendationCard(context, rec),
                                        ),
                                      );
                                    }),
                                  );
                                }),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
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
                          colors: [kPrimaryColor, kSecondaryColor],
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

  // ...existing code...

  

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
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        if (rec.districtRankByNextMonthDemand != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Chip(
                              label: Text('Rank ${rec.districtRankByNextMonthDemand}'),
                              backgroundColor: Colors.blue.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(minHeight: 0, maxHeight: 180),
                      decoration: BoxDecoration(
                        color: kScaffoldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200, width: 0.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics, size: 18, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              // Trend chip with color-coded background and icon
                              Chip(
                                backgroundColor: rec.districtTrend.toLowerCase() == 'increasing'
                                    ? Colors.green.shade50
                                    : rec.districtTrend.toLowerCase() == 'decreasing'
                                        ? Colors.red.shade50
                                        : Colors.orange.shade50,
                                avatar: Icon(
                                  rec.districtTrend.toLowerCase() == 'increasing'
                                      ? Icons.trending_up
                                      : rec.districtTrend.toLowerCase() == 'decreasing'
                                          ? Icons.trending_down
                                          : Icons.trending_flat,
                                  size: 16,
                                  color: rec.districtTrend.toLowerCase() == 'increasing'
                                      ? Colors.green.shade700
                                      : rec.districtTrend.toLowerCase() == 'decreasing'
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700,
                                ),
                                label: Text(
                                  rec.districtTrend,
                                  style: TextStyle(
                                    color: rec.districtTrend.toLowerCase() == 'increasing'
                                        ? Colors.green.shade800
                                        : rec.districtTrend.toLowerCase() == 'decreasing'
                                            ? Colors.red.shade800
                                            : Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              const SizedBox(width: 8),
                              // Show range radius if available
                              if (rec.rangeRadius > 0)
                                Chip(
                                  label: Text('${rec.rangeRadius} m'),
                                  backgroundColor: Colors.grey.shade100,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.water_drop, size: 18, color: Colors.blue[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'History: ${rec.districtTotalM3.toStringAsFixed(2)} m³',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.trending_up, size: 18, color: Colors.green[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Next month: ${rec.districtForecastNextMonthM3.toStringAsFixed(2)} m³',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Colors.purple[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Next 12 months: ${rec.districtForecast12mM3.toStringAsFixed(2)} m³',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.group_work, size: 18, color: Colors.orange[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cluster: ${rec.highestDemandCluster}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Explanation box with expand/collapse (limit height to avoid overflow)
                    Container(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(maxHeight: 110),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200, width: 0.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Builder(builder: (context) {
                                  final isExpanded = _expandedCards.contains(rec.district);
                                  final explanation = rec.explanation.trim();
                                  if (explanation.isEmpty) {
                                    return const Text('No additional details.', style: TextStyle(fontSize: 13));
                                  }
                                  if (isExpanded) {
                                    return SizedBox(
                                      height: 100,
                                      child: SingleChildScrollView(
                                        child: Text(explanation, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
                                      ),
                                    );
                                  }

                                  // truncated
                                  final truncated = explanation.length > 140 ? explanation.substring(0, 140).trim() + '...' : explanation;
                                  if (explanation.length > 140) {
                                    return RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                                        children: [
                                          TextSpan(text: truncated),
                                          TextSpan(
                                            text: ' Read more',
                                            style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w700),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () {
                                                setState(() {
                                                  _expandedCards.add(rec.district);
                                                });
                                              },
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Text(explanation, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400));
                                }),
                              ),
                            ],
                          ),
                          // collapse control when expanded
                          if (_expandedCards.contains(rec.district))
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _expandedCards.remove(rec.district);
                                  });
                                },
                                child: const Text('Show less', style: TextStyle(fontSize: 13, color: Color(0xFF4A5568))),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Copy coords
                        IconButton(
                          tooltip: 'Copy coordinates',
                          onPressed: () async {
                            final coords = '${rec.lat.toStringAsFixed(6)},${rec.lng.toStringAsFixed(6)}';
                            await Clipboard.setData(ClipboardData(text: coords));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Coordinates copied'), behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                          icon: Icon(Icons.copy, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 6),
                        // Open in Google Maps
                        IconButton(
                          tooltip: 'Open in Google Maps',
                          onPressed: () async {
                            final coords = '${rec.lat.toStringAsFixed(6)},${rec.lng.toStringAsFixed(6)}';
                            final url = 'https://www.google.com/maps/search/?api=1&query=$coords';
                            if (await canLaunch(url)) {
                              await launch(url);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open maps'), behavior: SnackBarBehavior.floating),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.map_outlined, color: Colors.blue[700]),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: const Text('View Map', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () => _showMapSheet(context, rec.lat, rec.lng, rec.district),
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
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
          ),
        );
      },
    );
  }

  Widget _buildOverviewCardFromData(BuildContext context, Map<String, dynamic> data) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final total = parseDouble(data['overall_total_m3'] ?? data['overall_total'] ?? data['total_m3']);
    final nextMonth = parseDouble(data['overall_forecast_next_month_m3'] ?? data['overall_forecast_next_month'] ?? data['overall_forecast_next_month_m3']);
    final next12 = parseDouble(data['overall_forecast_12m_m3'] ?? data['overall_forecast_12m'] ?? data['overall_forecast_12m_m3']);
    final top = data['highest_next_month_district']?.toString() ?? data['highest_next_month_district']?.toString() ?? '';
    final low = data['lowest_next_month_district']?.toString() ?? '';

    final pct = total > 0 ? (nextMonth / (total + 0.0001)) : 0.0;

    // try to get a monthly series for the larger trend graph
    List<double>? series;
    // support multiple field names that might be present from the backend
    final possibleSeriesKeys = [
      'monthly_series',
      'monthly_trend_current_year',
      'overall_monthly_series',
      'monthly_series_m3',
      'monthly_trend',
    ];

    // Prefer the map form `monthly_trend_current_year` (YYYY-MM -> {actual_m3, forecast_m3})
    if (data['monthly_trend_current_year'] is Map) {
      final mt = data['monthly_trend_current_year'] as Map;
      final keys = mt.keys.map((k) => k.toString()).toList()..sort();
      series = keys.map((k) {
        final entry = mt[k];
        double v = 0.0;
        if (entry is Map) {
          final actual = entry['actual_m3'];
          final forecast = entry['forecast_m3'];
          final hasActual = actual != null;
          final hasForecast = forecast != null;
          if (hasActual && hasForecast) {
            v = (double.tryParse(actual.toString()) ?? 0.0) + (double.tryParse(forecast.toString()) ?? 0.0);
          } else if (hasActual) {
            v = double.tryParse(actual.toString()) ?? 0.0;
          } else if (hasForecast) {
            v = double.tryParse(forecast.toString()) ?? 0.0;
          }
        }
        return v;
      }).toList();
    }

    // fallback list-style keys
    if (series == null) {
      for (final key in possibleSeriesKeys) {
        if (data[key] is List) {
          series = (data[key] as List).map((e) {
            try {
              return double.parse(e.toString());
            } catch (_) {
              return 0.0;
            }
          }).toList();
          break;
        }
      }
    }

    // If values look like liters (>1000), convert to m³ for display
    if (series != null && series.isNotEmpty) {
      final maxV = series.reduce((a, b) => a > b ? a : b);
      if (maxV > 1000) {
        series = series.map((v) => v / 1000.0).toList();
      }
    }

    // support for an overall PNG chart: prefer a direct image URL, then base64 PNG
    final String? chartUrl = data['overall_chart_url']?.toString();
    final String? chartBase64 = data['overall_chart_base64']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kPrimaryColor.withOpacity(0.95), kSecondaryColor.withOpacity(0.9)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dashboard, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Overall Forecast Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      if ((chartUrl != null && chartUrl.isNotEmpty) || (chartBase64 != null && chartBase64.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            tooltip: _overviewShowImage ? 'Show chart' : 'Show image',
                            icon: Icon(_overviewShowImage ? Icons.show_chart : Icons.image, color: Colors.blue[700]),
                            onPressed: () {
                              setState(() {
                                _overviewShowImage = !_overviewShowImage;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (series != null && series.isNotEmpty && !_overviewShowImage)
                    Container(
                      height: 180,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _OverviewLineChart(points: series),
                      ),
                    )
                  else if (_overviewShowImage && chartUrl != null && chartUrl.isNotEmpty)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(chartUrl, fit: BoxFit.cover, width: double.infinity),
                    )
                  else if (_overviewShowImage && chartBase64 != null && chartBase64.isNotEmpty)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(base64Decode(chartBase64), fit: BoxFit.cover, width: double.infinity),
                    )
                  else if (series != null && series.isNotEmpty)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(padding: const EdgeInsets.all(8.0), child: _OverviewLineChart(points: series)),
                    )
                  else if (chartUrl != null && chartUrl.isNotEmpty)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(chartUrl, fit: BoxFit.cover, width: double.infinity),
                    )
                  else if (chartBase64 != null && chartBase64.isNotEmpty)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(base64Decode(chartBase64), fit: BoxFit.cover, width: double.infinity),
                    )
                  else
                    Container(
                      height: 160,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('No overview series or image available', style: TextStyle(color: Colors.grey[500]))),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Total historical: ${total.toStringAsFixed(2)} m³', style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 12),
                      Chip(label: Text('Top: $top'), backgroundColor: Colors.blue.shade50),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Next month: ${nextMonth.toStringAsFixed(2)} m³', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: pct.clamp(0.0, 1.0), color: kPrimaryColor, backgroundColor: kPrimaryColor.withOpacity(0.08)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Next 12m: ${next12.toStringAsFixed(2)} m³', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('Lowest: $low', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              child: const Text('Details'),
            ),
          ],
        ),
      ),
    );
  }
}

// (sparkline removed — use _OverviewLineChart for larger/consistent charts)

// Overview line chart using fl_chart
class _OverviewLineChart extends StatefulWidget {
  final List<double> points;
  const _OverviewLineChart({Key? key, required this.points}) : super(key: key);

  @override
  State<_OverviewLineChart> createState() => _OverviewLineChartState();
}

class _OverviewLineChartState extends State<_OverviewLineChart> {
  Offset? _touchPosition; // local position inside the chart
  FlSpot? _touchedSpot;
  bool _showTooltip = false;
  Timer? _hideTooltipTimer;

  List<FlSpot> _toSpots() {
    return List.generate(widget.points.length, (i) => FlSpot(i.toDouble(), widget.points[i]));
  }

  @override
  Widget build(BuildContext context) {
    final spots = _toSpots();
    double minY = widget.points.reduce((a, b) => a < b ? a : b);
    double maxY = widget.points.reduce((a, b) => a > b ? a : b);

    // ensure a non-zero span so fl_chart doesn't crash
    if ((maxY - minY).abs() < 0.0001) {
      maxY = minY + 1.0;
      minY = (minY - 1.0).clamp(0.0, double.infinity);
    }

    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final Color chartColor = kPrimaryColor;

    // Use a LayoutBuilder + Stack so we can compute chart dimensions and render
    // a tooltip overlay without clipping the surrounding UI.
    return SizedBox(
      height: 150,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth;
          final chartHeight = constraints.maxHeight;
          const double padH = 8.0;
          const double padV = 8.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The chart itself
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                  child: LineChart(
                    LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.12), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          final label = (idx >= 0 && idx < months.length) ? months[idx] : '';
                          return Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: minY,
                  maxY: maxY,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      // we handle touches and tooltip rendering ourselves to avoid
                      // fl_chart drawing built-in vertical guideline that can affect
                      // the visual layout. Disable the built-in touch handling.
                      handleBuiltInTouches: false,
                      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                        Offset? localPos;
                        try {
                          localPos = event.localPosition;
                        } catch (_) {
                          localPos = null;
                        }

                        if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                          // Cancel any pending hide
                          _hideTooltipTimer?.cancel();
                          final touched = response.lineBarSpots!.first;
                          final spot = FlSpot(touched.x, touched.y);
                          setState(() {
                            _showTooltip = true;
                            _touchedSpot = spot;
                            // localPos is relative to the LineChart internal drawing area. Adjust
                            // it by the padding so it becomes relative to the Stack.
                            if (localPos != null) _touchPosition = localPos + const Offset(padH, padV);
                          });
                        } else {
                          // Defer hiding slightly to avoid flicker when hovering between events
                          _hideTooltipTimer?.cancel();
                          _hideTooltipTimer = Timer(const Duration(milliseconds: 250), () {
                            if (mounted) {
                              setState(() {
                                _showTooltip = false;
                                _touchedSpot = null;
                              });
                            }
                          });
                        }
                      },
                    // Don't let fl_chart draw the touched-spot indicator (we show our
                    // own tooltip overlay). Returning an empty list prevents the
                    // library from drawing the vertical guideline.
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return <TouchedSpotIndicatorData>[];
                    },
                    touchTooltipData: LineTouchTooltipData(getTooltipItems: (touchedSpots) => []),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: chartColor,
                      barWidth: 2,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: chartColor.withOpacity(0.12)),
                    ),
                  ],
                ),
              ),
            ),
          ),

              // Custom tooltip overlay
              if (_showTooltip && _touchedSpot != null)
                Positioned(
                  // If we have a captured local touch position, use it; otherwise estimate using the spot's x index
                  left: _calculateTooltipLeft(chartWidth, _touchPosition, _touchedSpot!, spots.length),
                  top: _calculateTooltipTop(chartHeight, _touchPosition),
                  child: IgnorePointer(
                    child: Material(
                      elevation: 6,
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              // month + value
                              '${_formatMonthLabel(_touchedSpot!, months)}\n${_touchedSpot!.y.toStringAsFixed(1)} m³',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _hideTooltipTimer?.cancel();
    super.dispose();
  }

  double _calculateTooltipLeft(double width, Offset? localPos, FlSpot spot, int pointsCount) {
    // If we have a local pointer, use it
    if (localPos != null) {
      // clamp so the tooltip doesn't go off-screen
      final left = localPos.dx - 40;
      return left.clamp(6.0, width - 120.0);
    }
    // fallback: estimate position based on spot.x relative index
    final fraction = (spot.x / (pointsCount - 1)).clamp(0.0, 1.0);
    return (fraction * width).clamp(6.0, width - 120.0);
  }

  double _calculateTooltipTop(double height, Offset? localPos) {
    if (localPos != null) {
      final top = localPos.dy - 60;
      return top.clamp(6.0, height - 30.0);
    }
    // fallback: show near top of chart
    return 8.0;
  }

  String _formatMonthLabel(FlSpot spot, List<String> months) {
    final idx = spot.x.round();
    if (idx >= 0 && idx < months.length) return '${months[idx]}';
    return '';
  }
}
 
