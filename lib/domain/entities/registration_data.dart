import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'registration_enums.dart';

class RegistrationData extends Equatable {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String phone;
  final String email;
  final String address;
  final UserRole role;
  final String? phoneVerificationToken;

  // Client-specific fields
  final ClientType? clientType;
  final String? businessName;
  final Uint8List? clientDocument;
  final String? clientDocumentName;

  // Operator-specific fields
  final Uint8List? resume;
  final String? resumeName;
  final DateTime? appointmentDate;

  const RegistrationData({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.address,
    required this.role,
    this.phoneVerificationToken,
    this.clientType,
    this.businessName,
    this.clientDocument,
    this.clientDocumentName,
    this.resume,
    this.resumeName,
    this.appointmentDate,
  });

  @override
  List<Object?> get props => [
        firstName,
        middleName,
        lastName,
        phone,
        email,
        address,
        role,
        phoneVerificationToken,
        clientType,
        businessName,
        clientDocument,
        clientDocumentName,
        resume,
        resumeName,
        appointmentDate,
      ];
}
