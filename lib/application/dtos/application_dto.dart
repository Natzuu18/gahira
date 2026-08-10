import '../../domain/entities/application_entity.dart';

class ApplicationDto {
  final String applicationId;
  final String userId;
  final String createdAt;   // ISO 8601 string over the wire
  final String? responseAt;
  final String status;

  const ApplicationDto({
    required this.applicationId,
    required this.userId,
    required this.createdAt,
    this.responseAt,
    required this.status,
  });

  factory ApplicationDto.fromJson(Map<String, dynamic> json) {
    return ApplicationDto(
      applicationId: json['applicationID'] as String,
      userId: json['userId'] as String,
      createdAt: json['created_at'] as String,
      responseAt: json['response_at'] as String?,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'applicationID': applicationId,
      'userId': userId,
      'created_at': createdAt,
      'response_at': responseAt,
      'status': status,
    };
  }

  factory ApplicationDto.fromEntity(ApplicationEntity entity) {
    return ApplicationDto(
      applicationId: entity.applicationId,
      userId: entity.userId,
      createdAt: entity.createdAt.toIso8601String(),
      responseAt: entity.responseAt?.toIso8601String(),
      status: entity.status,
    );
  }

  ApplicationEntity toEntity() {
    return ApplicationEntity(
      applicationId: applicationId,
      userId: userId,
      createdAt: DateTime.parse(createdAt),
      responseAt: responseAt != null ? DateTime.parse(responseAt!) : null,
      status: status,
    );
  }
}