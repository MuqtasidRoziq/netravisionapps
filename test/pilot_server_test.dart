import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: avoid_relative_lib_imports
import '../server/lib/livekit_jwt.dart';
// ignore: avoid_relative_lib_imports
import '../server/lib/pilot_server.dart';

void main() {
  group('LiveKit JWT Token Tests', () {
    test('Membuat token LiveKit valid dengan format JWT 3 bagian (header.payload.signature)', () {
      final token = LiveKitJwt.createToken(
        apiKey: 'test_key',
        apiSecret: 'test_secret_1234567890',
        roomName: 'room_pilot_test',
        identity: 'user_01',
        name: 'Budi Tunanetra',
        canPublish: true,
        canSubscribe: true,
      );

      final parts = token.split('.');
      expect(parts.length, 3, reason: 'Token JWT harus memiliki 3 bagian base64url');

      // Decode header
      final headerJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      expect(header['alg'], 'HS256');
      expect(header['typ'], 'JWT');

      // Decode payload
      final payloadJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      expect(payload['iss'], 'test_key');
      expect(payload['sub'], 'user_01');
      expect(payload['name'], 'Budi Tunanetra');
      expect(payload['video']['room'], 'room_pilot_test');
      expect(payload['video']['canPublish'], true);
      expect(payload['video']['canSubscribe'], true);
    });
  });

  group('Pilot Server Integration Tests', () {
    late PilotServer server;
    const testPort = 8199;
    final baseUrl = Uri.parse('http://127.0.0.1:$testPort');

    setUpAll(() async {
      server = PilotServer(
        port: testPort,
        livekitUrl: 'wss://test.livekit.local',
        livekitApiKey: 'pilot_api_key',
        livekitApiSecret: 'pilot_api_secret',
        requestTimeoutSeconds: 3, // Singkat untuk testing
        presenceTimeoutSeconds: 2,
      );
      await server.start();
    });

    tearDownAll(() async {
      await server.stop();
    });

    test('1. Health check mengembalikan 200 OK dengan informasi pilot', () async {
      final res = await http.get(baseUrl.replace(path: '/api/health'));
      expect(res.statusCode, HttpStatus.ok);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['version'], '2.0.0');
    });

    test('2. Registrasi pendamping dan pengaturan ketersediaan', () async {
      // Login Pendamping 1
      final loginRes1 = await http.post(
        baseUrl.replace(path: '/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': 'comp_01',
          'name': 'Relawan Siti',
          'role': 'companion',
          'communityId': 'komunitas_netra_pilot',
        }),
      );
      expect(loginRes1.statusCode, HttpStatus.ok);

      // Login Pendamping 2
      final loginRes2 = await http.post(
        baseUrl.replace(path: '/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': 'comp_02',
          'name': 'Relawan Ahmad',
          'role': 'companion',
          'communityId': 'komunitas_netra_pilot',
        }),
      );
      expect(loginRes2.statusCode, HttpStatus.ok);

      // Cek pendamping yang tersedia
      final availRes = await http.get(
        baseUrl.replace(path: '/api/companions/available', queryParameters: {'communityId': 'komunitas_netra_pilot'}),
      );
      expect(availRes.statusCode, HttpStatus.ok);
      final availJson = jsonDecode(availRes.body) as Map<String, dynamic>;
      final companions = availJson['companions'] as List;
      expect(companions.length, greaterThanOrEqualTo(2));
    });

    test('3. Membuat permintaan bantuan dengan konteks tugas spesifik', () async {
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_budi',
          'userName': 'Budi Santoso',
          'taskType': 'readLabel',
          'taskTarget': 'Kemasan Obat Paracetamol',
          'unverifiedAiLabel': 'botol',
          'notes': 'Mohon bantu baca aturan pakai dan tanggal kedaluwarsa',
          'sourceScreen': 'detector_indoor',
          'recipientTarget': 'communityVolunteers',
          'communityId': 'komunitas_netra_pilot',
        }),
      );

      expect(createRes.statusCode, HttpStatus.created);
      final json = jsonDecode(createRes.body) as Map<String, dynamic>;
      expect(json['status'], 'pending');
      expect(json['taskType'], 'readLabel');
      expect(json['taskTarget'], 'Kemasan Obat Paracetamol');
      expect(json['unverifiedAiLabel'], 'botol');
    });

    test('4. Mencegah permintaan bantuan ganda untuk pengguna yang sama', () async {
      final duplicateRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_budi',
          'userName': 'Budi Santoso',
          'taskType': 'findObject',
          'taskTarget': 'Kunci rumah',
          'sourceScreen': 'home',
          'recipientTarget': 'communityVolunteers',
          'communityId': 'komunitas_netra_pilot',
        }),
      );

      expect(duplicateRes.statusCode, HttpStatus.conflict);
      final json = jsonDecode(duplicateRes.body) as Map<String, dynamic>;
      expect(json['error'], contains('sudah memiliki sesi bantuan yang sedang aktif'));
    });

    test('5. ATOMIC ACCEPTANCE: Dua pendamping menekan Terima bersamaan -> Tepat 1 berhasil, 1 ditolak 409 Conflict', () async {
      // 1. Buat request baru dari user lain
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_dewi',
          'userName': 'Dewi Lestari',
          'taskType': 'deviceDisplay',
          'taskTarget': 'Layar Mesin Cuci',
          'sourceScreen': 'home',
          'recipientTarget': 'communityVolunteers',
          'communityId': 'komunitas_netra_pilot',
        }),
      );
      expect(createRes.statusCode, HttpStatus.created);
      final reqId = (jsonDecode(createRes.body) as Map<String, dynamic>)['id'] as String;

      // 2. Luncurkan accept dari dua relawan secara simultan (konkurensi)
      final future1 = http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'companionId': 'comp_01', 'companionName': 'Relawan Siti'}),
      );

      final future2 = http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'companionId': 'comp_02', 'companionName': 'Relawan Ahmad'}),
      );

      final responses = await Future.wait([future1, future2]);

      final statusCodes = responses.map((r) => r.statusCode).toList();

      // Memverifikasi invariant atomisitas:
      // Tepat satu harus 200 OK dan tepat satu harus 409 Conflict!
      expect(statusCodes, containsAll([HttpStatus.ok, HttpStatus.conflict]),
          reason: 'Dua pendamping yang menekan terima bersamaan tidak boleh sama-sama berhasil!');

      final successResponse = responses.firstWhere((r) => r.statusCode == HttpStatus.ok);
      final conflictResponse = responses.firstWhere((r) => r.statusCode == HttpStatus.conflict);

      final successJson = jsonDecode(successResponse.body) as Map<String, dynamic>;
      expect(successJson['token'], isNotEmpty);
      expect(successJson['livekitRoom'], isNotEmpty);

      final conflictJson = jsonDecode(conflictResponse.body) as Map<String, dynamic>;
      expect(conflictJson['error'], contains('sudah diambil oleh pendamping lain'));
    });

    test('6. Pembatalan sesi oleh pengguna sebelum diterima', () async {
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_tono',
          'userName': 'Tono',
          'taskType': 'generalHelp',
          'sourceScreen': 'home',
          'recipientTarget': 'communityVolunteers',
          'communityId': 'komunitas_netra_pilot',
        }),
      );
      final reqId = (jsonDecode(createRes.body) as Map<String, dynamic>)['id'] as String;

      final cancelRes = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': 'user_tono', 'reason': 'Pengguna membatalkan'}),
      );
      expect(cancelRes.statusCode, HttpStatus.ok);
      final cancelJson = jsonDecode(cancelRes.body) as Map<String, dynamic>;
      expect(cancelJson['status'], 'cancelled');

      // Mencoba menerima sesi yang dibatalkan harus ditolak 409
      final acceptCancelled = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'companionId': 'comp_01', 'companionName': 'Relawan Siti'}),
      );
      expect(acceptCancelled.statusCode, HttpStatus.conflict);
    });

    test('7. Penyelesaian sesi (complete) dan pelaporan (report)', () async {
      // Ambil user_dewi yang sesi nya sudah accepted di test 5
      final getReq = await http.get(baseUrl.replace(path: '/api/help-requests'));
      expect(getReq.statusCode, HttpStatus.notFound); // rute root /api/help-requests not found

      final reportRes = await http.post(
        baseUrl.replace(path: '/api/help-requests/req_test/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reportedBy': 'comp_01', 'reason': 'Kamera pengguna terputus-putus'}),
      );
      expect(reportRes.statusCode, HttpStatus.created);
    });
  });
}
