import 'dart:convert';
import 'dart:typed_data';
import '../../domain/entities/personal_detail_entity.dart';

class PersonalDetailDto {
  final String userId;
  final String documentId;
  final String documentBase64; // blob transported as base64 over JSON

  const PersonalDetailDto({
    required this.userId,
    required this.documentId,
    required this.documentBase64,
  });

  factory PersonalDetailDto.fromJson(Map<String, dynamic> json) {
    return PersonalDetailDto(
      userId: json['userId'] as String,
      documentId: json['documentId'] as String,
      documentBase64: json['document'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'documentId': documentId,
      'document': documentBase64,
    };
  }

  factory PersonalDetailDto.fromEntity(PersonalDetailEntity entity) {
    return PersonalDetailDto(
      userId: entity.userId,
      documentId: entity.documentId,
      documentBase64: base64Encode(entity.document),
    );
  }

  PersonalDetailEntity toEntity() {
    return PersonalDetailEntity(
      userId: userId,
      documentId: documentId,
      document: Uint8List.fromList(base64Decode(documentBase64)),
    );
  }
}