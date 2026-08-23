import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedRange = 'This Week';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(),
        ),
        title: const Text(
          'GAHIRA',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.report),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance Report',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildDropdownFilter(),
              ],
            ),
            const SizedBox(height: 24),

            // Performance KPIs
            Row(
              children: [
                Expanded(child: _buildKpiCard('Total Yield', '1,240 Tons', Icons.inventory_2_rounded)),
                const SizedBox(width: 16),
                Expanded(child: _buildKpiCard('Avg. Efficiency', '92.4%', Icons.speed_rounded)),
              ],
            ),
            const SizedBox(height: 24),

            // Weekly Production Chart
            _buildChartContainer(
              title: 'Weekly Production Output',
              subtitle: 'Daily tonnage across all mills',
              child: const _ProductionBarChart(),
            ),
            const SizedBox(height: 24),

            // System Performance (Line Chart Mockup)
            _buildChartContainer(
              title: 'System Uptime & Health',
              subtitle: 'Performance stability over last 24h',
              child: const _PerformanceLineChart(),
            ),
            const SizedBox(height: 24),

            // Detailed Production Table Mockup
            Text(
              'Production Breakdown',
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRange,
          dropdownColor: context.surfaceColor,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kGold, size: 20),
          style: TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600),
          items: ['Today', 'This Week', 'This Month', 'Yearly']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _selectedRange = v!),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kGold, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.w600),
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
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildTableRow('Mill ID', 'Yield (T)', 'Status', isHeader: true),
          const Divider(height: 1),
          _buildTableRow('Mill #01', '420', 'Optimal'),
          _buildTableRow('Mill #02', '385', 'Optimal'),
          _buildTableRow('Mill #03', '120', 'Low Yield'),
          _buildTableRow('Mill #04', '315', 'Maintenance'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String id, String yield, String status, {bool isHeader = false}) {
    final style = TextStyle(
      color: isHeader ? kGold : context.textColor,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontSize: isHeader ? 12 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(id, style: style)),
          Expanded(child: Text(yield, style: style, textAlign: TextAlign.center)),
          Expanded(child: Text(status, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.6),
        color: context.bgColor,
      ),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}

class _ProductionBarChart extends StatelessWidget {
  const _ProductionBarChart();

  @override
  Widget build(BuildContext context) {
    final data = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.5];
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (index) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                width: 20,
                decoration: BoxDecoration(
                  color: kGold.withOpacity(index == 3 ? 1.0 : 0.3),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: data[index],
                  child: Container(
                    width: 20,
                    decoration: BoxDecoration(
                      color: kGold,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              labels[index],
              style: TextStyle(color: context.mutedTextColor, fontSize: 10),
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
      ..color = color.withOpacity(0.05)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
