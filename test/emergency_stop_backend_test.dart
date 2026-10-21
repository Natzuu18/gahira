import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gahira/infrastructure/repositories/supabase_service_request_repository.dart';

void main() {
  test(
    'machine emergency stop updates machine, drums, active requests, and audit trail',
    () async {
      final requests = <http.Request>[];
      final mockHttpClient = MockClient((request) async {
        requests.add(request);
        final table = request.url.pathSegments.last;

        if (request.method == 'GET' && table == 'drums') {
          return http.Response(
            jsonEncode([
              {'drum_id': 'drum-1'},
              {'drum_id': 'drum-2'},
            ]),
            200,
            request: request,
          );
        }
        if (request.method == 'GET' && table == 'milling_batches') {
          return http.Response(
            jsonEncode([
              {'service_request_id': 'request-1'},
              {'service_request_id': 'request-2'},
            ]),
            200,
            request: request,
          );
        }
        if (request.method == 'POST' && table == 'audit_trails') {
          return http.Response(
            '[]',
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.method == 'PATCH' &&
            {'machines', 'drums', 'service_requests'}.contains(table)) {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }

        return http.Response(
          'Unexpected request: ${request.method} ${request.url}',
          500,
          request: request,
        );
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: mockHttpClient,
      );
      final repository = SupabaseServiceRequestRepository(client: client);

      final result = await repository.triggerEmergencyStop(
        operatorId: 'operator-1',
        reason: 'Motor overheating',
        evidenceUrl: 'https://example.test/evidence.jpg',
        machineId: 'machine-1',
        stopEntireMachine: true,
      );

      expect(
        result.isRight(),
        isTrue,
        reason: result.fold((failure) => failure.toString(), (_) => ''),
      );
      expect(
        requests
            .where((r) => r.method == 'PATCH')
            .map((r) => r.url.pathSegments.last),
        containsAll(['machines', 'drums', 'service_requests']),
      );

      final requestUpdate = requests.firstWhere(
        (r) =>
            r.method == 'PATCH' &&
            r.url.pathSegments.last == 'service_requests',
      );
      final payload = jsonDecode(requestUpdate.body) as Map<String, dynamic>;
      expect(payload['status'], 'emergencyStop');
      expect(payload['emergency_reason'], 'MACHINE FAILURE: Motor overheating');
      expect(
        payload['emergency_evidence_url'],
        'https://example.test/evidence.jpg',
      );
      expect(
        DateTime.tryParse(payload['emergency_stopped_at'] as String),
        isNotNull,
      );

      final batchQuery = requests.firstWhere(
        (r) =>
            r.method == 'GET' && r.url.pathSegments.last == 'milling_batches',
      );
      expect(batchQuery.url.queryParameters['status'], 'eq.milling');
      expect(
        batchQuery.url.queryParameters['drum_id'],
        anyOf('in.(drum-1,drum-2)', 'in.("drum-1","drum-2")'),
      );

      final auditRequests = requests.where(
        (r) => r.method == 'POST' && r.url.pathSegments.last == 'audit_trails',
      );
      expect(auditRequests, hasLength(2));
      await client.dispose();
      mockHttpClient.close();
    },
  );

  test(
    'specific drum emergency stop updates only its active service request',
    () async {
      final requests = <http.Request>[];
      final mockHttpClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.pathSegments.last == 'milling_batches') {
          return http.Response(
            jsonEncode([
              {'service_request_id': 'request-1'},
            ]),
            200,
            request: request,
          );
        }
        if (request.method == 'POST' &&
            request.url.pathSegments.last == 'audit_trails') {
          return http.Response(
            '[]',
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.method == 'PATCH' &&
            {
              'drums',
              'service_requests',
            }.contains(request.url.pathSegments.last)) {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          'Unexpected request: ${request.method} ${request.url}',
          500,
          request: request,
        );
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: mockHttpClient,
      );
      final repository = SupabaseServiceRequestRepository(client: client);

      final result = await repository.triggerEmergencyStop(
        operatorId: 'operator-1',
        reason: 'Bearing failure',
        drumId: 'drum-1',
      );

    expect(
      result.isRight(),
      isTrue,
      reason: result.fold((failure) => failure.toString(), (_) => ''),
    );
      expect(
        requests
            .where((r) => r.method == 'PATCH')
            .map((r) => r.url.pathSegments.last),
        ['drums', 'service_requests'],
      );
      final requestUpdate = requests.firstWhere(
        (r) =>
            r.method == 'PATCH' &&
            r.url.pathSegments.last == 'service_requests',
      );
      final payload = jsonDecode(requestUpdate.body) as Map<String, dynamic>;
      expect(payload['status'], 'emergencyStop');
      expect(payload['emergency_reason'], 'DRUM FAILURE: Bearing failure');
      expect(payload['emergency_evidence_url'], isNull);
      await client.dispose();
    mockHttpClient.close();
    },
  );
}
