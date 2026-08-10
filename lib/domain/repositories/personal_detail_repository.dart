import 'package:dartz/dartz.dart';
import '../entities/personal_detail_entity.dart';
import '../../core/error/failures.dart';

abstract class PersonalDetailRepository {
  Future<Either<Failure, PersonalDetailEntity>> getPersonalDetailByUserId(String userId);
  Future<Either<Failure, void>> uploadPersonalDetail(PersonalDetailEntity personalDetail);
}
