import 'dart:math';

import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

/// -----------------------------------------------------------------------
/// MODEL
/// -----------------------------------------------------------------------
enum AccountRole { client, operator }

enum DocumentType { image, pdf, other }

class AccountDocument {
  final String id;
  final String label; // e.g. "Valid ID", "Business Permit"
  final String url; // network URL (or local file path if you store locally)
  final DocumentType type;

  AccountDocument({
    required this.id,
    required this.label,
    required this.url,
    required this.type,
  });
}

class PendingAccount {
  final String id;
  final String fullName;
  final String username;
  final String phoneNumber; // must be in a format your SMS provider accepts
  final AccountRole role;
  final DateTime requestedAt;
  final List<AccountDocument> documents;

  PendingAccount({
    required this.id,
    required this.fullName,
    required this.username,
    required this.phoneNumber,
    required this.role,
    required this.requestedAt,
    this.documents = const [],
  });
}

/// -----------------------------------------------------------------------
/// SERVICE LAYER
/// Replace the bodies of these methods with real calls to your backend
/// (Firebase, REST API, etc.) and your SMS provider (Semaphore, Twilio,
/// Infobip, etc.). Everything else in this file only depends on these
/// method signatures, so swapping the implementation is all you need.
/// -----------------------------------------------------------------------
class ApprovalService {
  /// Fetch accounts awaiting admin approval.
  Future<List<PendingAccount>> fetchPendingAccounts() async {
    // TODO: replace with real query, e.g.:
    // final snap = await FirebaseFirestore.instance
    //     .collection('users')
    //     .where('status', isEqualTo: 'pending')
    //     .get();
    await Future.delayed(const Duration(milliseconds: 600));

    return [
      PendingAccount(
        id: '1',
        fullName: 'Juan Dela Cruz',
        username: 'juan.delacruz',
        phoneNumber: '+639171234567',
        role: AccountRole.client,
        requestedAt: DateTime.now().subtract(const Duration(hours: 3)),
        documents: [
          AccountDocument(
            id: 'd1',
            label: 'Valid ID (Front)',
            url: 'https://example.com/uploads/juan_id_front.jpg',
            type: DocumentType.image,
          ),
          AccountDocument(
            id: 'd2',
            label: 'Valid ID (Back)',
            url: 'https://example.com/uploads/juan_id_back.jpg',
            type: DocumentType.image,
          ),
        ],
      ),
      PendingAccount(
        id: '2',
        fullName: 'Maria Santos',
        username: 'maria.santos',
        phoneNumber: '+639181234567',
        role: AccountRole.operator,
        requestedAt: DateTime.now().subtract(const Duration(days: 1)),
        documents: [
          AccountDocument(
            id: 'd3',
            label: 'Valid ID',
            url: 'https://example.com/uploads/maria_id.jpg',
            type: DocumentType.image,
          ),
          AccountDocument(
            id: 'd4',
            label: 'Business Permit',
            url: 'https://example.com/uploads/maria_permit.pdf',
            type: DocumentType.pdf,
          ),
          AccountDocument(
            id: 'd5',
            label: 'Driver\'s License',
            url: 'https://example.com/uploads/maria_license.jpg',
            type: DocumentType.image,
          ),
        ],
      ),
    ];
  }

  /// Marks the account as approved and stores the temp password
  /// (hashed, with a mustChangePassword flag) in your backend.
  Future<void> approveAccount({
    required PendingAccount account,
    required String temporaryPassword,
  }) async {
    // TODO: replace with real update, e.g.:
    // await FirebaseFirestore.instance.collection('users').doc(account.id).update({
    //   'status': 'approved',
    //   'password': hash(temporaryPassword),
    //   'mustChangePassword': true,
    //   'approvedAt': FieldValue.serverTimestamp(),
    // });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> rejectAccount(PendingAccount account) async {
    // TODO: replace with real update (status: 'rejected')
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// Sends the approval SMS containing username + temporary password.
  /// Wire this up to your SMS gateway of choice.
  Future<void> sendApprovalSms({
    required String phoneNumber,
    required String username,
    required String temporaryPassword,
  }) async {
    final message = 'Your GAHIRA account has been approved.\n'
        'Username: $username\n'
        'Temporary Password: $temporaryPassword\n'
        'Please log in and change your password immediately.';

    // TODO: replace with your SMS provider call, e.g.:
    // await http.post(
    //   Uri.parse('https://api.semaphore.co/api/v4/messages'),
    //   body: {
    //     'apikey': SMS_API_KEY,
    //     'number': phoneNumber,
    //     'message': message,
    //   },
    // );
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('SMS -> $phoneNumber: $message');
  }
}

/// -----------------------------------------------------------------------
/// PAGE
/// -----------------------------------------------------------------------
class ApprovalPage extends StatefulWidget {
  const ApprovalPage({super.key});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApprovalService _service = ApprovalService();

