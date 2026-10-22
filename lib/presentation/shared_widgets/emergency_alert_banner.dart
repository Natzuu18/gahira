import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/models/service_request_model.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../admin/emergency_monitor_page.dart';
import 'monitoring_page.dart';

class EmergencyAlertBanner extends StatefulWidget {
  final bool isAdmin;
  final Widget? companion;

  const EmergencyAlertBanner({super.key, this.isAdmin = false, this.companion});

  @override
  State<EmergencyAlertBanner> createState() => _EmergencyAlertBannerState();
}

class _EmergencyAlertBannerState extends State<EmergencyAlertBanner> {
  final _repository = SupabaseServiceRequestRepository();
  final _audioPlayer = AudioPlayer();
  List<ServiceRequestEntity> _emergencyRequests = [];
  Timer? _timer;
  bool _soundPlayed = false;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _checkEmergencies();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkEmergencies(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkEmergencies() async {
    final result = await _repository.getServiceRequests();
    final requests = result.getOrElse(() => <ServiceRequestModel>[]);
    final activeBatchesResult = await _repository.getActiveMillingBatches();
    final stoppedRequestIds = <String>{};
    activeBatchesResult.fold((_) {}, (batches) {
      for (final batch in batches) {
        final drumStopped =
            batch['drums']?['status']?.toString().toLowerCase() ==
            'emergency_stop';
        final machineStopped =
            batch['machines']?['status']?.toString().toLowerCase() ==
            'emergency_stop';
        if ((drumStopped || machineStopped) &&
            batch['service_request_id'] != null) {
          stoppedRequestIds.add(batch['service_request_id'].toString());
        }
      }
    });
    final emergencies = requests.where((request) {
      return request.status == ServiceRequestStatus.emergencyStop ||
          (request.status == ServiceRequestStatus.processing &&
              stoppedRequestIds.contains(request.id));
    }).toList();
    final activeEmergencies = emergencies.where((request) {
      return request.emergencyResolvedAt == null ||
          stoppedRequestIds.contains(request.id);
    }).toList();
    emergencies.sort((a, b) {
      final aResolved = a.emergencyResolvedAt != null;
      final bResolved = b.emergencyResolvedAt != null;
      if (aResolved != bResolved) return aResolved ? 1 : -1;
      return (b.emergencyStoppedAt ?? DateTime(0)).compareTo(
        a.emergencyStoppedAt ?? DateTime(0),
      );
    });

    if (mounted) {
      setState(() {
        _emergencyRequests = emergencies;
        if (activeEmergencies.isNotEmpty && !_soundPlayed) {
          _playEmergencySound();
          _soundPlayed = true;
        } else if (activeEmergencies.isEmpty) {
          _soundPlayed = false;
          _audioPlayer.stop();
        }
      });
    }
  }

  Future<void> _playEmergencySound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/emergency.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint('Emergency Banner Sound Error: $e');
    }
  }

  Future<void> _handleResolve(ServiceRequestEntity request) async {
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId == null) return;

    setState(() => _isResolving = true);

    final result = await _repository.resolveEmergencyStop(
      requestId: request.id,
      adminId: adminId,
    );

    if (mounted) {
      result.fold(
        (l) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.message), backgroundColor: Colors.red),
          );
          setState(() => _isResolving = false);
        },
        (_) {
          _checkEmergencies();
          setState(() {
            _isResolving = false;
            // Optimistically update the list if possible, or just wait for checkEmergencies
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Issue marked as resolved. Systems restored.'),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_emergencyRequests.isEmpty) {
      return widget.companion ?? const SizedBox.shrink();
    }

    // Grouping emergencies if multiple exist (rare)
    final latest = _emergencyRequests.first;
    final isResolvedByAdmin = latest.emergencyResolvedAt != null;

    final emergencyCard = Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isResolvedByAdmin ? Colors.orange : Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isResolvedByAdmin ? Colors.orange : Colors.red)
                  .withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                _audioPlayer.stop();
                if (widget.isAdmin) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyMonitorPage(),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MonitoringPage(
                        request: latest,
                        title: 'EMERGENCY MONITOR',
                        isAdmin: widget.isAdmin,
                      ),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  Icon(
                    isResolvedByAdmin
                        ? Icons.check_circle_outline
                        : Icons.emergency_share_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isResolvedByAdmin
                              ? 'ISSUE RESOLVED'
                              : 'EMERGENCY STOP TRIGGERED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          isResolvedByAdmin
                              ? 'Waiting for operator to continue.'
                              : 'Source: ${latest.emergencyReason ?? "Unknown Device"}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.isAdmin && _emergencyRequests.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '+ ${_emergencyRequests.length - 1} other emergencies',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
            if (widget.isAdmin && !isResolvedByAdmin) ...[
              const Divider(color: Colors.white30, height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isResolving ? null : () => _handleResolve(latest),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isResolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Text(
                          'RESOLVED ISSUE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final companion = widget.companion;
    if (companion == null) return emergencyCard;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: companion),
              const SizedBox(width: 12),
              Expanded(child: emergencyCard),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [companion, const SizedBox(height: 12), emergencyCard],
        );
      },
    );
  }
}
