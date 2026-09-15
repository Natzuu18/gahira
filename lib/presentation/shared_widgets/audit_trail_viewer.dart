import 'package:flutter/material.dart';
import 'appColor.dart';

class AuditTrailViewer extends StatelessWidget {
  final List<Map<String, dynamic>> auditTrails;

  const AuditTrailViewer({super.key, required this.auditTrails});

  @override
  Widget build(BuildContext context) {
    if (auditTrails.isEmpty) {
      return Center(
        child: Text('No history available', style: TextStyle(color: context.mutedTextColor)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: auditTrails.length,
      itemBuilder: (context, index) {
        final trail = auditTrails[index];
        final user = trail['user'] as Map<String, dynamic>?;
        final userName = user != null ? '${user['fname']} ${user['lname']}' : 'System';
        final role = user != null ? user['role_id'] : '';
        final date = DateTime.parse(trail['created_at']);

        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle),
                  ),
                  if (index != auditTrails.length - 1)
                    Expanded(
                      child: Container(width: 2, color: kGold.withOpacity(0.3)),
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
                            trail['action'].toString().replaceAll('_', ' '),
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                      Text(
                        'By $userName ($role)',
                        style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      if (trail['remarks'] != null && trail['remarks'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            trail['remarks'],
                            style: TextStyle(color: context.mutedTextColor, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${trail['previous_status']} → ${trail['new_status']}',
                        style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
