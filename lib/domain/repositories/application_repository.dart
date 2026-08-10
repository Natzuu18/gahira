import 'package:dartz/dartz.dart';
import '../entities/application_entity.dart';
import '../../core/error/failures.dart';

abstract class ApplicationRepository {
  Future<Either<Failure, List<ApplicationEntity>>> getApplicationsByUserId(String userId);
  Future<Either<Failure, List<ApplicationEntity>>> getAllApplications();
  Future<Either<Failure, void>> createApplication(ApplicationEntity application);
  Future<Either<Failure, void>> updateApplicationStatus(String applicationId, String status);
}
