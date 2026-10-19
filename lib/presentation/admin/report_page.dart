import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String _selectedRange = 'This Week';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kGold),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: const Text(
          'REPORTS & ANALYTICS',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Date Range Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performance Analytics',
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time production, uptime, and efficiency report',
                        style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter(),
              ],
            ),
            const SizedBox(height: 24),

            // Performance KPIs Grid
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildKpiCard('Total Yield', '1,240 Tons', Icons.inventory_2_rounded, '+12.4% vs last week'),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildKpiCard('Avg. Efficiency', '92.4%', Icons.speed_rounded, 'Optimal state'),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildKpiCard('Active Jobs', '18 Operations', Icons.settings_input_component_rounded, 'In processing'),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildKpiCard('Gold Recovered', '4,850 Grams', Icons.monetization_on_rounded, 'Verified yield'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Weekly Production Chart
            _buildChartContainer(
              title: 'Production Output (Tonnage)',
              subtitle: 'Daily material output across all ball mills',
              child: const _ProductionBarChart(),
            ),
            const SizedBox(height: 24),

            // System Performance & Health Chart
            _buildChartContainer(
              title: 'System Uptime & Stability',
              subtitle: 'Operational uptime and machine stability trend',
              child: const _PerformanceLineChart(),
            ),
            const SizedBox(height: 24),

            // Detailed Production Table
            Text(
              'Equipment Production Breakdown',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildProductionTable(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRange,
          dropdownColor: context.surfaceColor,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kGold, size: 20),
          style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.bold),
          items: ['Today', 'This Week', 'This Month', 'Yearly']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _selectedRange = v!),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, String footnote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: kGold, size: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  footnote,
                  style: const TextStyle(color: kGold, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            subtitle,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 24),
          SizedBox(height: 180, width: double.infinity, child: child),
        ],
      ),
    );
  }

  Widget _buildProductionTable() {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTableRow('Mill / Machine ID', 'Type', 'Yield (Tons)', 'Status', isHeader: true),
          const Divider(height: 1),
          _buildTableRow('Ball Mill #01', 'Primary Mill', '420', 'Optimal'),
          _buildTableRow('Ball Mill #02', 'Secondary Mill', '385', 'Optimal'),
          _buildTableRow('Ball Mill #03', 'Primary Mill', '120', 'Low Yield'),
          _buildTableRow('Processing Plant #01', 'Refinery Unit', '315', 'Maintenance'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String id, String type, String yieldVal, String status, {bool isHeader = false}) {
    final style = TextStyle(
      color: isHeader ? kGold : context.textColor,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontSize: isHeader ? 11 : 12,
    );

    Color statusColor = Colors.green;
    if (status == 'Low Yield') statusColor = Colors.orange;
    if (status == 'Maintenance') statusColor = Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(id, style: style)),
          Expanded(flex: 2, child: Text(type, style: TextStyle(color: context.mutedTextColor, fontSize: 11))),
          Expanded(flex: 1, child: Text(yieldVal, style: style, textAlign: TextAlign.center)),
          Expanded(
            flex: 2,
            child: isHeader
                ? Text(status, style: style, textAlign: TextAlign.right)
                : Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductionBarChart extends StatelessWidget {
  const _ProductionBarChart();

  @override
  Widget build(BuildContext context) {
    final data = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.5];
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (index) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                width: 22,
                decoration: BoxDecoration(
                  color: kGold.withOpacity(index == 3 ? 1.0 : 0.25),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: data[index],
                  child: Container(
                    width: 22,
                    decoration: BoxDecoration(
                      color: kGold,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              labels[index],
              style: TextStyle(color: context.mutedTextColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        );
      }),
    );
  }
}

class _PerformanceLineChart extends StatelessWidget {
  const _PerformanceLineChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(kGold),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final Color color;
  _LineChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width, size.height * 0.2),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
