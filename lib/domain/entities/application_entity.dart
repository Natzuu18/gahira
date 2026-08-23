import 'package:equatable/equatable.dart';

class ApplicationEntity extends Equatable {
  final String applicationId;
  final String userId; // FK -> UserEntity
  final String? availabilityId; // FK -> AvailabilityEntity
  final String appointmentStatus; // scheduled, completed, cancelled, rescheduled, no_show
  final String? appointmentRemarks;
  final DateTime createdAt;
  final DateTime? responseAt; // null until a response is made
  final String status; // e.g. pending / approved / rejected

  const ApplicationEntity({
    required this.applicationId,
    required this.userId,
    this.availabilityId,
    this.appointmentStatus = 'scheduled',
    this.appointmentRemarks,
    required this.createdAt,
    this.responseAt,
    required this.status,
  });

  @override
  List<Object?> get props => [
    applicationId,
    userId,
    availabilityId,
    appointmentStatus,
    appointmentRemarks,
    createdAt,
    responseAt,
    status,
  ];
}
