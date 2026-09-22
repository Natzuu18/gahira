import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();

  List<ServiceRequestEntity> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    setState(() {
      _requests = result.fold((l) => [], (r) => r);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final individualRequests = _requests
        .where(
          (r) =>
              r.participatingMinerIds.length <= 1 &&
              (r.financialDetails?.totalBill ?? 0) > 0,
        )
        .toList();
    final groupRequests = _requests
        .where(
          (r) =>
              r.participatingMinerIds.length > 1 &&
              (r.financialDetails?.totalBill ?? 0) > 0,
        )
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.surfaceColor,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: kGold),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            'MINER EXPENSES',
            style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 16,
            ),
          ),
          actions: [
            const ThemeToggleButton(),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: kGold),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: const TabBar(
            labelColor: kGold,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kGold,
            tabs: [
              Tab(text: 'INDIVIDUAL'),
              Tab(text: 'GROUP (KORPO)'),
            ],
          ),
        ),
        endDrawer: const AdminDrawer(currentMenu: AdminMenu.expenses),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : TabBarView(
                children: [
                  _buildExpensesList(individualRequests),
                  _buildExpensesList(groupRequests),
                ],
              ),
      ),
    );
  }

  Widget _buildExpensesList(List<ServiceRequestEntity> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No expenses found for this category.',
          style: TextStyle(color: context.mutedTextColor),
        ),
      );
    }

    double totalExpenses = list.fold(
      0,
      (sum, r) => sum + (r.financialDetails?.totalBill ?? 0),
    );

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTotalSummaryCard(totalExpenses),
          const SizedBox(height: 16),
          ...list.map((r) => _buildExpenseCard(r)),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard(double total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL CATEGORY EXPENSES',
            style: TextStyle(
              color: context.mutedTextColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'P ${NumberFormat("#,##0.00").format(total)}',
            style: TextStyle(
              color: context.textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(ServiceRequestEntity request) {
    final fd = request.financialDetails;
    final bool isGroup = request.participatingMinerIds.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGroup
                            ? 'Group Request'
                            : (request.creatorName ?? 'Miner'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'SR-${request.id.substring(0, 5).toUpperCase()}',
                        style: TextStyle(
                          color: kGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'P ${NumberFormat("#,##0.00").format(fd?.totalBill ?? 0)}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailItem(
              'Processing Fee',
              'P ${NumberFormat("#,##0").format(fd?.processingFee ?? 0)}',
            ),
            _buildDetailItem(
              'Other Expenses',
              'P ${NumberFormat("#,##0").format(fd?.otherExpenses ?? 0)}',
            ),
            if (isGroup && fd?.participantBreakdown != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Participant Individual Expenses:',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...fd!.participantBreakdown!
                  .where((p) => p.individualExpenses > 0)
                  .map(
                    (p) => _buildDetailItem(
                      '${p.userName ?? 'Miner'}${p.individualExpenseReason != null ? ' - ${p.individualExpenseReason}' : ''}',
                      'P ${NumberFormat("#,##0").format(p.individualExpenses)}',
                      isSub: true,
                    ),
                  ),
            ],
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(request.createdAt),
                  style: TextStyle(color: context.mutedTextColor, fontSize: 10),
                ),
                _buildStatusChip(request.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isSub = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: isSub ? 12 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.mutedTextColor, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ServiceRequestStatus status) {
    Color color = Colors.orange;
    if (status == ServiceRequestStatus.completed) color = Colors.green;
    if (status == ServiceRequestStatus.partiallyPaid) color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
