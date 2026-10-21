import 'package:flutter/material.dart';
import 'appColor.dart';

class AuditTrailViewer extends StatefulWidget {
  final List<Map<String, dynamic>> auditTrails;

  const AuditTrailViewer({super.key, required this.auditTrails});

  @override
  State<AuditTrailViewer> createState() => _AuditTrailViewerState();
}

class _AuditTrailViewerState extends State<AuditTrailViewer> {
  static const int _batchSize = 5;
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant AuditTrailViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auditTrails != widget.auditTrails) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditTrails = widget.auditTrails;
    if (auditTrails.isEmpty) {
      return Center(
        child: Text(
          'No history available',
          style: TextStyle(color: context.mutedTextColor),
        ),
      );
    }

    final pageCount = (auditTrails.length / _batchSize).ceil();
    final startIndex = _currentPage * _batchSize;
    final endIndex = (startIndex + _batchSize).clamp(0, auditTrails.length);
    final currentBatch = auditTrails.sublist(startIndex, endIndex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentBatch.length,
          itemBuilder: (context, index) {
            final trail = currentBatch[index];
            final user = trail['user'] as Map<String, dynamic>?;
            final userName = user != null
                ? '${user['fname']} ${user['lname']}'
                : 'System';
            final role = user != null ? user['role_id'] : '';
            final date = DateTime.parse(trail['created_at']);
            final remarks = trail['remarks']?.toString() ?? '';
            final wasScheduledWithoutOperator =
                trail['action'] == 'SCHEDULE_AND_ASSIGN' &&
                remarks.startsWith('Assigned to 0 operators');
            final actionLabel = wasScheduledWithoutOperator
                ? 'SCHEDULE SERVICE'
                : trail['action'].toString().replaceAll('_', ' ');
            final displayRemarks = wasScheduledWithoutOperator
                ? 'Scheduled and added to the scheduled mill queue. Operator assignment is pending.'
                : remarks;

            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: kGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index != currentBatch.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: kGold.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                actionLabel,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: context.mutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'By $userName ($role)',
                            style: const TextStyle(
                              color: kGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (displayRemarks.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                displayRemarks,
                                style: TextStyle(
                                  color: context.mutedTextColor,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${trail['previous_status']} → ${trail['new_status']}',
                            style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Showing ${startIndex + 1}–$endIndex of ${auditTrails.length}',
              style: TextStyle(color: context.mutedTextColor, fontSize: 12),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous batch',
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: kGold,
                ),
                Text(
                  '${_currentPage + 1} / $pageCount',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  tooltip: 'Next batch',
                  onPressed: _currentPage < pageCount - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: kGold,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
