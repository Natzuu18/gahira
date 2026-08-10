import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/application_repository.dart';
import '../dtos/application_dto.dart';

class ApplicationService {
  final ApplicationRepository repository;
  ApplicationService(this.repository);

  Future<Either<Failure, List<ApplicationDto>>> getApplicationsByUserId(String userId) async {
    final result = await repository.getApplicationsByUserId(userId);
    return result.map((entities) => entities.map((e) => ApplicationDto.fromEntity(e)).toList());
  }

  Future<Either<Failure, List<ApplicationDto>>> getAllApplications() async {
    final result = await repository.getAllApplications();
    return result.map((entities) => entities.map((e) => ApplicationDto.fromEntity(e)).toList());
  }

  Future<Either<Failure, void>> createApplication(ApplicationDto application) {
    return repository.createApplication(application.toEntity());
  }

  Future<Either<Failure, void>> updateApplicationStatus(String applicationId, String status) {
    return repository.updateApplicationStatus(applicationId, status);
  }
}
