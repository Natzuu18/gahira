import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  late final ServiceRequestService _service;

  List<ServiceRequestEntity> _requests = [];
  List<UserEntity> _allUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    final usersRes = await _userRepository.getAllUsers();

    setState(() {
      _requests = result
          .getOrElse(() => [])
          .where(
            (r) =>
                r.status == ServiceRequestStatus.processingCompleted ||
                r.status == ServiceRequestStatus.goldHandoff ||
                r.status == ServiceRequestStatus.partiallyPaid ||
                r.status == ServiceRequestStatus.completed,
          )
          .toList();
      _allUsers = usersRes.getOrElse(() => []);
      _isLoading = false;
    });
  }

  String _getUserName(String id) {
    UserEntity? user;
    for (final u in _allUsers) {
      if (u.userId == id) {
        user = u;
        break;
      }
    }
    return user != null ? '${user.fname} ${user.lname}' : 'Unknown Miner';
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests
        .where((r) => r.status != ServiceRequestStatus.completed)
        .toList();
    final completed = _requests
        .where((r) => r.status == ServiceRequestStatus.completed)
        .toList();

    return DefaultTabController(
      length: 3,
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
            'FINANCIAL HANDLING',
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
          bottom: TabBar(
            labelColor: kGold,
            unselectedLabelColor: context.mutedTextColor,
            indicatorColor: kGold,
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'Completed (${completed.length})'),
              const Tab(text: 'Gold Transactions'),
            ],
          ),
        ),
        endDrawer: const AdminDrawer(currentMenu: AdminMenu.bills),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : TabBarView(
                children: [
                  _buildList(pending, isPending: true),
                  _buildList(completed, isPending: false),
                  _buildGoldTransactionsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildGoldTransactionsTab() {
    final goldRequests = _requests
        .where((r) => (r.financialDetails?.goldPurchaseValue ?? 0) > 0)
        .toList();

    if (goldRequests.isEmpty) {
      return Center(
        child: Text(
          'No gold transactions recorded.',
          style: TextStyle(color: context.mutedTextColor),
        ),
      );
    }

    double totalGoldValue = goldRequests.fold(
      0,
      (sum, r) => sum + (r.financialDetails?.goldPurchaseValue ?? 0),
    );
    double totalWeight = goldRequests.fold(
      0,
      (sum, r) => sum + (r.financialDetails?.goldWeightGrams ?? 0),
    );

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGoldSummaryHeader(totalGoldValue, totalWeight),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_searchQuery.isNotEmpty)
                Text(
                  '${_filteredGoldRequests(goldRequests).length} results',
                  style: const TextStyle(color: kGold, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filteredGoldRequests(goldRequests).isEmpty)
            _buildEmptyState()
          else
            ..._filteredGoldRequests(
              goldRequests,
            ).map((r) => _buildGoldTransactionCard(r)),
        ],
      ),
    );
  }

  List<ServiceRequestEntity> _filteredGoldRequests(
    List<ServiceRequestEntity> goldRequests,
  ) {
    if (_searchQuery.isEmpty) return goldRequests;
    return goldRequests
        .where(
          (r) =>
              (r.creatorName ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              r.id.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      style: TextStyle(color: context.textColor),
      decoration: InputDecoration(
        hintText: 'Search by Miner name or Ref ID...',
        hintStyle: TextStyle(color: context.mutedTextColor.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.search, color: kGold, size: 20),
        filled: true,
        fillColor: context.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.no_accounts_rounded,
            size: 48,
            color: context.mutedTextColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No gold transactions found.',
            style: TextStyle(color: context.mutedTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldSummaryHeader(double totalValue, double totalWeight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kGold.withOpacity(0.2), kGold.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Total Gold Purchased',
            style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'P ${NumberFormat("#,##0.00").format(totalValue)}',
            style: TextStyle(
              color: context.textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Weight: ${totalWeight.toStringAsFixed(2)} grams',
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldTransactionCard(ServiceRequestEntity request) {
    final fd = request.financialDetails;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.creatorName ?? 'Miner',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(request.createdAt),
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Text(
                'P ${NumberFormat("#,##0.00").format(fd?.goldPurchaseValue ?? 0)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStatCard('Weight', '${fd?.goldWeightGrams ?? 0}g'),
              _buildMiniStatCard('Price/g', 'P ${fd?.goldBuyingPrice ?? 0}'),
              _buildMiniStatCard(
                'Ref',
                request.id.substring(0, 5).toUpperCase(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    List<ServiceRequestEntity> list, {
    required bool isPending,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isPending
              ? 'No pending billing tasks.'
              : 'No completed transactions.',
          style: TextStyle(color: context.mutedTextColor),
        ),
      );
    }

    double totalProcessedSacks = list.fold(
      0,
      (sum, r) => sum + (r.materialDetails.numberOfSacks ?? 0),
    );
    double totalRevenue = isPending
        ? 0
        : list.fold(0, (sum, r) => sum + (r.financialDetails?.totalBill ?? 0));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isPending) ...[
            _buildFinancialOverviewHeader(totalProcessedSacks, totalRevenue),
            const SizedBox(height: 16),
          ],
          ...list.map(
            (request) => _buildRequestCard(request, isPending: isPending),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverviewHeader(double sacks, double revenue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildHeaderStat(
            'Sacks Processed',
            sacks.toInt().toString(),
            Icons.inventory_2_rounded,
          ),
          Container(
            width: 1,
            height: 40,
            color: kGold.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 14),
          ),
          _buildHeaderStat(
            'Total Billings',
            'P ${NumberFormat("#,##0").format(revenue)}',
            Icons.payments_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kGold, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    ServiceRequestEntity request, {
    required bool isPending,
  }) {
    final bool isGroup = request.participatingMinerIds.length > 1;
    final bool isReadyForBilling =
        request.status == ServiceRequestStatus.processingCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReadyForBilling ? kGold : kGold.withOpacity(0.1),
          width: isReadyForBilling ? 2 : 1,
        ),
        boxShadow: isReadyForBilling
            ? [
                BoxShadow(
                  color: kGold.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReadyForBilling)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: kGold,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'READY FOR FINANCIAL HANDLING',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kBlack,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SR-${request.id.substring(0, 5).toUpperCase()}',
                        style: const TextStyle(
                          color: kGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isGroup
                            ? 'Korpo (Group)'
                            : (request.creatorName ?? 'Individual Miner'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _buildStatusChip(request.status),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Material',
                  request.materialDetails.sourceType ?? 'Gold Ore',
                ),
                _buildSummaryRow(
                  'Sacks',
                  '${request.materialDetails.numberOfSacks ?? 0}',
                ),
                if (isGroup)
                  _buildSummaryRow(
                    'Participants',
                    '${request.participatingMinerIds.length}',
                  ),
                if (request.status == ServiceRequestStatus.completed)
                  _buildSummaryRow(
                    'Total Bill',
                    'P ${NumberFormat("#,##0.00").format(request.financialDetails?.totalBill ?? 0)}',
                    isBold: true,
                  ),
              ],
            ),
          ),
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ElevatedButton(
                onPressed: () => _startFinancialWorkflow(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReadyForBilling
                      ? kGold
                      : kGold.withOpacity(0.5),
                  foregroundColor: kBlack,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  request.status == ServiceRequestStatus.goldHandoff
                      ? 'Record Payment'
                      : 'Financial Handling',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ServiceRequestStatus status) {
    Color color = Colors.orange;
    if (status == ServiceRequestStatus.completed) color = Colors.green;
    if (status == ServiceRequestStatus.processingCompleted) color = Colors.blue;
    if (status == ServiceRequestStatus.partiallyPaid) color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _startFinancialWorkflow(ServiceRequestEntity request) {
    if (request.status == ServiceRequestStatus.goldHandoff) {
      _showPaymentChoiceStep(request);
    } else {
      _showFinancialChoiceStep(request);
    }
  }

  void _showFinancialChoiceStep(ServiceRequestEntity request) {
    final bool isGroup = request.participatingMinerIds.length > 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: Map<String, dynamic>.from({}).isEmpty
              ? MainAxisSize.min
              : MainAxisSize.max,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Financial Handling',
              style: const TextStyle(
                color: kGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isGroup ? 'Korpo (Group)' : (request.creatorName ?? 'Miner'),
              style: TextStyle(color: context.textColor, fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildProcessingSummary(request),
            const SizedBox(height: 20),
            _buildWorkflowOption(
              icon: Icons.auto_awesome,
              title: 'Gold Buying (Optional)',
              subtitle:
                  'Record the recovered gold details and set the buying price.',
              onTap: () {
                Navigator.pop(context);
                _showGoldBuyingStep(request);
              },
            ),
            const SizedBox(height: 16),
            const Text('Or', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _buildWorkflowOption(
              icon: Icons.receipt_long,
              title: 'Skip Gold Buying',
              subtitle:
                  'Proceed directly to billing without purchasing the gold.',
              onTap: () {
                Navigator.pop(context);
                _showBillingStep(request, isGoldBought: false);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingSummary(ServiceRequestEntity request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Processing Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildStageItem('Request & Review', true),
          _buildStageItem('Loading', true),
          _buildStageItem('Milling / Crushing', true),
          _buildStageItem('Unloading', true),
          _buildStageItem('Washing / Separation', true),
          _buildStageItem('Refining', true),
        ],
      ),
    );
  }

  Widget _buildStageItem(String label, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isCompleted ? context.textColor : context.mutedTextColor,
            ),
          ),
          const Spacer(),
          if (isCompleted)
            Text(
              'Completed',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkflowOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kGold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showGoldBuyingStep(ServiceRequestEntity request) {
    double goldWeight = 0;
    double buyingPrice = 4000;
    bool deductFromGold = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double goldValue = goldWeight * buyingPrice;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gold Buying',
                        style: TextStyle(
                          color: kGold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'STEP 1/2',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInputLabel('Gold Weight (grams)'),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      suffixText: 'grams',
                    ),
                    onChanged: (v) => setModalState(
                      () => goldWeight = double.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInputLabel('Buying Price (per gram)'),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      prefixText: 'P ',
                      hintText: '4,000.00',
                    ),
                    onChanged: (v) => setModalState(
                      () => buyingPrice = double.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Gold Purchase Value',
                          style: TextStyle(
                            color: context.mutedTextColor,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'P ${NumberFormat("#,##0.00").format(goldValue)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text(
                      'Deduct Billing from Gold Purchase',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'The billing amount will be deducted from the gold purchase value.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: deductFromGold,
                    activeColor: kGold,
                    onChanged: (v) => setModalState(() => deductFromGold = v!),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: goldWeight > 0
                        ? () {
                            Navigator.pop(context);
                            _showBillingStep(
                              request,
                              isGoldBought: true,
                              goldWeight: goldWeight,
                              buyingPrice: buyingPrice,
                              goldValue: goldValue,
                              deductFromGold: deductFromGold,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue to Billing',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBillingStep(
    ServiceRequestEntity request, {
    required bool isGoldBought,
    double? goldWeight,
    double? buyingPrice,
    double? goldValue,
    bool deductFromGold = false,
  }) {
    final bool isGroup = request.participatingMinerIds.length > 1;
    double processingFee = (request.materialDetails.numberOfSacks ?? 0) * 150.0;

    // Dynamic expenses list
    List<Map<String, dynamic>> extraExpenses = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double otherExpenses = extraExpenses.fold(
            0,
            (sum, item) => sum + (item['amount'] as double? ?? 0),
          );
          double totalBill = processingFee + otherExpenses;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Billing',
                        style: TextStyle(
                          color: kGold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'STEP 2/2',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Expenses',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildBillingInput(
                    'Processing Fee',
                    processingFee,
                    (v) => setModalState(
                      () => processingFee = double.tryParse(v) ?? 0,
                    ),
                  ),
                  ...extraExpenses.asMap().entries.map((entry) {
                    int idx = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.value['name'])),
                          Text('P ${entry.value['amount']}'),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => setModalState(
                              () => extraExpenses.removeAt(idx),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  TextButton.icon(
                    onPressed: () => _showAddExpenseDialog(
                      (name, amt) => setModalState(
                        () => extraExpenses.add({'name': name, 'amount': amt}),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Expense',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bill',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'P ${NumberFormat("#,##0.00").format(totalBill)}',
                        style: const TextStyle(
                          color: kGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (isGroup) {
                        _showIndividualExpensesStep(
                          request,
                          isGoldBought: isGoldBought,
                          goldWeight: goldWeight,
                          buyingPrice: buyingPrice,
                          goldValue: goldValue,
                          deductFromGold: deductFromGold,
                          processingFee: processingFee,
                          otherExpenses: otherExpenses,
                          totalBill: totalBill,
                          extraExpenses: extraExpenses,
                        );
                      } else {
                        _showBillingSummary(
                          request,
                          isGoldBought: isGoldBought,
                          goldWeight: goldWeight,
                          buyingPrice: buyingPrice,
                          goldValue: goldValue,
                          deductFromGold: deductFromGold,
                          processingFee: processingFee,
                          otherExpenses: otherExpenses,
                          totalBill: totalBill,
                          individualExpenses: {},
                          individualExpenseReasons: {},
                          extraExpenses: extraExpenses,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isGroup
                          ? 'Next: Individual Expenses'
                          : 'Settlement Summary',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showIndividualExpensesStep(
    ServiceRequestEntity request, {
    required bool isGoldBought,
    double? goldWeight,
    double? buyingPrice,
    double? goldValue,
    bool deductFromGold = false,
    required double processingFee,
    required double otherExpenses,
    required double totalBill,
    required List<Map<String, dynamic>> extraExpenses,
  }) {
    final indExpenses = {for (var id in request.participatingMinerIds) id: 0.0};
    final indExpenseReasons = {
      for (var id in request.participatingMinerIds) id: '',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Individual Expenses',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add a reason for every expense so each miner understands the charge.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ...request.participatingMinerIds.map(
                  (id) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: kGold.withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            color: kGold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getUserName(id),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  prefixText: 'P ',
                                  hintText: 'Individual expense',
                                  isDense: true,
                                ),
                                onChanged: (v) => setModalState(
                                  () =>
                                      indExpenses[id] = double.tryParse(v) ?? 0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Reason for this expense',
                                  isDense: true,
                                ),
                                onChanged: (v) => indExpenseReasons[id] = v,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    final missingReasons = request.participatingMinerIds.any(
                      (id) =>
                          (indExpenses[id] ?? 0) > 0 &&
                          (indExpenseReasons[id] ?? '').trim().isEmpty,
                    );
                    if (missingReasons) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Add a reason for every individual expense.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _showBillingSummary(
                      request,
                      isGoldBought: isGoldBought,
                      goldWeight: goldWeight,
                      buyingPrice: buyingPrice,
                      goldValue: goldValue,
                      deductFromGold: deductFromGold,
                      processingFee: processingFee,
                      otherExpenses: otherExpenses,
                      totalBill: totalBill,
                      individualExpenses: indExpenses,
                      individualExpenseReasons: indExpenseReasons,
                      extraExpenses: extraExpenses,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kBlack,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next: Summary',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBillingSummary(
    ServiceRequestEntity request, {
    required bool isGoldBought,
    double? goldWeight,
    double? buyingPrice,
    double? goldValue,
    bool deductFromGold = false,
    required double processingFee,
    required double otherExpenses,
    required double totalBill,
    required Map<String, double> individualExpenses,
    required Map<String, String> individualExpenseReasons,
    required List<Map<String, dynamic>> extraExpenses,
  }) {
    double baseShare =
        totalBill /
        (request.participatingMinerIds.isEmpty
            ? 1
            : request.participatingMinerIds.length);
    List<ParticipantFinancial> breakdown = request.participatingMinerIds.map((
      id,
    ) {
      double totalDue = baseShare + (individualExpenses[id] ?? 0);
      return ParticipantFinancial(
        userId: id,
        userName: _getUserName(id),
        shareAmount: baseShare,
        individualExpenses: individualExpenses[id] ?? 0,
        individualExpenseReason:
            individualExpenseReasons[id]?.trim().isEmpty == true
            ? null
            : individualExpenseReasons[id]?.trim(),
        totalDue: totalDue,
        amountPaid: 0,
        status: 'unpaid',
      );
    }).toList();

    double netSettlement = isGoldBought
        ? (deductFromGold ? (goldValue! - totalBill) : goldValue!)
        : -totalBill;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settlement Summary',
              style: TextStyle(
                color: kGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (isGoldBought) ...[
                    _buildSummaryRow(
                      'Gold Purchase (${goldWeight}g @ P${buyingPrice})',
                      'P ${NumberFormat("#,##0.00").format(goldValue!)}',
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildSummaryRow(
                    'Total Processing Bill',
                    'P ${NumberFormat("#,##0.00").format(totalBill)}',
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        netSettlement >= 0
                            ? 'Refinery Pays Miner'
                            : 'Miner Pays Refinery',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: netSettlement >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        'P ${NumberFormat("#,##0.00").format(netSettlement.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: netSettlement >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (breakdown.isNotEmpty) ...[
              const Text(
                'Participant Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: kGold,
                ),
              ),
              const SizedBox(height: 12),
              ...breakdown
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.userName ?? 'Miner',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (p.individualExpenses > 0 &&
                                    p.individualExpenseReason != null)
                                  Text(
                                    'Individual expense: ${p.individualExpenseReason}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            'P ${NumberFormat("#,##0.00").format(p.totalDue)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final currentUserId =
                    Supabase.instance.client.auth.currentUser?.id;
                if (currentUserId == null) return;

                final result = await _service.submitFinancialHandling(
                  requestId: request.id,
                  ownerId: currentUserId,
                  goldWeight: goldWeight,
                  buyingPrice: buyingPrice,
                  goldValue: goldValue,
                  deductBillFromGold: deductFromGold,
                  processingFee: processingFee,
                  otherExpenses: otherExpenses,
                  totalBill: totalBill,
                  amountToMiner: isGoldBought
                      ? (goldValue! - (deductFromGold ? totalBill : 0))
                      : 0,
                  currentStatus: request.status.name,
                  participantBreakdown: breakdown,
                  billingItems: [
                    {
                      'name': 'Processing Fee',
                      'amount': processingFee,
                      'category': 'processing',
                    },
                    ...extraExpenses,
                  ],
                );

                Navigator.pop(context);
                result.fold(
                  (l) => ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l.message))),
                  (_) {
                    _loadData();
                    _showPaymentChoiceStep(request);
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm & Record Settlement',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentChoiceStep(ServiceRequestEntity request) {
    final bool isGroup = request.participatingMinerIds.length > 1;

    if (!isGroup) {
      _showPaymentStep(request);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Payment Method',
              style: TextStyle(
                color: kGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            _buildWorkflowOption(
              icon: Icons.groups_rounded,
              title: 'Payment for All Participants',
              subtitle: 'Upload a single receipt for the entire group.',
              onTap: () {
                Navigator.pop(context);
                _showPaymentStep(request);
              },
            ),
            const SizedBox(height: 16),
            _buildWorkflowOption(
              icon: Icons.person_search_rounded,
              title: 'Manual Payment (per participant)',
              subtitle:
                  'Select and record payments for each member individually.',
              onTap: () {
                Navigator.pop(context);
                _showParticipantListStep(request);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showParticipantListStep(ServiceRequestEntity request) async {
    // re-fetch to get financials
    final latestRes = await _repository.getServiceRequests();
    final latestReq = latestRes.fold(
      (_) => request,
      (list) => list.firstWhere((element) => element.id == request.id),
    );
    final breakdown = latestReq.financialDetails?.participantBreakdown ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Participant',
              style: TextStyle(
                color: kGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ...breakdown
                .map(
                  (p) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kGold.withOpacity(0.1),
                      child: const Icon(Icons.person, color: kGold),
                    ),
                    title: Text(p.userName ?? 'Miner'),
                    subtitle: Text(
                      'Balance: P ${NumberFormat("#,##0.00").format(p.totalDue - p.amountPaid)}',
                    ),
                    trailing: _buildSmallStatusChip(p.status),
                    onTap: () {
                      Navigator.pop(context);
                      _showIndividualPaymentStep(request, p);
                    },
                  ),
                )
                .toList(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'paid') color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showIndividualPaymentStep(
    ServiceRequestEntity request,
    ParticipantFinancial p,
  ) {
    double totalDue = p.totalDue - p.amountPaid;
    double amountPaidInput = totalDue;
    PlatformFile? selectedReceipt;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.userName ?? 'Miner',
                    style: const TextStyle(
                      color: kGold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Payment method: CASH ONLY',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    'Total Due',
                    'P ${NumberFormat("#,##0.00").format(totalDue)}',
                  ),
                  const Divider(height: 32),
                  _buildInputLabel('Current Payment (Cash)'),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixText: 'P ',
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    controller: TextEditingController(
                      text: amountPaidInput.toString(),
                    ),
                    onChanged: (v) => setModalState(
                      () => amountPaidInput = double.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Upload Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null) {
                        setModalState(
                          () => selectedReceipt = result.files.first,
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReceipt != null
                              ? kGold
                              : Colors.grey.withOpacity(0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            selectedReceipt != null
                                ? Icons.check_circle
                                : Icons.cloud_upload_outlined,
                            color: selectedReceipt != null
                                ? Colors.green
                                : kGold.withOpacity(0.7),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedReceipt != null
                                ? selectedReceipt!.name
                                : 'Tap to upload receipt (Image)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedReceipt != null
                                  ? context.textColor
                                  : context.mutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      final currentUserId =
                          Supabase.instance.client.auth.currentUser?.id;
                      if (currentUserId == null) return;

                      String? receiptUrl;
                      if (selectedReceipt != null) {
                        final uploadRes = await _repository.uploadRequestPhotos(
                          [selectedReceipt!],
                        );
                        uploadRes.fold(
                          (_) => null,
                          (urls) => receiptUrl = urls.first,
                        );
                      }

                      final result = await _service.recordIndividualPayment(
                        requestId: request.id,
                        ownerId: currentUserId,
                        participantId: p.userId,
                        paymentAmount: amountPaidInput,
                        remainingBalance: totalDue - amountPaidInput,
                        receiptUrl: receiptUrl,
                        currentStatus: request.status.name,
                      );

                      Navigator.pop(context);
                      result.fold(
                        (l) => ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.message))),
                        (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Participant payment recorded!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm Payment',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentStep(ServiceRequestEntity request) async {
    final latestRes = await _repository.getServiceRequests();
    final latestReq = latestRes.fold(
      (_) => request,
      (list) => list.firstWhere((element) => element.id == request.id),
    );

    double totalBill = latestReq.financialDetails?.totalBill ?? 0;
    double amountPaidRecord = totalBill;
    DateTime paymentDate = DateTime.now();
    PlatformFile? selectedReceipt;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double remaining = totalBill - amountPaidRecord;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Record Payment',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Payment method: CASH ONLY',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    'Total Bill',
                    'P ${NumberFormat("#,##0.00").format(totalBill)}',
                  ),
                  const Divider(height: 32),
                  _buildInputLabel('Current Payment (Cash)'),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixText: 'P ',
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setModalState(
                      () => amountPaidRecord = double.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Remaining Balance',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        'P ${NumberFormat("#,##0.00").format(remaining)}',
                        style: TextStyle(
                          color: remaining > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Upload Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null) {
                        setModalState(
                          () => selectedReceipt = result.files.first,
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReceipt != null
                              ? kGold
                              : Colors.grey.withOpacity(0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            selectedReceipt != null
                                ? Icons.check_circle
                                : Icons.cloud_upload_outlined,
                            color: selectedReceipt != null
                                ? Colors.green
                                : kGold.withOpacity(0.7),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedReceipt != null
                                ? selectedReceipt!.name
                                : 'Tap to upload receipt (Image)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedReceipt != null
                                  ? context.textColor
                                  : context.mutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInputLabel('Payment Date'),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null)
                        setModalState(() => paymentDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: kGold,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MMM dd, yyyy').format(paymentDate),
                            style: TextStyle(color: context.textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      final currentUserId =
                          Supabase.instance.client.auth.currentUser?.id;
                      if (currentUserId == null) return;

                      String? receiptUrl;
                      if (selectedReceipt != null) {
                        final uploadRes = await _repository.uploadRequestPhotos(
                          [selectedReceipt!],
                        );
                        uploadRes.fold(
                          (_) => null,
                          (urls) => receiptUrl = urls.first,
                        );
                      }

                      final result = await _service.recordPayment(
                        requestId: latestReq.id,
                        ownerId: currentUserId,
                        paymentAmount: amountPaidRecord,
                        remainingBalance: remaining,
                        receiptUrl: receiptUrl,
                        paymentDate: paymentDate,
                        currentStatus: latestReq.status.name,
                      );

                      Navigator.pop(context);
                      result.fold(
                        (l) => ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.message))),
                        (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment recorded successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm Payment',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddExpenseDialog(Function(String, double) onAdd) {
    String name = '';
    double amt = 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Add Other Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Expense Name'),
              onChanged: (v) => name = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Amount (PHP)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => amt = double.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onAdd(name, amt);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: context.mutedTextColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBillingInput(
    String label,
    double value,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                prefixText: 'P ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              controller: TextEditingController(text: value.toStringAsFixed(2)),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.mutedTextColor,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
