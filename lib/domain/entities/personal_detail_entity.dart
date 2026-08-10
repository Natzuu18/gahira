import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class PersonalDetailEntity extends Equatable {
  final String userId;     // FK -> UserEntity
  final String documentId;
  final Uint8List document; // blob/file bytes

  const PersonalDetailEntity({
    required this.userId,
    required this.documentId,
    required this.document,
  });

  @override
  List<Object?> get props => [userId, documentId, document];
}