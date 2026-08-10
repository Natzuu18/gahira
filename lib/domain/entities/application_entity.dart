import 'package:equatable/equatable.dart';

class ApplicationEntity extends Equatable {
  final String applicationId;
  final String userId; // FK -> UserEntity
  final DateTime createdAt;
  final DateTime? responseAt; // null until a response is made
  final String status; // e.g. pending / approved / rejected

  const ApplicationEntity({
    required this.applicationId,
    required this.userId,
    required this.createdAt,
    this.responseAt,
    required this.status,
  });

  @override
  List<Object?> get props => [
    applicationId,
    userId,
    createdAt,
    responseAt,
    status,
  ];
}