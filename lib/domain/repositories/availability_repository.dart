import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/availability_entity.dart';

abstract class AvailabilityRepository {
  Future<Either<Failure, List<AvailabilityEntity>>> getAvailabilities();
  Future<Either<Failure, AvailabilityEntity>> addAvailability(AvailabilityEntity availability);
  Future<Either<Failure, AvailabilityEntity>> updateAvailability(AvailabilityEntity availability);
  Future<Either<Failure, void>> deleteAvailability(String availabilityId);
}
