import 'package:flutter/material.dart';

/// This file demonstrates responsive UI patterns for the recommendations page
/// Copy these patterns into recommendations_page.dart to improve responsiveness

const Color kPrimaryColor = Color(0xFF1976D2);
const Color kSecondaryColor = Color(0xFF42A5F5);
const Color kSuccessColor = Color(0xFF48BB78);
const Color kWarningColor = Color(0xFFED8936);

/// PATTERN 1: Responsive Map Buttons
/// Use this pattern for the map/heatmap section
class ResponsiveMapButtons extends StatelessWidget {
  final String recommendationsMapUrl;
  final String demandHeatmapUrl;
  final Function(BuildContext, String, String) showMapDialog;

  const ResponsiveMapButtons({
    Key? key,
    required this.recommendationsMapUrl,
    required this.demandHeatmapUrl,
    required this.showMapDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Visual Maps',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'See where customers are located and where water demand is highest. These maps help you decide where to build new water stations.',
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 18),
            
            // RESPONSIVE LAYOUT: Column for mobile, Row for desktop
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildButtons(context),
                      )
                    : Row(
                        children: _buildButtons(context)
                            .map((btn) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: btn,
                                  ),
                                ))
                            .toList(),
                      );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tip: Click "Generate Recommendations" first to create these maps.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    return [
      _buildMapButton(
        context,
        'View Station Locations',
        Icons.location_on,
        kPrimaryColor,
        recommendationsMapUrl,
        'Station Locations Map',
      ),
      const SizedBox(height: 12),
      _buildMapButton(
        context,
        'View Demand Heatmap',
        Icons.thermostat,
        kSecondaryColor,
        demandHeatmapUrl,
        'Water Demand Heatmap',
      ),
    ];
  }

  Widget _buildMapButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String url,
    String dialogTitle,
  ) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => showMapDialog(context, dialogTitle, url),
    );
  }
}

/// PATTERN 2: Responsive DataTable with Legend
/// Use this pattern for the consolidated recommendations table
class ResponsiveDataTableCard extends StatelessWidget {
  final List<DataRow> rows;
  final List<DataColumn> columns;
  final String title;
  final String subtitle;

  const ResponsiveDataTableCard({
    Key? key,
    required this.rows,
    required this.columns,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            
            // RESPONSIVE TABLE: Horizontal scroll with minimum width constraint
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 80,
                ),
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  headingRowColor: MaterialStateColor.resolveWith(
                    (states) => kPrimaryColor.withOpacity(0.1),
                  ),
                  dataRowColor: MaterialStateColor.resolveWith(
                    (states) => Colors.white,
                  ),
                  headingRowHeight: 56,
                  dataRowHeight: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  columns: columns,
                  rows: rows,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // HELPFUL LEGEND
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Understanding the table:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildLegendItem('Trend', 'Shows if water usage is going up ↑ or down ↓'),
          _buildLegendItem('Demand Stability', 'Low = predictable, High = varies a lot'),
          _buildLegendItem('Buffer Stock', 'Extra water to keep ready for surprises'),
          _buildLegendItem('Reorder At', 'When to order more water'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String term, String explanation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13, color: kPrimaryColor)),
          Text(
            '$term: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              explanation,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// PATTERN 3: User-Friendly Tooltip Wrapper
/// Use this to add helpful tooltips to metrics
class MetricWithTooltip extends StatelessWidget {
  final String value;
  final String tooltip;
  final TextStyle? style;

  const MetricWithTooltip({
    Key? key,
    required this.value,
    required this.tooltip,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Text(value, style: style),
    );
  }
}

/// PATTERN 4: Responsive Info Cards Layout
/// Use this for the overview card's highest/lowest demand display
class ResponsiveInfoCards extends StatelessWidget {
  final List<Widget> cards;

  const ResponsiveInfoCards({Key? key, required this.cards}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((card) {
            return SizedBox(
              width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }
}

/// PATTERN 5: Info Card with Icon
/// Simple, clean card design for displaying key metrics
class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String tooltip;

  const InfoCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? 'N/A' : value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PATTERN 6: Loading State with Context
/// Better loading indicators that explain what's happening
class LoadingCard extends StatelessWidget {
  final String message;

  const LoadingCard({Key? key, this.message = 'Loading...'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(24),
        height: 140,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// USAGE EXAMPLES:
/// 
/// // 1. Map Buttons:
/// ResponsiveMapButtons(
///   recommendationsMapUrl: url1,
///   demandHeatmapUrl: url2,
///   showMapDialog: _showMapDialog,
/// )
///
/// // 2. Info Cards:
/// ResponsiveInfoCards(
///   cards: [
///     InfoCard(
///       title: 'Highest Demand District',
///       value: 'Arevalo',
///       icon: Icons.trending_up,
///       color: kSuccessColor,
///       tooltip: 'This district needs the most water next month',
///     ),
///     InfoCard(
///       title: 'Lowest Demand District',
///       value: 'City Proper',
///       icon: Icons.trending_down,
///       color: Colors.blue,
///       tooltip: 'This district needs the least water next month',
///     ),
///   ],
/// )
///
/// // 3. Loading State:
/// LoadingCard(message: 'Loading forecast data...')
