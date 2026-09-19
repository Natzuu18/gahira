import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

class SackingPage extends StatefulWidget {
  final ServiceRequestEntity request;

  const SackingPage({super.key, required this.request});

  @override
  State<SackingPage> createState() => _SackingPageState();
}

class _SackingPageState extends State<SackingPage> {
  final SupabaseServiceRequestRepository _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;
  
  final _sackController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    // Pre-fill with original quantity
    _sackController.text = (widget.request.materialDetails.numberOfSacks ?? 0).toString();
  }

  Future<void> _completeSacking({int? manualCount, bool skipped = false}) async {
    setState(() => _isSaving = true);
    
    final currentOperatorId = Supabase.instance.client.auth.currentUser?.id;
    if (currentOperatorId == null) return;

    final finalSacks = skipped 
        ? widget.request.materialDetails.numberOfSacks 
        : (manualCount ?? int.tryParse(_sackController.text) ?? widget.request.materialDetails.numberOfSacks);

    final result = await _service.updateProcessingStatus(
      requestId: widget.request.id,
      operatorId: currentOperatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: widget.request.status.name,
      newStage: ProcessingStage.loading, // Move to next stage
      sackedQuantity: finalSacks,
      remarks: skipped ? 'Sacking skipped' : 'Sacking completed with $finalSacks sacks',
    );

    // Also update the sacked_quantity in DB via additional data if we had a dedicated repo method, 
    // but updateProcessingStatus takes additionalData. 
    // Wait, let's update updateProcessingStatus in service to handle sackedQuantity.
    
    // Actually, I'll update the service_request_service method first to support this.
    
    result.fold(
      (l) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message)));
        setState(() => _isSaving = false);
      },
      (_) {
        Navigator.pop(context, true); // Success
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final originalSacks = widget.request.materialDetails.numberOfSacks ?? 0;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text('SACKING STAGE', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        actions: const [ThemeToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(originalSacks),
            const SizedBox(height: 32),
            Text('SACKING OPTIONS', style: TextStyle(color: context.mutedTextColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
            
            // Option 1: Skip
            _buildOptionCard(
              title: 'Skip Sacking',
              subtitle: 'Use current sacks (Good condition)',
              icon: Icons.fast_forward_rounded,
              color: Colors.blue,
              onTap: () => _completeSacking(skipped: true),
            ),
            
            const SizedBox(height: 16),
            
            // Option 2: Manual Input / Batch
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGold.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: kGold),
                      SizedBox(width: 12),
                      Text('Manual Sacking / Batching', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Input the final number of sacks after the sacking process.', style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _sackController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Final Sack Count',
                      labelStyle: TextStyle(color: context.mutedTextColor, fontSize: 14),
                      suffixText: 'Sacks',
                      filled: true,
                      fillColor: context.bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _completeSacking(),
                      style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kBlack))
                        : const Text('Confirm Sack Count', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(int originalSacks) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kGold.withOpacity(0.2), kGold.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, color: kGold, size: 40),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Original Sack Count', style: TextStyle(color: context.mutedTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('$originalSacks Sacks', style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Provided by: ${widget.request.creatorName ?? "Miner"}', style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: _isSaving ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.mutedTextColor),
          ],
        ),
      ),
    );
  }
}
