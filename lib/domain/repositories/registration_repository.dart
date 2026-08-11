import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/registration_data.dart';
import '../entities/user_entity.dart';

abstract class RegistrationRepository {
  /// Submits the registration form data to the backend.
  /// Returns the newly created [UserEntity] on success.
  Future<Either<Failure, UserEntity>> register(RegistrationData registrationData);

  /// Sends a one-time password (OTP) to the specified phone number.
  Future<Either<Failure, void>> sendPhoneOtp(String phoneNumber);

  /// Verifies the OTP sent to the specified phone number.
  /// Returns the verification token on success.
  Future<Either<Failure, String>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  });
}
