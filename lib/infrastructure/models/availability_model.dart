import '../../domain/entities/availability_entity.dart';

class AvailabilityModel extends AvailabilityEntity {
  const AvailabilityModel({
    super.availabilityId,
    required super.date,
    required super.startTime,
    required super.endTime,
    required super.address,
    super.status,
    super.createdAt,
    super.updatedAt,
  });

  factory AvailabilityModel.fromJson(Map<String, dynamic> json) {
    return AvailabilityModel(
      availabilityId: json['availability_id'],
      date: DateTime.parse(json['date']),
      startTime: json['start_time'],
      endTime: json['end_time'],
      address: json['address'],
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (availabilityId != null) 'availability_id': availabilityId,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
      'start_time': startTime,
      'end_time': endTime,
      'address': address,
      'status': status,
    };
  }

  factory AvailabilityModel.fromEntity(AvailabilityEntity entity) {
    return AvailabilityModel(
      availabilityId: entity.availabilityId,
      date: entity.date,
      startTime: entity.startTime,
      endTime: entity.endTime,
      address: entity.address,
      status: entity.status,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
