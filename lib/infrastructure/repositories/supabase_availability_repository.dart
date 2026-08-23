import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/availability_entity.dart';
import '../../domain/repositories/availability_repository.dart';
import '../models/availability_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseAvailabilityRepository implements AvailabilityRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<Either<Failure, List<AvailabilityEntity>>> getAvailabilities() async {
    try {
      final response = await _client
          .from('appointment_availability')
          .select()
          .order('date', ascending: true);
      
      final list = (response as List)
          .map((json) => AvailabilityModel.fromJson(json))
          .toList();
      
      return Right(list);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AvailabilityEntity>> addAvailability(AvailabilityEntity availability) async {
    try {
      final model = AvailabilityModel.fromEntity(availability);
      final response = await _client
          .from('appointment_availability')
          .insert(model.toJson())
          .select()
          .single();
      return Right(AvailabilityModel.fromJson(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AvailabilityEntity>> updateAvailability(AvailabilityEntity availability) async {
    try {
      final model = AvailabilityModel.fromEntity(availability);
      final response = await _client
          .from('appointment_availability')
          .update(model.toJson())
          .eq('availability_id', availability.availabilityId!)
          .select()
          .single();
      return Right(AvailabilityModel.fromJson(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAvailability(String availabilityId) async {
    try {
      await _client
          .from('appointment_availability')
          .delete()
          .eq('availability_id', availabilityId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
