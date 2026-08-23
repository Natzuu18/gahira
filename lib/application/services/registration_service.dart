import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/registration_repository.dart';
import '../dtos/registration_dto.dart';
import '../dtos/user_dto.dart';

class RegistrationService {
  final RegistrationRepository repository;

  RegistrationService(this.repository);

  /// Fetches available appointment slots from the database.
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailableSlots() {
    return repository.getAvailableSlots();
  }

  /// Submits the registration DTO to the repository.
  /// Maps the resulting UserEntity to a UserDto.
  Future<Either<Failure, UserDto>> register(RegistrationDto registrationDto) async {
    final result = await repository.register(registrationDto.toEntity());
    return result.map((entity) => UserDto.fromEntity(entity));
  }

  /// Sends a one-time password (OTP) to the specified phone number.
  Future<Either<Failure, void>> sendPhoneOtp(String phoneNumber) {
    return repository.sendPhoneOtp(phoneNumber);
  }

  /// Verifies the OTP sent to the specified phone number.
  Future<Either<Failure, String>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  }) {
    return repository.verifyPhoneOtp(
      phoneNumber: phoneNumber,
      code: code,
    );
  }
}
