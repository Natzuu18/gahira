import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';
import '../../infrastructure/repositories/supabase_approval_repository.dart';

/// -----------------------------------------------------------------------
/// MODEL
/// -----------------------------------------------------------------------
enum AccountRole { client, operator }

enum DocumentType { image, pdf, other }

class AccountDocument {
  final String id;
  final String label; // e.g. "Valid ID", "Business Permit"
  final String url; // network URL
  final DocumentType type;

  AccountDocument({
    required this.id,
    required this.label,
    required this.url,
    required this.type,
  });
}

class PendingAccount {
  final String userId;
  final String applicationId;
  final String fullName;
  final String username;
  final String phoneNumber;
  final AccountRole role;
  final DateTime requestedAt;
  final List<AccountDocument> documents;

  // Appointment info
  final DateTime? appointmentDate;
  final String? startTime;
  final String? endTime;
  final String? address;
  final String appointmentStatus;
  final String status;

  PendingAccount({
    required this.userId,
    required this.applicationId,
    required this.fullName,
    required this.username,
    required this.phoneNumber,
    required this.role,
    required this.requestedAt,
    this.documents = const [],
    this.appointmentDate,
    this.startTime,
    this.endTime,
    this.address,
    required this.appointmentStatus,
    required this.status,
  });
}

/// -----------------------------------------------------------------------
/// SERVICE LAYER
/// -----------------------------------------------------------------------
class ApprovalService {
  final SupabaseApprovalRepository _repository = SupabaseApprovalRepository();

  /// Fetch applications awaiting admin approval.
  Future<List<PendingAccount>> fetchPendingAccounts() async {
    final result = await _repository.fetchPendingApplications();
    
    final applications = result.fold(
      (failure) {
        debugPrint('Error fetching pending applications: ${failure.message}');
        throw Exception(failure.message);
      },
      (apps) => apps,
    );
    
    final accounts = <PendingAccount>[];
    for (final app in applications) {
      final user = app['user'] as Map<String, dynamic>?;
      if (user == null) continue;

      final roleData = user['role'] as Map<String, dynamic>?;
      final roleName = roleData != null ? roleData['role'] as String? : 'client';
      final role = roleName == 'operator' ? AccountRole.operator : AccountRole.client;
      
      final availability = app['availability'] as Map<String, dynamic>?;
      
      // Fetch the document path directly from the applications table column
      final documents = <AccountDocument>[];
      final String? docPath = app['document_id'] as String?;
      
      if (docPath != null) {
        try {
          final url = _repository.client.storage.from('userFiles').getPublicUrl(docPath);
          final lowerPath = docPath.toLowerCase();
          
          String label = 'Document';
          DocumentType type = DocumentType.other;

          if (lowerPath.endsWith('.png') || lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
            label = 'Valid ID';
            type = DocumentType.image;
          } else if (lowerPath.endsWith('.pdf')) {
            label = 'Document';
            type = DocumentType.pdf;
          } else if (lowerPath.endsWith('.docx') || lowerPath.endsWith('.doc')) {
            label = 'Document';
            type = DocumentType.other;
          }

          documents.add(AccountDocument(
            id: docPath,
            label: label,
            url: url,
            type: type,
          ));
        } catch (e) {
          debugPrint('Error generating public URL: $e');
        }
      }

      accounts.add(PendingAccount(
        userId: user['userId'] as String,
        applicationId: app['application_id'] as String,
        fullName: '${user['fname']} ${user['mname'] != null ? '${user['mname']} ' : ''}${user['lname']}',
        username: user['email'] as String,
        phoneNumber: user['contact_num'] as String,
        role: role,
        requestedAt: DateTime.parse(app['created_at'] as String),
        documents: documents,
        appointmentDate: availability != null ? DateTime.parse(availability['date'] as String) : null,
        startTime: availability?['start_time'],
        endTime: availability?['end_time'],
        address: availability?['address'],
        appointmentStatus: app['appointment_status'] ?? 'pending',
        status: app['status'] ?? 'pending',
      ));
    }
    return accounts;
  }

