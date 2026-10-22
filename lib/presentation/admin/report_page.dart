import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../infrastructure/repositories/supabase_report_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

enum _ReportRange { today, week, month, year }

extension on _ReportRange {
  String get label => switch (this) {
    _ReportRange.today => 'Today',
    _ReportRange.week => 'This Week',
    _ReportRange.month => 'This Month',
    _ReportRange.year => 'Yearly',
  };
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _repository = SupabaseReportRepository();
  _ReportRange _selectedRange = _ReportRange.week;
  late Future<AdminReportData> _reportFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  Future<AdminReportData> _loadReport() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endExclusive = today.add(const Duration(days: 1));
    final start = switch (_selectedRange) {
      _ReportRange.today => today,
      _ReportRange.week => today.subtract(Duration(days: today.weekday - 1)),
      _ReportRange.month => DateTime(today.year, today.month),
      _ReportRange.year => DateTime(today.year),
    };
    return _repository.getReportData(start: start, endExclusive: endExclusive);
  }

  void _selectRange(_ReportRange? range) {
    if (range == null || range == _selectedRange) return;
    setState(() {
      _selectedRange = range;
      _reportFuture = _loadReport();
    });
  }

  void _refresh() {
    setState(() => _reportFuture = _loadReport());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
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
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: kGold),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<AdminReportData>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGold));
          }
          if (snapshot.hasError) {
            return _buildMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load report data',
              message: snapshot.error.toString(),
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return _buildMessage(
              icon: Icons.info_outline_rounded,
              title: 'Report data is unavailable',
              message: 'Refresh the report to try again.',
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            );
          }
          return _buildReport(data);
        },
      ),
    );
  }

  Widget _buildReport(AdminReportData data) {
    final requests = data.serviceRequests;
    final activeJobs = requests.where((request) {
      final status = _text(request['status']).toLowerCase();
      return const {
        'queued',
        'scheduled',
        'assigned',
        'processing',
      }.contains(status);
    }).length;
    final completed = requests.where((request) {
      final status = _text(request['status']).toLowerCase();
      return status == 'completed' || status == 'processingcompleted';
    }).length;
    final recoveredGold = requests
        .where(_isRenderedService)
        .fold<double>(
          0,
          (sum, request) => sum + _number(request['gold_weight_grams']),
        );
    final payments =
        [
          ...data.participantPayments,
          ...data.serviceRequestPayments,
        ].fold<double>(
          0,
          (sum, payment) =>
              sum + _number(payment['amount'] ?? payment['payment_amount']),
        );
    final batchTotals = _batchTotals(data.millingBatches);
    final points = _chartPoints(data.millingBatches);

    return RefreshIndicator(
      onRefresh: () async {
        final future = _loadReport();
        setState(() => _reportFuture = future);
        await future;
      },
      color: kGold,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
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
                    const SizedBox(height: 3),
                    Text(
                      'Live totals from service requests and milling batches',
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildDropdownFilter(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _rangeDescription(),
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<String>(
              tooltip: 'Export report',
              enabled: !_isExporting,
              onSelected: (format) => _exportReport(data, format),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.table_chart_outlined),
                    title: Text('Excel / CSV'),
                    subtitle: Text('Spreadsheet compatible'),
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('PDF'),
                    subtitle: Text('Print or share report'),
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: kGold.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isExporting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.download_rounded,
                        color: kGold,
                        size: 18,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isExporting ? 'Preparing...' : 'Export report',
                      style: const TextStyle(color: kGold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      'Total gold recovered (g)',
                      _formatNumber(recoveredGold),
                      Icons.monetization_on_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      'Active jobs',
                      '$activeJobs',
                      Icons.settings_input_component_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      'Payments collected',
                      _formatCurrency(payments),
                      Icons.payments_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      'Completed services',
                      '$completed',
                      Icons.task_alt_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      'Milling batches',
                      '${data.millingBatches.length}',
                      Icons.factory_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildChartContainer(
            title: 'Milling output',
            subtitle: 'Output sacks recorded in milling batches',
            child: _buildBarChart(points),
          ),
          const SizedBox(height: 24),
          _buildChartContainer(
            title: 'Service activity',
            subtitle: 'Requests by requested service date',
            child: _buildServiceActivityChart(requests),
          ),
          const SizedBox(height: 24),
          _buildChartContainer(
            title: 'Request outcomes',
            subtitle:
                'Requests approved, rejected, or needing corrections in the selected period',
            child: _buildRequestOutcomesChart(requests),
          ),
          const SizedBox(height: 24),
          Text(
            'Equipment Production Breakdown',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildProductionTable(data.machines, batchTotals),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _exportReport(AdminReportData data, String format) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileBase = 'EGReS_Report_${_selectedRange.name}_$timestamp';
      if (format == 'csv') {
        final csv = _buildCsv(data);
        final bytes = Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          ...utf8.encode(csv),
        ]);
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save report as CSV',
          fileName: '$fileBase.csv',
          type: FileType.custom,
          allowedExtensions: const ['csv'],
          bytes: bytes,
        );
        if (savedPath == null) return;
        _showExportMessage('CSV report saved successfully.');
      } else {
        final document = _buildPdf(data);
        await Printing.sharePdf(
          bytes: await document.save(),
          filename: '$fileBase.pdf',
        );
      }
    } catch (error) {
      _showExportMessage('Could not export report: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  String _buildCsv(AdminReportData data) {
    final requests = data.serviceRequests;
    final activeJobs = requests
        .where(
          (request) => const {
            'queued',
            'scheduled',
            'assigned',
            'processing',
          }.contains(_text(request['status']).toLowerCase()),
        )
        .length;
    final completed = requests.where((request) {
      final status = _text(request['status']).toLowerCase();
      return status == 'completed' || status == 'processingcompleted';
    }).length;
    final recoveredGold = requests
        .where(_isRenderedService)
        .fold<double>(
          0,
          (sum, request) => sum + _number(request['gold_weight_grams']),
        );
    final payments =
        [
          ...data.participantPayments,
          ...data.serviceRequestPayments,
        ].fold<double>(
          0,
          (sum, payment) =>
              sum + _number(payment['amount'] ?? payment['payment_amount']),
        );
    final rows = <List<Object?>>[
      ['EGReS Reports & Analytics'],
      ['Period', _rangeDescription()],
      ['Generated', DateFormat.yMMMd().add_Hm().format(DateTime.now())],
      [],
      ['Summary'],
      ['Metric', 'Value'],
      ['Total gold recovered (g)', recoveredGold],
      ['Active jobs', activeJobs],
      ['Payments collected (PHP)', payments],
      ['Completed services', completed],
      ['Milling batches', data.millingBatches.length],
      [],
      ['Service requests'],
      ['SR reference', 'Request date', 'Status', 'Gold weight (g)'],
      ...requests.map(
        (request) => [
          _serviceReference(request['service_request_id']),
          request['request_date'],
          request['status'],
          request['gold_weight_grams'],
        ],
      ),
      [],
      ['Milling batches'],
      [
        'Batch ID',
        'Machine ID',
        'Created at',
        'Input sacks',
        'Output sacks',
        'Status',
      ],
      ...data.millingBatches.map(
        (batch) => [
          batch['batch_id'],
          batch['machine_id'],
          batch['created_at'],
          batch['input_sacks'],
          batch['output_sacks'],
          batch['status'],
        ],
      ),
      [],
      ['Payments'],
      ['Payment ID', 'Payment date', 'Amount (PHP)'],
      ...data.participantPayments.map(
        (payment) => [
          payment['payment_id'],
          payment['payment_date'],
          payment['amount'],
        ],
      ),
      ...data.serviceRequestPayments.map(
        (payment) => [
          _serviceReference(payment['service_request_id']),
          payment['payment_date'],
          payment['payment_amount'],
        ],
      ),
      [],
      ['Equipment'],
      ['Machine ID', 'Machine name', 'Type', 'Status'],
      ...data.machines.map(
        (machine) => [
          machine['machine_id'],
          machine['machine_name'],
          machine['machine_type'],
          machine['status'],
        ],
      ),
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  String _csvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  String _serviceReference(Object? value) {
    final id = value?.toString() ?? '';
    if (id.isEmpty) return 'SR: N/A';
    return 'SR: ${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';
  }

  pw.Document _buildPdf(AdminReportData data) {
    final requests = data.serviceRequests;
    final gold = requests
        .where(_isRenderedService)
        .fold<double>(
          0,
          (sum, request) => sum + _number(request['gold_weight_grams']),
        );
    final payments =
        [
          ...data.participantPayments,
          ...data.serviceRequestPayments,
        ].fold<double>(
          0,
          (sum, payment) =>
              sum + _number(payment['amount'] ?? payment['payment_amount']),
        );
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'EGReS Reports & Analytics',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: ${_rangeDescription()}'),
          pw.Text(
            'Generated: ${DateFormat.yMMMd().add_Hm().format(DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Summary metric', 'Value'],
            data: [
              ['Total gold recovered (g)', _formatNumber(gold)],
              ['Service requests', '${requests.length}'],
              [
                'Completed services',
                '${requests.where((r) => const {'completed', 'processingcompleted'}.contains(_text(r['status']).toLowerCase())).length}',
              ],
              ['Payments collected (PHP)', _formatNumber(payments)],
              ['Milling batches', '${data.millingBatches.length}'],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Service requests',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['SR reference', 'Date', 'Status', 'Gold (g)'],
            data: requests
                .map(
                  (r) => [
                    _serviceReference(r['service_request_id']),
                    _text(r['request_date']),
                    _text(r['status']),
                    _formatNumber(_number(r['gold_weight_grams'])),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Milling batches',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Batch ID',
              'Machine',
              'Created',
              'In sacks',
              'Out sacks',
            ],
            data: data.millingBatches
                .map(
                  (b) => [
                    _text(b['batch_id']),
                    _text(b['machine_id']),
                    _text(b['created_at']),
                    _text(b['input_sacks']),
                    _text(b['output_sacks']),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return document;
  }

  Widget _buildDropdownFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGold.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ReportRange>(
          value: _selectedRange,
          dropdownColor: context.surfaceColor,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: kGold,
            size: 20,
          ),
          style: const TextStyle(
            color: kGold,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          items: _ReportRange.values
              .map(
                (range) =>
                    DropdownMenuItem(value: range, child: Text(range.label)),
              )
              .toList(),
          onChanged: _selectRange,
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
        border: Border.all(color: kGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kGold, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildChartContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildBarChart(List<_ChartPoint> points) {
    if (points.isEmpty || points.every((point) => point.value == 0)) {
      return _emptyChart('No milling output recorded for this period.');
    }
    final maxValue = points.fold<double>(
      0,
      (maximum, point) => math.max(maximum, point.value),
    );
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 100,
      points.length * 32.0,
    );
    return SizedBox(
      height: 180,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final height = maxValue == 0 ? 0.0 : point.value / maxValue * 130;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatNumber(point.value),
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: math.max(height, 2),
                        decoration: BoxDecoration(
                          color: kGold,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        point.label,
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceActivityChart(List<Map<String, dynamic>> requests) {
    final points = _chartPointsForRequests(requests);
    if (points.isEmpty || points.every((point) => point.value == 0)) {
      return _emptyChart('No service requests found for this period.');
    }
    final maxValue = points.fold<double>(
      0,
      (maximum, point) => math.max(maximum, point.value),
    );
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 100,
      points.length * 32.0,
    );
    return SizedBox(
      height: 180,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final height = point.value / maxValue * 130;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${point.value.toInt()}',
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: math.max(height, 2),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        point.label,
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _emptyChart(String message) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRequestOutcomesChart(List<Map<String, dynamic>> requests) {
    final points = _requestOutcomeTrendPoints(requests);
    if (points.every(
      (point) =>
          point.approved == 0 && point.corrections == 0 && point.rejected == 0,
    )) {
      return _emptyChart(
        'No approved, rejected, or correction-needed requests found for this period.',
      );
    }

    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 112,
      points.length * 36.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _buildLegendItem('Approved', Colors.green),
            _buildLegendItem('Needs corrections', Colors.orange),
            _buildLegendItem('Rejected', Colors.redAccent),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: CustomPaint(
                painter: _VerificationTrendPainter(
                  points: points,
                  textColor: context.mutedTextColor,
                ),
                size: Size(chartWidth, 190),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildProductionTable(
    List<Map<String, dynamic>> machines,
    Map<String, _MachineTotals> batchTotals,
  ) {
    if (machines.isEmpty) {
      return _emptyChart('No equipment is registered.');
    }
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildTableRow('Machine', 'In / Out sacks', 'Status', isHeader: true),
          const Divider(height: 1),
          ...machines.map((machine) {
            final machineId = _text(machine['machine_id']);
            final totals = batchTotals[machineId] ?? const _MachineTotals();
            return _buildTableRow(
              _text(machine['machine_name'], fallback: 'Unknown'),
              '${_formatNumber(totals.input)} / ${_formatNumber(totals.output)}',
              _text(machine['status'], fallback: 'Unknown'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    String machine,
    String production,
    String status, {
    bool isHeader = false,
  }) {
    final textStyle = TextStyle(
      color: isHeader ? kGold : context.textColor,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontSize: isHeader ? 11 : 12,
    );
    final statusColor = switch (status.toLowerCase()) {
      'available' => Colors.green,
      'in_use' => Colors.blue,
      'maintenance' || 'inactive' || 'emergency_stop' => Colors.redAccent,
      _ => context.mutedTextColor,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              machine,
              style: textStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              production,
              style: TextStyle(
                color: isHeader ? kGold : context.mutedTextColor,
                fontSize: isHeader ? 11 : 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: isHeader
                  ? Text(status, style: textStyle, textAlign: TextAlign.right)
                  : Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kGold, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: context.textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              message,
              style: TextStyle(color: context.mutedTextColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            action,
          ],
        ),
      ),
    );
  }

  List<_ChartPoint> _chartPoints(List<Map<String, dynamic>> batches) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_selectedRange) {
      case _ReportRange.today:
        final values = List<double>.filled(24, 0);
        for (final batch in batches) {
          final date = _parseDate(batch['created_at']);
          if (date != null && _sameDate(date, today)) {
            values[date.hour] += _number(batch['output_sacks']);
          }
        }
        return List.generate(
          24,
          (hour) => _ChartPoint(
            '${hour.toString().padLeft(2, '0')}:00',
            values[hour],
          ),
        );
      case _ReportRange.week:
        final values = List<double>.filled(7, 0);
        for (final batch in batches) {
          final date = _parseDate(batch['created_at']);
          if (date != null) {
            final index = date.weekday - 1;
            if (index >= 0 && index < values.length) {
              values[index] += _number(batch['output_sacks']);
            }
          }
        }
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return List.generate(
          7,
          (index) => _ChartPoint(labels[index], values[index]),
        );
      case _ReportRange.month:
        final dayCount = DateTime(now.year, now.month + 1, 0).day;
        final values = List<double>.filled(dayCount, 0);
        for (final batch in batches) {
          final date = _parseDate(batch['created_at']);
          if (date != null &&
              date.year == now.year &&
              date.month == now.month) {
            values[date.day - 1] += _number(batch['output_sacks']);
          }
        }
        return List.generate(
          dayCount,
          (index) => _ChartPoint('${index + 1}', values[index]),
        );
      case _ReportRange.year:
        final values = List<double>.filled(12, 0);
        for (final batch in batches) {
          final date = _parseDate(batch['created_at']);
          if (date != null && date.year == now.year) {
            values[date.month - 1] += _number(batch['output_sacks']);
          }
        }
        const labels = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return List.generate(
          12,
          (index) => _ChartPoint(labels[index], values[index]),
        );
    }
  }

  List<_ChartPoint> _chartPointsForRequests(
    List<Map<String, dynamic>> requests,
  ) {
    final now = DateTime.now();
    late final List<String> labels;
    late final List<double> values;
    switch (_selectedRange) {
      case _ReportRange.today:
        return [_ChartPoint('Today', requests.length.toDouble())];
      case _ReportRange.week:
        labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        values = List<double>.filled(7, 0);
        for (final request in requests) {
          final date = _parseDate(request['request_date']);
          if (date != null) values[date.weekday - 1]++;
        }
      case _ReportRange.month:
        final days = DateTime(now.year, now.month + 1, 0).day;
        labels = List.generate(days, (index) => '${index + 1}');
        values = List<double>.filled(days, 0);
        for (final request in requests) {
          final date = _parseDate(request['request_date']);
          if (date != null &&
              date.year == now.year &&
              date.month == now.month) {
            values[date.day - 1]++;
          }
        }
      case _ReportRange.year:
        labels = const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        values = List<double>.filled(12, 0);
        for (final request in requests) {
          final date = _parseDate(request['request_date']);
          if (date != null && date.year == now.year) values[date.month - 1]++;
        }
    }
    return List.generate(
      labels.length,
      (index) => _ChartPoint(labels[index], values[index]),
    );
  }

  List<_VerificationTrendPoint> _requestOutcomeTrendPoints(
    List<Map<String, dynamic>> requests,
  ) {
    final now = DateTime.now();
    final dailyCounts = switch (_selectedRange) {
      _ReportRange.today => 1,
      _ReportRange.week => 7,
      _ReportRange.month => DateTime(now.year, now.month + 1, 0).day,
      _ReportRange.year => 12,
    };
    final labels = switch (_selectedRange) {
      _ReportRange.today => const ['Today'],
      _ReportRange.week => const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ],
      _ReportRange.month => List.generate(
        dailyCounts,
        (index) => index == 0 || (index + 1) % 5 == 0 ? '${index + 1}' : '',
      ),
      _ReportRange.year => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ],
    };
    final approved = List.generate(dailyCounts, (_) => <String>{});
    final corrections = List.generate(dailyCounts, (_) => <String>{});
    final rejected = List.generate(dailyCounts, (_) => <String>{});

    for (final request in requests) {
      final requestId = _text(request['service_request_id']);
      final index = _trendIndex(request['request_date'], now);
      if (requestId.isEmpty || index == null) continue;

      final status = _text(request['status']).toLowerCase();
      if (status == 'returnedtominer') {
        corrections[index].add(requestId);
      } else if (status == 'cancelled') {
        rejected[index].add(requestId);
      } else if (const {
        'accepted',
        'verified',
        'queued',
        'scheduled',
        'assigned',
        'processing',
        'processingcompleted',
        'goldhandoff',
        'partiallypaid',
        'completed',
      }.contains(status)) {
        approved[index].add(requestId);
      }
    }

    return List.generate(
      dailyCounts,
      (index) => _VerificationTrendPoint(
        label: labels[index],
        approved: approved[index].length,
        corrections: corrections[index].length,
        rejected: rejected[index].length,
      ),
    );
  }

  int? _trendIndex(dynamic value, DateTime now) {
    final date = _parseDate(value);
    if (date == null) return null;
    switch (_selectedRange) {
      case _ReportRange.today:
        return _sameDate(date, now) ? 0 : null;
      case _ReportRange.week:
        return date.weekday - 1;
      case _ReportRange.month:
        if (date.year != now.year || date.month != now.month) return null;
        return date.day - 1;
      case _ReportRange.year:
        if (date.year != now.year) return null;
        return date.month - 1;
    }
  }

  Map<String, _MachineTotals> _batchTotals(List<Map<String, dynamic>> batches) {
    final totals = <String, _MachineTotals>{};
    for (final batch in batches) {
      final machineId = _text(batch['machine_id']);
      final current = totals[machineId] ?? const _MachineTotals();
      totals[machineId] = _MachineTotals(
        input: current.input + _number(batch['input_sacks']),
        output: current.output + _number(batch['output_sacks']),
      );
    }
    return totals;
  }

  String _rangeDescription() {
    final now = DateTime.now();
    final start = switch (_selectedRange) {
      _ReportRange.today => DateTime(now.year, now.month, now.day),
      _ReportRange.week => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
      _ReportRange.month => DateTime(now.year, now.month),
      _ReportRange.year => DateTime(now.year),
    };
    return '${DateFormat.yMMMd().format(start)} – ${DateFormat.yMMMd().format(now)}';
  }

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  DateTime? _parseDate(dynamic value) {
    final parsed = DateTime.tryParse(_text(value));
    return parsed?.toLocal();
  }

  String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  bool _isRenderedService(Map<String, dynamic> request) {
    return const {
      'processingcompleted',
      'goldhandoff',
      'completed',
    }.contains(_text(request['status']).toLowerCase());
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatNumber(double value) => NumberFormat('#,##0.##').format(value);

  String _formatCurrency(double value) =>
      NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(value);
}

class _ChartPoint {
  const _ChartPoint(this.label, this.value);

  final String label;
  final double value;
}

class _MachineTotals {
  const _MachineTotals({this.input = 0, this.output = 0});

  final double input;
  final double output;
}

class _VerificationTrendPoint {
  const _VerificationTrendPoint({
    required this.label,
    required this.approved,
    required this.corrections,
    required this.rejected,
  });

  final String label;
  final int approved;
  final int corrections;
  final int rejected;
}

class _VerificationTrendPainter extends CustomPainter {
  const _VerificationTrendPainter({
    required this.points,
    required this.textColor,
  });

  final List<_VerificationTrendPoint> points;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 30.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 30.0;
    final plotWidth = math.max(0, size.width - left - right);
    final plotHeight = math.max(0, size.height - top - bottom);
    final maxValue = points.fold<int>(
      0,
      (maximum, point) => math.max(
        maximum,
        math.max(point.approved, math.max(point.corrections, point.rejected)),
      ),
    );
    final scaleMax = math.max(maxValue, 1);
    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    for (var tick = 0; tick <= 3; tick++) {
      final y = top + plotHeight * tick / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      final value = (scaleMax * (3 - tick) / 3).round();
      _drawText(
        canvas,
        '$value',
        Offset(0, y - 7),
        textColor,
        fontSize: 9,
        width: left - 5,
        align: TextAlign.right,
      );
    }

    double xFor(int index) => points.length == 1
        ? left + plotWidth / 2
        : left + plotWidth * index / (points.length - 1);

    double yFor(int value) => top + plotHeight * (1 - value / scaleMax);
    final series =
        <({Color color, int Function(_VerificationTrendPoint) value})>[
          (color: Colors.green, value: (point) => point.approved),
          (color: Colors.orange, value: (point) => point.corrections),
          (color: Colors.redAccent, value: (point) => point.rejected),
        ];

    for (final line in series) {
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final offset = Offset(xFor(index), yFor(line.value(points[index])));
        if (index == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var index = 0; index < points.length; index++) {
        canvas.drawCircle(
          Offset(xFor(index), yFor(line.value(points[index]))),
          3,
          Paint()..color = line.color,
        );
      }
    }

    for (var index = 0; index < points.length; index++) {
      if (points[index].label.isEmpty) continue;
      _drawText(
        canvas,
        points[index].label,
        Offset(xFor(index) - 20, size.height - bottom + 7),
        textColor,
        fontSize: 9,
        width: 40,
        align: TextAlign.center,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    required double fontSize,
    required double width,
    required TextAlign align,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _VerificationTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.textColor != textColor;
}