  bool _loading = true;
  List<PendingAccount> _accounts = [];
  final Set<String> _processingIds = {}; // ids currently being approved/rejected
  AccountRole? _filter; // null = show all

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    final accounts = await _service.fetchPendingAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  String _generateTemporaryPassword({int length = 10}) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> _confirmAndApprove(PendingAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Account'),
        content: Text(
          'Approve "${account.fullName}" (${account.role == AccountRole.client ? 'Client' : 'Operator'})?\n\n'
              'An SMS with their username and a temporary password will be sent to ${account.phoneNumber}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _approveAccount(account);
  }

  Future<void> _approveAccount(PendingAccount account) async {
    setState(() => _processingIds.add(account.id));

    try {
      final tempPassword = _generateTemporaryPassword();

      await _service.approveAccount(
        account: account,
        temporaryPassword: tempPassword,
      );

      await _service.sendApprovalSms(
        phoneNumber: account.phoneNumber,
        username: account.username,
        temporaryPassword: tempPassword,
      );

      if (!mounted) return;
      setState(() {
        _accounts.removeWhere((a) => a.id == account.id);
        _processingIds.remove(account.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${account.fullName} approved. SMS sent.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(account.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve ${account.fullName}: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _confirmAndReject(PendingAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Account'),
        content: Text('Reject "${account.fullName}"\'s account request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(account.id));
    try {
      await _service.rejectAccount(account);
      if (!mounted) return;
      setState(() {
        _accounts.removeWhere((a) => a.id == account.id);
        _processingIds.remove(account.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.fullName} rejected.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(account.id));
    }
  }

  List<PendingAccount> get _filteredAccounts {
    if (_filter == null) return _accounts;
    return _accounts.where((a) => a.role == _filter).toList();
  }

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
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.approval),
      body: RefreshIndicator(
        onRefresh: _loadAccounts,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterChips(),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kGold))
                  : _filteredAccounts.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _filteredAccounts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final account = _filteredAccounts[index];
                  return _buildAccountCard(account);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: kGold.withOpacity(0.8), size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approvals',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Review and approve pending client and operator accounts.',
                  style: TextStyle(color: context.textColor.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip('All', null),
          const SizedBox(width: 8),
          _filterChip('Clients', AccountRole.client),
          const SizedBox(width: 8),
          _filterChip('Operators', AccountRole.operator),
        ],
      ),
    );
  }

  Widget _filterChip(String label, AccountRole? role) {
    final selected = _filter == role;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = role),
      selectedColor: kGold.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? kGold : context.textColor.withOpacity(0.7),
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? kGold : context.textColor.withOpacity(0.15)),
      backgroundColor: context.surfaceColor,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: kGold.withOpacity(0.6), size: 48),
          const SizedBox(height: 12),
          Text(
            'No pending approvals',
            style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'New client and operator sign-ups will show up here.',
            style: TextStyle(color: context.textColor.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(PendingAccount account) {
    final isProcessing = _processingIds.contains(account.id);
    final isOperator = account.role == AccountRole.operator;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.textColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kGold.withOpacity(0.15),
                child: Icon(
                  isOperator ? Icons.badge_outlined : Icons.person_outline,
                  color: kGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.fullName,
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '@${account.username} · ${account.phoneNumber}',
                      style: TextStyle(color: context.textColor.withOpacity(0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOperator ? 'Operator' : 'Client',
                  style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (account.documents.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDocumentsPreview(account),
          ],
          const SizedBox(height: 12),
          if (isProcessing)
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _confirmAndReject(account),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _confirmAndApprove(account),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Small horizontal strip of thumbnails shown on the card, tap any of it
  /// to open the full documents sheet.
  Widget _buildDocumentsPreview(PendingAccount account) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDocumentsSheet(account),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.textColor.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: account.documents.take(4).map((doc) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildDocThumb(doc, size: 40),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${account.documents.length} document${account.documents.length == 1 ? '' : 's'} uploaded',
                style: TextStyle(color: context.textColor.withOpacity(0.7), fontSize: 12),
              ),
            ),
            Icon(Icons.chevron_right, color: context.textColor.withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDocThumb(AccountDocument doc, {double size = 56}) {
    final borderRadius = BorderRadius.circular(6);
    if (doc.type == DocumentType.image) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          doc.url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              color: context.textColor.withOpacity(0.06),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            width: size,
            height: size,
            color: context.textColor.withOpacity(0.06),
            child: Icon(Icons.broken_image_outlined, size: size * 0.4, color: context.textColor.withOpacity(0.4)),
          ),
        ),
      );
    }

    // PDF or other file types get an icon tile instead of a thumbnail.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.1),
        borderRadius: borderRadius,
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: Icon(
        doc.type == DocumentType.pdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
        color: kGold,
        size: size * 0.45,
      ),
    );
  }

  /// Bottom sheet listing every document the client/operator uploaded.
  void _openDocumentsSheet(PendingAccount account) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.folder_open_outlined, color: kGold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${account.fullName} · Uploaded Documents',
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: account.documents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = account.documents[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _buildDocThumb(doc),
                        title: Text(
                          doc.label,
                          style: TextStyle(color: context.textColor, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          doc.type == DocumentType.pdf ? 'PDF document' : 'Image',
                          style: TextStyle(color: context.textColor.withOpacity(0.5), fontSize: 12),
                        ),
                        trailing: Icon(Icons.open_in_new, color: context.textColor.withOpacity(0.5), size: 18),
                        onTap: () => _openDocumentViewer(doc),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Full-screen viewer. Images render inline; PDFs and other file types
  /// show a placeholder — hook in a PDF viewer package (e.g. `pdfx` or
  /// `syncfusion_flutter_pdfviewer`) or launch the URL externally via
  /// `url_launcher` if you'd rather open it outside the app.
  void _openDocumentViewer(AccountDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(doc.label, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
          body: Center(
            child: doc.type == DocumentType.image
                ? InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                doc.url,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70, size: 64),
                const SizedBox(height: 12),
                const Text(
                  'PDF preview not wired up yet.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  'Integrate a PDF viewer package or open:\n${doc.url}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
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