  Future<void> approveAccount({
    required PendingAccount account,
  }) async {
    final result = await _repository.approveApplication(
      applicationId: account.applicationId,
      userId: account.userId,
    );
    
    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {},
    );
  }

  Future<void> rejectAccount(PendingAccount account) async {
    final result = await _repository.updateApplicationStatus(
      applicationId: account.applicationId,
      userId: account.userId,
      status: 'rejected',
    );
    
    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {},
    );
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
  String? _errorMessage;
  List<PendingAccount> _accounts = [];
  final Set<String> _processingIds = {}; // applicationId
  AccountRole? _filter;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final accounts = await _service.fetchPendingAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
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
    if (_processingIds.contains(account.applicationId)) return; // Protection
    setState(() => _processingIds.add(account.applicationId));

    try {
      await _service.approveAccount(account: account);

      if (!mounted) return;
      setState(() {
        _accounts.removeWhere((a) => a.applicationId == account.applicationId);
        _processingIds.remove(account.applicationId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${account.fullName} approved. Temporary password sent via SMS.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(account.applicationId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve ${account.fullName}: $e'),
          backgroundColor: Colors.red.shade600,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _approveAccount(account),
          ),
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

    setState(() => _processingIds.add(account.applicationId));
    try {
      await _service.rejectAccount(account);
      if (!mounted) return;
      setState(() {
        _accounts.removeWhere((a) => a.applicationId == account.applicationId);
        _processingIds.remove(account.applicationId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.fullName} rejected.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(account.applicationId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
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
                  : _errorMessage != null
                      ? _buildErrorState()
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load applications',
              style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textColor.withOpacity(0.5), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAccounts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(PendingAccount account) {
    final isProcessing = _processingIds.contains(account.applicationId);
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
                      '${account.username} · ${account.phoneNumber}',
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
          const SizedBox(height: 12),
          
          // Appointment info for operators
          if (account.appointmentDate != null) ...[
             _buildInfoRow(
               Icons.event_available_rounded, 
               'Appointment: ${DateFormat('MMM dd, yyyy').format(account.appointmentDate!)}',
             ),
             _buildInfoRow(
               Icons.access_time_rounded, 
               'Time: ${_formatDisplayTime(account.startTime)} - ${_formatDisplayTime(account.endTime)}',
             ),
             _buildInfoRow(
               Icons.location_on_outlined, 
               'Address: ${account.address ?? 'N/A'}',
             ),
             const SizedBox(height: 8),
          ],

          Row(
            children: [
              _buildBadge('Status: ${account.status.toUpperCase()}', Colors.blueGrey),
              const SizedBox(width: 8),
              if (account.appointmentDate != null)
                _buildBadge('Appt: ${account.appointmentStatus.toUpperCase()}', _getApptStatusColor(account.appointmentStatus)),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kGold.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.textColor.withOpacity(0.8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getApptStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDisplayTime(String? timeStr) {
    if (timeStr == null) return 'N/A';
    try {
      final dt = DateFormat('HH:mm:ss').parse(timeStr);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return timeStr;
    }
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
                          doc.type == DocumentType.image 
                            ? 'Image' 
                            : (doc.type == DocumentType.pdf ? 'PDF document' : 'Word document'),
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

  /// Full-screen viewer.
  void _openDocumentViewer(AccountDocument doc) {
    final bool isPdf = doc.type == DocumentType.pdf;
    final bool isDoc = doc.url.toLowerCase().contains('.doc');
    
    IconData displayIcon = Icons.insert_drive_file_outlined;
    String typeLabel = 'Document';
    
    if (isPdf) {
      displayIcon = Icons.picture_as_pdf_outlined;
      typeLabel = 'PDF';
    } else if (isDoc) {
      displayIcon = Icons.description_outlined;
      typeLabel = 'Word Document';
    }

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
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(displayIcon, color: kGold.withOpacity(0.8), size: 80),
                        const SizedBox(height: 20),
                        Text(
                          '$typeLabel Preview',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Direct preview for $typeLabel files is not available in-app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: SelectableText(
                            doc.url,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: kGold, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Copy the link above to view the document.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
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
