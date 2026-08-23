import '../../domain/entities/application_entity.dart';

class ApplicationDto {
  final String applicationId;
  final String userId;
  final String? availabilityId;
  final String appointmentStatus;
  final String? appointmentRemarks;
  final String createdAt; // ISO 8601 string over the wire
  final String? responseAt;
  final String status;

  const ApplicationDto({
    required this.applicationId,
    required this.userId,
    this.availabilityId,
    this.appointmentStatus = 'scheduled',
    this.appointmentRemarks,
    required this.createdAt,
    this.responseAt,
    required this.status,
  });

  factory ApplicationDto.fromJson(Map<String, dynamic> json) {
    return ApplicationDto(
      applicationId: (json['application_id'] ?? json['applicationID']) as String,
      userId: json['userId'] as String,
      availabilityId: json['availability_id'] as String?,
      appointmentStatus: json['appointment_status'] as String? ?? 'scheduled',
      appointmentRemarks: json['appointment_remarks'] as String?,
      createdAt: json['created_at'] as String,
      responseAt: json['response_at'] as String?,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'application_id': applicationId,
      'userId': userId,
      'availability_id': availabilityId,
      'appointment_status': appointmentStatus,
      'appointment_remarks': appointmentRemarks,
      'created_at': createdAt,
      'response_at': responseAt,
      'status': status,
    };
  }

  factory ApplicationDto.fromEntity(ApplicationEntity entity) {
    return ApplicationDto(
      applicationId: entity.applicationId,
      userId: entity.userId,
      availabilityId: entity.availabilityId,
      appointmentStatus: entity.appointmentStatus,
      appointmentRemarks: entity.appointmentRemarks,
      createdAt: entity.createdAt.toIso8601String(),
      responseAt: entity.responseAt?.toIso8601String(),
      status: entity.status,
    );
  }

  ApplicationEntity toEntity() {
    return ApplicationEntity(
      applicationId: applicationId,
      userId: userId,
      availabilityId: availabilityId,
      appointmentStatus: appointmentStatus,
      appointmentRemarks: appointmentRemarks,
      createdAt: DateTime.parse(createdAt),
      responseAt: responseAt != null ? DateTime.parse(responseAt!) : null,
      status: status,
    );
  }
}
