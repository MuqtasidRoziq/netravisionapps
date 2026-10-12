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

      final headerJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      expect(header['alg'], 'HS256');
      expect(header['typ'], 'JWT');

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

  group('Pilot Server Security & Resilience Integration Tests', () {
    late PilotServer server;
    const testPort = 8199;
    final baseUrl = Uri.parse('http://127.0.0.1:$testPort');

    setUpAll(() async {
      server = PilotServer(
        port: testPort,
        livekitUrl: 'wss://test.livekit.local',
        livekitApiKey: 'pilot_api_key',
        livekitApiSecret: 'pilot_api_secret',
        requestTimeoutSeconds: 3,
        presenceTimeoutSeconds: 2,
      );
      await server.start();
    });

    tearDownAll(() async {
      await server.stop();
    });

    test('1. Health check mengembalikan 200 OK dengan informasi pilot aman', () async {
      final res = await http.get(baseUrl.replace(path: '/api/health'));
      expect(res.statusCode, HttpStatus.ok);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['version'], contains('hardened'));
    });

    test('2. Token dan accessKey TIDAK bocor pada endpoint publik GET /api/help-requests/:id', () async {
      // 1. Buat sesi bantuan
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_rahasia_01',
          'userName': 'Pengguna Bersih',
          'taskType': 'readLabel',
          'taskTarget': 'Label Obat Sirup',
          'recipientTarget': 'communityVolunteers',
          'communityId': 'komunitas_netra_pilot',
        }),
      );
      expect(createRes.statusCode, HttpStatus.created);
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      final reqId = createJson['id'] as String;
      final creatorAccessKey = createJson['accessKey'] as String;
      expect(creatorAccessKey, isNotEmpty);

      // 2. Query detail publik tanpa auth
      final getRes = await http.get(baseUrl.replace(path: '/api/help-requests/$reqId'));
      expect(getRes.statusCode, HttpStatus.ok);
      final getJson = jsonDecode(getRes.body) as Map<String, dynamic>;

      // VERIFIKASI KEAMANAN: Kunci dan token TIDAK BOLEH muncul di respons detail umum!
      expect(getJson.containsKey('accessKey'), isFalse, reason: 'accessKey tidak boleh bocor di GET publik');
      expect(getJson.containsKey('userToken'), isFalse, reason: 'userToken tidak boleh bocor di GET publik');
      expect(getJson.containsKey('companionToken'), isFalse, reason: 'companionToken tidak boleh bocor di GET publik');
      expect(getJson['status'], 'pending');
    });

    test('3. API /accept tanpa izin otentikasi ditolak 403 Forbidden', () async {
      // Buat permintaan
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_auth_test',
          'userName': 'User Auth Test',
          'taskType': 'generalHelp',
          'recipientTarget': 'communityVolunteers',
        }),
      );
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      final reqId = createJson['id'] as String;

      // Percobaan 1: Tanpa authKey dan bukan relawan terdaftar -> HARUS 403 Forbidden!
      final badAccept1 = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'companionId': 'comp_hacker_random',
          'companionName': 'Penyusup Asing',
        }),
      );
      expect(badAccept1.statusCode, HttpStatus.forbidden,
          reason: 'Endpoint /accept harus menolak pengirim yang tidak terotentikasi!');

      // Percobaan 2: Menggunakan authKey salah -> HARUS 403 Forbidden!
      final badAccept2 = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'X-Auth-Key': 'key_palsu_12345',
        },
        body: jsonEncode({
          'authKey': 'key_palsu_12345',
          'companionId': 'comp_hacker_random',
        }),
      );
      expect(badAccept2.statusCode, HttpStatus.forbidden);
    });

    test('4. API /accept dengan authKey sah berhasil 200 OK dan memberikan companion token', () async {
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_valid_auth',
          'userName': 'User Valid',
          'taskType': 'findObject',
          'taskTarget': 'Kacamata',
          'recipientTarget': 'communityVolunteers',
        }),
      );
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      final reqId = createJson['id'] as String;
      final accessKey = createJson['accessKey'] as String;

      // Panggilan /accept yang sah dengan authKey
      final validAccept = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'X-Auth-Key': accessKey,
        },
        body: jsonEncode({
          'authKey': accessKey,
          'companionName': 'Pendamping Sah',
        }),
      );

      expect(validAccept.statusCode, HttpStatus.ok);
      final acceptJson = jsonDecode(validAccept.body) as Map<String, dynamic>;
      expect(acceptJson['token'], isNotEmpty, reason: 'Token LiveKit companion harus diberikan');
      expect(acceptJson['status'], 'accepted');
    });

    test('5. Permintaan untuk kontak tepercaya (trustedContacts) tidak disebar ke relawan komunitas', () async {
      // Connect WebSocket relawan untuk mendengarkan broadcast
      final wsUri = Uri.parse('ws://127.0.0.1:$testPort/ws?userId=relawan_komunitas_01');
      final socket = await WebSocket.connect(wsUri.toString());
      final receivedEvents = <Map<String, dynamic>>[];

      // Register companion
      await http.post(
        baseUrl.replace(path: '/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': 'relawan_komunitas_01',
          'name': 'Relawan Komunitas 1',
          'role': 'companion',
          'communityId': 'komunitas_netra_pilot',
        }),
      );

      socket.listen((msg) {
        try {
          receivedEvents.add(jsonDecode(msg as String) as Map<String, dynamic>);
        } catch (_) {}
      });

      // 1. Buat permintaan untuk 'trustedContacts' (keluarga saja)
      final privRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_family_only',
          'userName': 'User Keluarga',
          'taskType': 'generalHelp',
          'recipientTarget': 'trustedContacts',
          'communityId': 'komunitas_netra_pilot',
        }),
      );
      expect(privRes.statusCode, HttpStatus.created);
      final privJson = jsonDecode(privRes.body) as Map<String, dynamic>;
      expect(privJson['webAssistUrl'], contains('/assist?req='));

      // Beri jeda kecil untuk penerimaan socket
      await Future.delayed(const Duration(milliseconds: 300));

      // Verifikasi: Relawan komunitas TIDAK menerima event 'new_help_request' untuk sesi keluarga!
      final hasLeakedToCommunity = receivedEvents.any((e) =>
          e['event'] == 'new_help_request' &&
          (e['request']?['id'] == privJson['id']));
      expect(hasLeakedToCommunity, isFalse,
          reason: 'Permintaan untuk trustedContacts tidak boleh dibroadcast ke relawan komunitas!');

      await socket.close();
    });

    test('6. Kegagalan mikrofon calon pendamping TIDAK menggagalkan seluruh permintaan (tetap pending)', () async {
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_candidate_fail_test',
          'userName': 'User Uji Resiliensi',
          'taskType': 'readLabel',
          'recipientTarget': 'communityVolunteers',
        }),
      );
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      final reqId = createJson['id'] as String;
      final accessKey = createJson['accessKey'] as String;

      // Calon pendamping A membuka web, namun izin mic ditolak di browsernya
      final failCandidateRes = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/fail'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'authKey': accessKey,
          'reason': 'Izin mikrofon browser ditolak',
        }),
      );
      expect(failCandidateRes.statusCode, HttpStatus.ok);

      // Verifikasi: Status tiket permintaan TETAP pending, tidak dibatalkan!
      final checkRes = await http.get(baseUrl.replace(path: '/api/help-requests/$reqId'));
      final checkJson = jsonDecode(checkRes.body) as Map<String, dynamic>;
      expect(checkJson['status'], 'pending',
          reason: 'Kegagalan kandidat pendamping tidak boleh membatalkan permintaan bagi relawan lain!');

      // Pendamping B yang siap dapat mengambil tiket yang sama dengan sukses
      final acceptB = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'authKey': accessKey,
          'companionName': 'Pendamping B',
        }),
      );
      expect(acceptB.statusCode, HttpStatus.ok);
    });

    test('7. /connected ditolak 409 Conflict jika sesi sudah dibatalkan atau selesai', () async {
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_cancel_guard',
          'userName': 'User Guard',
          'taskType': 'generalHelp',
          'recipientTarget': 'communityVolunteers',
        }),
      );
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      final reqId = createJson['id'] as String;
      final accessKey = createJson['accessKey'] as String;

      // Batalkan permintaan oleh pembuat
      final cancelRes = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authKey': accessKey, 'userId': 'user_cancel_guard'}),
      );
      expect(cancelRes.statusCode, HttpStatus.ok);

      // Percobaan browser web memanggil /connected pada sesi yang sudah batal -> DITOLAK 409!
      final connectRes = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/connected'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authKey': accessKey}),
      );
      expect(connectRes.statusCode, HttpStatus.conflict,
          reason: 'Tidak boleh mengubah sesi batal menjadi connected!');
    });

    test('8. Sesi yang telah diselesaikan (completed) ditutup dan tidak dapat dihidupkan kembali', () async {
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_complete_teardown',
          'userName': 'User Selesai',
          'taskType': 'readLabel',
          'recipientTarget': 'communityVolunteers',
        }),
      );
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      final reqId = createJson['id'] as String;
      final accessKey = createJson['accessKey'] as String;

      // Terima sesi
      await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authKey': accessKey, 'companionName': 'Pendamping'}),
      );

      // Selesaikan sesi
      final completeRes = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authKey': accessKey}),
      );
      expect(completeRes.statusCode, HttpStatus.ok);

      // Verifikasi status server
      final checkRes = await http.get(baseUrl.replace(path: '/api/help-requests/$reqId'));
      final checkJson = jsonDecode(checkRes.body) as Map<String, dynamic>;
      expect(checkJson['status'], 'completed');
      expect(checkJson['isRoomClosed'], isTrue);

      // Percobaan re-accept sesi selesai -> DITOLAK 409!
      final reAccept = await http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authKey': accessKey}),
      );
      expect(reAccept.statusCode, HttpStatus.conflict);
    });

    test('9. ATOMIC ACCEPTANCE: Dua pendamping menekan Terima bersamaan -> Tepat 1 berhasil, 1 ditolak 409 Conflict', () async {
      final createRes = await http.post(
        baseUrl.replace(path: '/api/help-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'user_concurrent_test',
          'userName': 'User Konkurensi',
          'taskType': 'deviceDisplay',
          'recipientTarget': 'communityVolunteers',
        }),
      );
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      final reqId = createJson['id'] as String;
      final accessKey = createJson['accessKey'] as String;

      final future1 = http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authKey': accessKey, 'companionName': 'Pendamping A'}),
      );

      final future2 = http.post(
        baseUrl.replace(path: '/api/help-requests/$reqId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authKey': accessKey, 'companionName': 'Pendamping B'}),
      );

      final responses = await Future.wait([future1, future2]);
      final statusCodes = responses.map((r) => r.statusCode).toList();

      expect(statusCodes, containsAll([HttpStatus.ok, HttpStatus.conflict]));
    });
  });
}
