import 'package:equatable/equatable.dart';

class AvailabilityEntity extends Equatable {
  final String? availabilityId;
  final DateTime date;
  final String startTime; // Format: "HH:mm:ss"
  final String endTime;   // Format: "HH:mm:ss"
  final String address;
  final String status;    // open, full, closed
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AvailabilityEntity({
    this.availabilityId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.address,
    this.status = 'open',
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        availabilityId,
        date,
        startTime,
        endTime,
        address,
        status,
        createdAt,
        updatedAt,
      ];
}
