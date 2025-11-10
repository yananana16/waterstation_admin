import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  // Improved: enforce a minHeight and avoid Spacer (which caused bottom overflow).
  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    Widget? trailingIcon,
    AlignmentGeometry buttonAlignment = Alignment.bottomRight,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 120), // reduced overflow risk
          clipBehavior: Clip.hardEdge, // guard against visual overflow
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6)),
            ],
            border: Border.all(color: const Color(0xFFE7F0FF)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min, // avoid expanding unexpectedly
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF087693).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 26, color: const Color(0xFF087693)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
                        const SizedBox(height: 6),
                        Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.35)),
                      ],
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 12),
                    trailingIcon,
                  ],
                ],
              ),
              // small spacer instead of a full Spacer to keep height predictable
              const SizedBox(height: 10),
              if (buttonText.isNotEmpty)
                Align(
                  alignment: buttonAlignment,
                  child: TextButton(
                    onPressed: onPressed,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F0FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(buttonText, style: const TextStyle(color: Color.fromARGB(255, 0, 92, 118), fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Metric cards: use adaptive constraints instead of strict fixed height
  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(builder: (context, constraints) {
          // If the available width is small, allow taller minHeight to accommodate wrapped text.
          final isNarrow = constraints.maxWidth < 240;
          final minH = isNarrow ? 110.0 : 88.0;

          return Container(
            constraints: BoxConstraints(minHeight: minH, maxWidth: constraints.maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7F0FF)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF087693).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF087693), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      // allow up to 2 lines for value; if it wraps, container minHeight avoids overflow
                      Text(value, style: const TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 92, 118), fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _largeCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7F0FF)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _ordersByAreaPlaceholder() {
    final data = <Map<String, dynamic>>[
      {'label': 'Mandurriao', 'value': 95},
      {'label': 'Jaro', 'value': 65},
      {'label': 'La Paz', 'value': 40},
      {'label': 'Molo', 'value': 15},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Orders by Area', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
        const SizedBox(height: 12),
        ...data.map((d) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 120, child: Text(d['label'], style: const TextStyle(color: Colors.black87))), // slightly wider label
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(
                    children: [
                      Container(height: 14, decoration: BoxDecoration(color: const Color(0xFFF1F6FF), borderRadius: BorderRadius.circular(6))),
                      FractionallySizedBox(
                        widthFactor: (d['value'] as int) / 100,
                        child: Container(height: 14, decoration: BoxDecoration(color: const Color(0xFF087693), borderRadius: BorderRadius.circular(6))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 36, child: Text('${d['value']}', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // slightly taller sparkline for better readability
  Widget _sparklinePlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _SparklinePainter(),
            size: const Size(double.infinity, 140),
          ),
        ),
      ],
    );
  }

  Widget _mapPlaceholder() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, // center content to avoid overflow
            children: [
              const Text('Station Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
              const SizedBox(height: 8),
              const Text(
                'Open a new station in Jaro, where demand is high, coverage low.',
                style: TextStyle(color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(64, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View details'),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 96,
          height: 64,
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF5F8FF), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Icon(Icons.location_on, color: Color(0xFF087693), size: 36)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build row/column layout to mimic the screenshot
    final leftMapCard = _buildCard(
      icon: Icons.place,
      title: 'New Station Suggested',
      subtitle: 'Plaza Rizal Street, Remon Ville, Jaro',
      buttonText: 'View on Map',
      onPressed: () {},
      buttonAlignment: Alignment.bottomLeft,
    );

    final statSales = Container(
      child: _buildCard(
        icon: Icons.show_chart,
        title: 'Total Sales',
        subtitle: 'P 125,000',
        buttonText: '',
        onPressed: () {},
      ),
    );

    final statCompliance = _buildCard(
      icon: Icons.check_circle,
      title: 'Compliance Issues',
      subtitle: '3 expiring soon',
      buttonText: '',
      onPressed: () {},
    );

    final salesDashboard = _buildCard(
      icon: Icons.bar_chart,
      title: 'Sales Dashboard',
      subtitle: 'Track sales performance-top products',
      buttonText: 'View Sales',
      onPressed: () {},
    );

    final districtOverview = _buildCard(
      icon: Icons.pie_chart,
      title: 'District Overview',
      subtitle: '12 stations · 84% demand served within 5 km',
      buttonText: 'Relay Now',
      onPressed: () {},
    );

    final trend1 = _buildCard(
      icon: Icons.trending_up,
      title: 'Trend Insight',
      subtitle: 'Orders increased by 12% compared to last month',
      buttonText: '',
      onPressed: () {},
    );

    final trend2 = _buildCard(
      icon: Icons.trending_up,
      title: 'Trend Insight',
      subtitle: 'Orders increased by 12% compared to last month',
      buttonText: '',
      onPressed: () {},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24), // slightly wider horizontal padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and date dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('District Recommendations Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
                  SizedBox(height: 6),
                  Text('Actionable insights for stations in Jaro District', style: TextStyle(fontSize: 14, color: Colors.black54)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<String>(
                  value: 'Last 30 days',
                  items: const [
                    DropdownMenuItem(value: 'Last 30 days', child: Text('Last 30 days')),
                    DropdownMenuItem(value: 'Last 7 days', child: Text('Last 7 days')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top four metric cards - ensure a reasonable min width per card on wide layouts
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            final available = (constraints.maxWidth - (isWide ? 48 : 0));
            // apply a sensible min width so cards don't shrink too much
            final computed = isWide ? (available / 4) - 12 : double.infinity;
            final cardWidth = isWide ? math.max(220.0, computed) : double.infinity;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: cardWidth, child: _metricCard(icon: Icons.place, title: 'New Station Needed', value: '1 Location\n(Jaro Central)', onTap: () {})),
                SizedBox(width: cardWidth, child: _metricCard(icon: Icons.shopping_cart, title: 'Orders', value: '1,235', subtitle: 'In District')),
                SizedBox(width: cardWidth, child: _metricCard(icon: Icons.trip_origin, title: 'Avg Delivery Distance', value: '7.8 km')),
                SizedBox(width: cardWidth, child: _metricCard(icon: Icons.warning, title: 'Stations Overloaded', value: '2')),
              ],
            );
          }),

          const SizedBox(height: 20),

          // Middle: Orders by Area (left) and Order Trend (right)
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 240), child: _largeCard(child: _ordersByAreaPlaceholder()))),
                  const SizedBox(width: 20),
                  Expanded(flex: 1, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 240), child: _largeCard(child: _sparklinePlaceholder()))),
                ],
              );
            } else {
              return Column(
                children: [
                  _largeCard(child: _ordersByAreaPlaceholder()),
                  const SizedBox(height: 12),
                  _largeCard(child: _sparklinePlaceholder()),
                ],
              );
            }
          }),

          const SizedBox(height: 20),

          // Bottom: Station Location, Delivery Fee, Statinform
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            if (isWide) {
              return Row(
                children: [
                  Expanded(flex: 2, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 120), child: _largeCard(child: _mapPlaceholder()))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 120),
                      child: _largeCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                              Text('Delivery Fee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
                              SizedBox(height: 8),
                              Text('Reduce delivery fees in La Paz above.', style: TextStyle(color: Colors.black87)),
                            ]),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(64, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Manage'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 120),
                      child: _largeCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                              Text('Statinform', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
                              SizedBox(height: 8),
                              Text('5 stations overloaded by recent daily data.', style: TextStyle(color: Colors.black87)),
                            ]),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(64, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('View'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _largeCard(child: _mapPlaceholder()),
                  const SizedBox(height: 12),
                  _largeCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Delivery Fee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
                      const SizedBox(height: 8),
                      const Text('Reduce delivery fees in La Paz above.', style: TextStyle(color: Colors.black87)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () {}, child: const Text('Manage')),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _largeCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Statinform', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 92, 118))),
                      const SizedBox(height: 8),
                      const Text('5 stations overloaded by recent daily data.', style: TextStyle(color: Colors.black87)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () {}, child: const Text('View')),
                    ]),
                  ),
                ],
              );
            }
          }),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points = [40, 45, 50, 60, 55, 70, 65, 76, 72, 78];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0 || points.isEmpty) return;

    final paintFill = Paint()..color = const Color(0xFFEAF3FF);
    final paintLine = Paint()
      ..color = const Color(0xFF2B6BE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..isAntiAlias = true;

    final path = Path();
    final double dx = size.width / (points.length - 1);
    final double max = points.reduce((a, b) => a > b ? a : b);
    if (max == 0) return;

    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - (points[i] / max) * size.height;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }

    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    // small circles
    final dotPaint = Paint()..color = const Color(0xFF2B6BE8);
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - (points[i] / max) * size.height;
      canvas.drawCircle(Offset(x, y), 2.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
