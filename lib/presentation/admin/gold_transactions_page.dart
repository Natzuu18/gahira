import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

class GoldTransactionsPage extends StatefulWidget {
  const GoldTransactionsPage({super.key});

  @override
  State<GoldTransactionsPage> createState() => _GoldTransactionsPageState();
}

class _GoldTransactionsPageState extends State<GoldTransactionsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();

  List<ServiceRequestEntity> _goldRequests = [];
  bool _isLoading = true;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    setState(() {
      _goldRequests = result.fold(
        (l) => [],
        (r) => r
            .where((req) => (req.financialDetails?.goldPurchaseValue ?? 0) > 0)
            .toList(),
      );
      // Sort by latest first
      _goldRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalGoldValue = _goldRequests.fold(
      0,
      (sum, r) => sum + (r.financialDetails?.goldPurchaseValue ?? 0),
    );
    double totalWeight = _goldRequests.fold(
      0,
      (sum, r) => sum + (r.financialDetails?.goldWeightGrams ?? 0),
    );

    return Scaffold(
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
          'GOLD TRANSACTIONS',
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
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.goldTransactions),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryHeader(totalGoldValue, totalWeight),
                  const SizedBox(height: 20),
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
                          '${_filteredRequests.length} results',
                          style: TextStyle(color: kGold, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_filteredRequests.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredRequests.map((r) => _buildTransactionCard(r)),
                ],
              ),
            ),
    );
  }

  List<ServiceRequestEntity> get _filteredRequests {
    if (_searchQuery.isEmpty) return _goldRequests;
    return _goldRequests
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

  Widget _buildSummaryHeader(double totalValue, double totalWeight) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildHeaderItem(
                  'Total Investment',
                  'P ${NumberFormat("#,##0").format(totalValue)}',
                  Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderItem(
                  'Total Grams',
                  '${totalWeight.toStringAsFixed(2)}g',
                  Icons.monitor_weight_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This shows all gold purchases rendered from miners after processing completion.',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderItem(String label, String value, IconData icon) {
    return Column(
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
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(ServiceRequestEntity request) {
    final fd = request.financialDetails;
    final bool isGroup = request.participatingMinerIds.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGroup
                          ? 'Group (Korpo)'
                          : (request.creatorName ?? 'Miner'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'MMMM dd, yyyy • hh:mm a',
                      ).format(request.createdAt),
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'P ${NumberFormat("#,##0.00").format(fd?.goldPurchaseValue ?? 0)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardMiniStat(
                  'Weight',
                  '${fd?.goldWeightGrams}g',
                  Icons.scale_rounded,
                ),
                _buildCardMiniStat(
                  'Unit Price',
                  'P ${NumberFormat("#,##0").format(fd?.goldBuyingPrice ?? 0)}',
                  Icons.tag_rounded,
                ),
                _buildCardMiniStat(
                  'Ref ID',
                  request.id.substring(0, 5).toUpperCase(),
                  Icons.numbers_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kGold.withOpacity(0.5), size: 14),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 9),
        ),
      ],
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
}
