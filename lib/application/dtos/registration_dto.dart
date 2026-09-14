import 'dart:convert';
import 'dart:typed_data';
import '../../domain/entities/registration_data.dart';
import '../../domain/entities/registration_enums.dart';

class RegistrationDto {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String phone;
  final String email;
  final String address;
  final String role; // "client" or "operator"
  final String? phoneVerificationToken;

  // Client-specific fields
  final String? miningUnitId;
  final String? clientDocumentBase64;
  final String? clientDocumentName;

  // Operator-specific fields
  final String? resumeBase64;
  final String? resumeName;
  final String? appointmentDate; // ISO 8601

  const RegistrationDto({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.address,
    required this.role,
    this.phoneVerificationToken,
    this.miningUnitId,
    this.clientDocumentBase64,
    this.clientDocumentName,
    this.resumeBase64,
    this.resumeName,
    this.appointmentDate,
  });

  factory RegistrationDto.fromEntity(RegistrationData entity) {
    return RegistrationDto(
      firstName: entity.firstName,
      middleName: entity.middleName,
      lastName: entity.lastName,
      phone: entity.phone,
      email: entity.email,
      address: entity.address,
      role: entity.role.name,
      phoneVerificationToken: entity.phoneVerificationToken,
      miningUnitId: entity.miningUnitId,
      clientDocumentBase64: entity.clientDocument != null
          ? base64Encode(entity.clientDocument!)
          : null,
      clientDocumentName: entity.clientDocumentName,
      resumeBase64:
          entity.resume != null ? base64Encode(entity.resume!) : null,
      resumeName: entity.resumeName,
      appointmentDate: entity.appointmentDate?.toIso8601String(),
    );
  }

  RegistrationData toEntity() {
    DateTime? parsedAppointmentDate;
    if (appointmentDate != null && appointmentDate!.isNotEmpty) {
      try {
        parsedAppointmentDate = DateTime.parse(appointmentDate!);
      } catch (e) {
        parsedAppointmentDate = null;
      }
    }
    
    return RegistrationData(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      phone: phone,
      email: email,
      address: address,
      role: UserRole.values.byName(role),
      phoneVerificationToken: phoneVerificationToken,
      miningUnitId: miningUnitId,
      clientDocument: clientDocumentBase64 != null
          ? Uint8List.fromList(base64Decode(clientDocumentBase64!))
          : null,
      clientDocumentName: clientDocumentName,
      resume: resumeBase64 != null
          ? Uint8List.fromList(base64Decode(resumeBase64!))
          : null,
      resumeName: resumeName,
      appointmentDate: parsedAppointmentDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'address': address,
      'role': role,
      'phoneVerificationToken': phoneVerificationToken,
      'miningUnitId': miningUnitId,
      'clientDocument': clientDocumentBase64,
      'clientDocumentName': clientDocumentName,
      'resume': resumeBase64,
      'resumeName': resumeName,
      'appointmentDate': appointmentDate,
    };
  }
}
