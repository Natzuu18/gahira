import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/personal_detail_repository.dart';
import '../dtos/personal_detail_dto.dart';

class PersonalDetailService {
  final PersonalDetailRepository repository;
  PersonalDetailService(this.repository);

  Future<Either<Failure, PersonalDetailDto>> getPersonalDetailByUserId(String userId) async {
    final result = await repository.getPersonalDetailByUserId(userId);
    return result.map((entity) => PersonalDetailDto.fromEntity(entity));
  }

  Future<Either<Failure, void>> uploadPersonalDetail(PersonalDetailDto personalDetail) {
    return repository.uploadPersonalDetail(personalDetail.toEntity());
  }
}
