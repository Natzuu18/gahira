import '../supabase/supabase_config.dart';

class AdminReportData {
  const AdminReportData({
    required this.serviceRequests,
    required this.millingBatches,
    required this.machines,
    required this.participantPayments,
    required this.serviceRequestPayments,
  });

  final List<Map<String, dynamic>> serviceRequests;
  final List<Map<String, dynamic>> millingBatches;
  final List<Map<String, dynamic>> machines;
  final List<Map<String, dynamic>> participantPayments;
  final List<Map<String, dynamic>> serviceRequestPayments;
}

class SupabaseReportRepository {
  static const _pageSize = 1000;

  Future<AdminReportData> getReportData({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final client = SupabaseConfig.client;
    final startDate = _dateOnly(start);
    final endDate = _dateOnly(endExclusive);

    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchAll(
        (from, to) => client
            .from('service_requests')
            .select(
              'service_request_id, request_date, created_at, status, '
              'material_weight, actual_weight, gold_weight_grams',
            )
            .gte('request_date', startDate)
            .lt('request_date', endDate)
            .order('request_date')
            .order('service_request_id')
            .range(from, to),
      ),
      _fetchAll(
        (from, to) => client
            .from('milling_batches')
            .select(
              'batch_id, machine_id, created_at, input_sacks, output_sacks, status',
            )
            .eq('status', 'completed')
            .gte('created_at', start.toIso8601String())
            .lt('created_at', endExclusive.toIso8601String())
            .order('created_at')
            .order('batch_id')
            .range(from, to),
      ),
      _fetchAll(
        (from, to) => client
            .from('machines')
            .select('machine_id, machine_name, machine_type, status')
            .order('machine_name')
            .range(from, to),
      ),
      _fetchAll(
        (from, to) => client
            .from('participant_payments')
            .select('payment_id, amount, payment_date')
            .gte('payment_date', start.toIso8601String())
            .lt('payment_date', endExclusive.toIso8601String())
            .order('payment_date')
            .order('payment_id')
            .range(from, to),
      ),
      _fetchAll(
        (from, to) => client
            .from('service_requests')
            .select('service_request_id, payment_amount, payment_date')
            .gt('payment_amount', 0)
            .gte('payment_date', start.toIso8601String())
            .lt('payment_date', endExclusive.toIso8601String())
            .order('payment_date')
            .order('service_request_id')
            .range(from, to),
      ),
    ]);

    return AdminReportData(
      serviceRequests: results[0],
      millingBatches: results[1],
      machines: results[2],
      participantPayments: results[3],
      serviceRequestPayments: results[4],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAll(
    Future<dynamic> Function(int from, int to) fetchPage,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = _mapRows(await fetchPage(offset, offset + _pageSize - 1));
      rows.addAll(page);
      if (page.length < _pageSize) return rows;
      offset += page.length;
    }
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }
}
