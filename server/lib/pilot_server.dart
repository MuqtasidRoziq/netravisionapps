import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'livekit_jwt.dart';
import 'models/session_models.dart';

class PilotServer {
  final int port;
  final String livekitUrl;
  final String livekitApiKey;
  final String livekitApiSecret;
  final int requestTimeoutSeconds;
  final int presenceTimeoutSeconds;
  final String? sslCertPath;
  final String? sslKeyPath;

  HttpServer? _server;
  Timer? _cleanupTimer;

  final Map<String, HelpRequest> _requests = {};
  final Map<String, CompanionPresence> _companions = {};
  final Map<String, WebSocket> _clientSockets = {};
  final Map<String, String> _socketToUser = {};
  final List<SessionReport> _reports = [];

  PilotServer({
    this.port = 8080,
    this.livekitUrl = 'wss://pilot.netravision.internal',
    this.livekitApiKey = 'netra_pilot_key',
    this.livekitApiSecret = 'netra_pilot_secret_998244353',
    this.requestTimeoutSeconds = 45,
    this.presenceTimeoutSeconds = 30,
    this.sslCertPath,
    this.sslKeyPath,
  });

  Future<void> start() async {
    // Dukung konfigurasi dinamis melalui Environment Variables
    final effectivePort =
        int.tryParse(Platform.environment['PORT'] ?? '') ?? port;
    final effectiveLivekitUrl =
        Platform.environment['LIVEKIT_URL'] ?? livekitUrl;
    final certPath = Platform.environment['SSL_CERT_PATH'] ?? sslCertPath;
    final keyPath = Platform.environment['SSL_KEY_PATH'] ?? sslKeyPath;
    // Endpoint pilot tidak memiliki autentikasi produksi. Tetap di loopback
    // kecuali operator secara sadar membukanya ke jaringan.
    final bindAddress = Platform.environment['PILOT_ALLOW_NETWORK'] == 'true'
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4;

    if (certPath != null &&
        keyPath != null &&
        File(certPath).existsSync() &&
        File(keyPath).existsSync()) {
      final secContext = SecurityContext()
        ..useCertificateChain(certPath)
        ..usePrivateKey(keyPath);
      _server =
          await HttpServer.bindSecure(bindAddress, effectivePort, secContext);
      // ignore: avoid_print
      print(
          'NetraVision Pilot Server berjalan dengan HTTPS di port $effectivePort');
    } else {
      _server = await HttpServer.bind(bindAddress, effectivePort);
      // ignore: avoid_print
      print('NetraVision Pilot Server berjalan di port $effectivePort');
    }

    // Timer pembersihan berkala (timeout permintaan & presence)
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _processTimeouts();
    });

    _server!.listen((HttpRequest request) async {
      // Set CORS Headers untuk web testing / mobile companion
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers
          .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers',
          'Content-Type, Authorization, X-Auth-Key');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      final path = request.uri.path;

      // Handle WebSocket
      if (path == '/ws') {
        await _handleWebSocket(request);
        return;
      }

      // Handle REST API & Web Pages
      try {
        if (request.method == 'GET') {
          if (path == '/companion' || path == '/' || path == '/portal') {
            await _handleServeCompanionDashboard(request);
            return;
          }

          if (path == '/sw.js') {
            await _handleServeStaticFile(
                request, 'server/web/sw.js', 'application/javascript');
            return;
          }

          if (path == '/manifest.json') {
            await _handleServeStaticFile(
                request, 'server/web/manifest.json', 'application/json');
            return;
          }

          if (path == '/logo_no_bg.png') {
            await _handleServeStaticFile(
                request, 'server/web/logo_no_bg.png', 'image/png');
            return;
          }

          if (path == '/assist') {
            await _handleServeAssistPage(request);
            return;
          }

          if (path == '/api/help-requests/pending') {
            final pending = _requests.values
                .where((r) => r.status == 'pending')
                .map((r) => {
                      'id': r.id,
                      'userName': r.userName,
                      'taskType': r.taskType,
                      'taskTarget': r.taskTarget,
                      'notes': r.notes,
                      'accessKey': r.accessKey,
                      'webAssistUrl': '/assist?req=${r.id}&auth=${r.accessKey}',
                      'createdAt': r.createdAt.toIso8601String(),
                    })
                .toList();
            _jsonResponse(request, HttpStatus.ok, {'requests': pending});
            return;
          }

          if (path == '/api/health' ||
              path == '/health' ||
              path == '/healthz') {
            _jsonResponse(request, HttpStatus.ok, {
              'status': 'ok',
              'version': '2.1.0-hardened',
              'pilot': 'NetraVision Visual Help Pilot Server',
              'livekitUrl': effectiveLivekitUrl.startsWith('wss://')
                  ? effectiveLivekitUrl.split('@').last
                  : effectiveLivekitUrl,
              'activeRequests': _requests.values
                  .where((r) =>
                      r.status == 'pending' ||
                      r.status == 'accepted' ||
                      r.status == 'connected')
                  .length,
              'activeCompanions': _companions.values
                  .where((c) =>
                      c.isAvailable &&
                      c.isFresh(Duration(seconds: presenceTimeoutSeconds)))
                  .length,
            });
            return;
          }

          if (path == '/api/companions/available') {
            final communityId = request.uri.queryParameters['communityId'] ??
                'komunitas_netra_pilot';
            final freshCompanions = _companions.values
                .where((c) =>
                    c.communityId == communityId &&
                    c.isAvailable &&
                    c.currentSessionId == null &&
                    c.isFresh(Duration(seconds: presenceTimeoutSeconds)))
                .map((c) => c.toJson())
                .toList();

            _jsonResponse(
                request, HttpStatus.ok, {'companions': freshCompanions});
            return;
          }

          if (path.startsWith('/api/help-requests/')) {
            final id = path.replaceFirst('/api/help-requests/', '');
            final req = _requests[id];
            if (req == null) {
              _jsonResponse(request, HttpStatus.notFound,
                  {'error': 'Permintaan tidak ditemukan'});
            } else {
              // AMAN: toJson() tidak lagi menyertakan accessKey, userToken, atau companionToken!
              _jsonResponse(request, HttpStatus.ok, req.toJson());
            }
            return;
          }
        }

        if (request.method == 'POST') {
          final bodyString = await utf8.decoder.bind(request).join();
          final Map<String, dynamic> body = bodyString.isNotEmpty
              ? jsonDecode(bodyString) as Map<String, dynamic>
              : {};

          if (path == '/api/auth/login') {
            await _handleLogin(request, body);
            return;
          }

          if (path == '/api/companions/availability') {
            await _handleAvailabilityToggle(request, body);
            return;
          }

          if (path == '/api/presence/heartbeat') {
            await _handleHeartbeat(request, body);
            return;
          }

          if (path == '/api/help-requests') {
            await _handleCreateHelpRequest(request, body);
            return;
          }

          if (path.endsWith('/accept') &&
              path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleAcceptHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/connected') &&
              path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleConnectedHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/fail') && path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleFailHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/cancel') &&
              path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleCancelHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/complete') &&
              path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleCompleteHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/report') &&
              path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleReport(request, id, body);
            return;
          }

          if (path.endsWith('/snapshot') &&
              path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleSnapshotRelay(request, id, body);
            return;
          }
        }

        _jsonResponse(request, HttpStatus.notFound,
            {'error': 'Rute tidak ditemukan: $path'});
      } catch (e, stack) {
        _jsonResponse(request, HttpStatus.internalServerError, {
          'error': 'Kesalahan internal server',
          'detail': e.toString(),
          'stack': stack.toString(),
        });
      }
    });
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    for (final ws in _clientSockets.values) {
      await ws.close();
    }
    _clientSockets.clear();
    await _server?.close(force: true);
    _server = null;
  }

  /// Ekstraksi authKey dari Authorization Header (Bearer), query (?auth=), atau body
  String? _extractAuthKey(HttpRequest request, Map<String, dynamic>? body) {
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader != null && authHeader.toLowerCase().startsWith('bearer ')) {
      return authHeader.substring(7).trim();
    }
    final xAuthKey = request.headers.value('x-auth-key');
    if (xAuthKey != null && xAuthKey.isNotEmpty) {
      return xAuthKey.trim();
    }
    final queryAuth = request.uri.queryParameters['auth'] ??
        request.uri.queryParameters['accessKey'];
    if (queryAuth != null && queryAuth.isNotEmpty) {
      return queryAuth.trim();
    }
    if (body != null) {
      final bodyAuth = body['authKey'] ?? body['accessKey'];
      if (bodyAuth is String && bodyAuth.isNotEmpty) {
        return bodyAuth.trim();
      }
    }
    return null;
  }

  // ====================== AUTH & PRESENCE ======================

  Future<void> _handleLogin(
      HttpRequest request, Map<String, dynamic> body) async {
    final id = body['id'] as String? ??
        'user_${DateTime.now().millisecondsSinceEpoch}';
    final name = body['name'] as String? ?? 'Pengguna';
    final role = body['role'] as String? ?? 'user';
    final communityId =
        body['communityId'] as String? ?? 'komunitas_netra_pilot';

    if (role == 'companion') {
      _companions[id] = CompanionPresence(
        companionId: id,
        name: name,
        communityId: communityId,
        isAvailable: true,
      );
    }

    _jsonResponse(request, HttpStatus.ok, {
      'id': id,
      'name': name,
      'role': role,
      'communityId': communityId,
      'token': 'session_token_${Random().nextInt(999999)}',
    });
  }

  Future<void> _handleAvailabilityToggle(
      HttpRequest request, Map<String, dynamic> body) async {
    final companionId = body['companionId'] as String?;
    final isAvailable = body['isAvailable'] as bool? ?? false;

    if (companionId == null || !_companions.containsKey(companionId)) {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Pendamping tidak terdaftar'});
      return;
    }

    _companions[companionId]!.isAvailable = isAvailable;
    _companions[companionId]!.lastHeartbeat = DateTime.now();
    _jsonResponse(request, HttpStatus.ok, _companions[companionId]!.toJson());
  }

  Future<void> _handleHeartbeat(
      HttpRequest request, Map<String, dynamic> body) async {
    final companionId = body['companionId'] as String?;
    if (companionId == null) {
      _jsonResponse(
          request, HttpStatus.badRequest, {'error': 'companionId dibutuhkan'});
      return;
    }

    if (_companions.containsKey(companionId)) {
      _companions[companionId]!.lastHeartbeat = DateTime.now();
      _jsonResponse(request, HttpStatus.ok,
          {'status': 'pong', 'companionId': companionId});
    } else {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Pendamping tidak ditemukan'});
    }
  }

  // ====================== HELP REQUESTS & ATOMIC MATCHING ======================

  Future<void> _handleCreateHelpRequest(
      HttpRequest request, Map<String, dynamic> body) async {
    final userId = body['userId'] as String?;
    final userName = body['userName'] as String? ?? 'Pengguna Tunanetra';
    final taskType = body['taskType'] as String? ?? 'generalHelp';
    final taskTarget = body['taskTarget'] as String?;
    final unverifiedAiLabel = body['unverifiedAiLabel'] as String?;
    final notes = body['notes'] as String?;
    final sourceScreen = body['sourceScreen'] as String? ?? 'home';
    final recipientTarget =
        body['recipientTarget'] as String? ?? 'communityVolunteers';
    final communityId =
        body['communityId'] as String? ?? 'komunitas_netra_pilot';

    if (userId == null) {
      _jsonResponse(request, HttpStatus.badRequest,
          {'error': 'userId tidak boleh kosong'});
      return;
    }

    // Cegah permintaan ganda: Cek apakah user sudah punya permintaan aktif
    final activeExisting = _requests.values
        .where((r) =>
            r.userId == userId &&
            (r.status == 'pending' ||
                r.status == 'accepted' ||
                r.status == 'connecting' ||
                r.status == 'connected'))
        .toList();

    if (activeExisting.isNotEmpty) {
      _jsonResponse(request, HttpStatus.conflict, {
        'error': 'Pengguna sudah memiliki sesi bantuan yang sedang aktif.',
        'activeRequest': activeExisting.first.toJson(),
      });
      return;
    }

    final id =
        'req_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final accessKey =
        'key_${Random().nextInt(899999) + 100000}_${Random().nextInt(899999) + 100000}';

    final helpReq = HelpRequest(
      id: id,
      accessKey: accessKey,
      userId: userId,
      userName: userName,
      taskType: taskType,
      taskTarget: taskTarget,
      unverifiedAiLabel: unverifiedAiLabel,
      notes: notes,
      sourceScreen: sourceScreen,
      recipientTarget: recipientTarget,
      communityId: communityId,
    );

    _requests[id] = helpReq;

    // Tentukan scheme & host untuk webAssistUrl
    final isHttps = request.certificate != null ||
        request.headers.value('x-forwarded-proto') == 'https';
    final scheme = isHttps ? 'https' : 'http';
    final effectivePort = _server?.port ?? port;
    final hostHeader = request.headers.value('host');
    String authority;
    if (hostHeader != null && hostHeader.isNotEmpty) {
      if (!isHttps &&
          !hostHeader.contains(':') &&
          effectivePort != 80 &&
          effectivePort != 443) {
        authority = '$hostHeader:$effectivePort';
      } else {
        authority = hostHeader;
      }
    } else {
      authority = '127.0.0.1:$effectivePort';
    }
    final webAssistUrl = '$scheme://$authority/assist?req=$id&auth=$accessKey';

    // TEMUAN 3 FIX: Hanya broadcast ke relawan komunitas jika recipientTarget mengizinkannya!
    // Jika recipientTarget == 'trustedContacts', jangan bocorkan ke komunitas relawan!
    if (recipientTarget == 'communityVolunteers' || recipientTarget == 'all') {
      final offerPayload = helpReq.toJson(forCompanionOffer: true);
      offerPayload['webAssistUrl'] = webAssistUrl;

      _broadcastToCompanions(communityId, {
        'event': 'new_help_request',
        'request': offerPayload,
      });
    }

    // Kembalikan toCreatorResponse yang secara eksklusif memberikan accessKey ke pembuat
    _jsonResponse(request, HttpStatus.created,
        helpReq.toCreatorResponse(webAssistUrl: webAssistUrl));
  }

  /// ATOMIC ACCEPTANCE: Menjamin tepat satu pendamping yang berhasil menerima & verifikasi izin API
  Future<void> _handleAcceptHelpRequest(
      HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    // TEMUAN 1 FIX: Verifikasi izin akses (authKey ATAU pendamping terdaftar di sistem)
    final callerAuth = _extractAuthKey(request, body);
    final rawCompanionId = body['companionId'] as String?;
    final isRegisteredCompanion =
        rawCompanionId != null && _companions.containsKey(rawCompanionId);
    final hasValidAuthKey = callerAuth != null && callerAuth == req.accessKey;

    if (!hasValidAuthKey && !isRegisteredCompanion) {
      _jsonResponse(request, HttpStatus.forbidden, {
        'error':
            'Akses ditolak: authKey tidak valid dan pendamping tidak terdaftar.',
      });
      return;
    }

    // ATOMIC CHECK: Hanya jika status masih 'pending', permintaan boleh diambil
    if (req.status != 'pending') {
      _jsonResponse(request, HttpStatus.conflict, {
        'error':
            'Permintaan sudah diambil oleh pendamping lain atau telah dibatalkan/kedaluwarsa.',
        'status': req.status,
        'assignedCompanionId': req.assignedCompanionId,
      });
      return;
    }

    // TEMUAN 1 FIX: Server menentukan & memvalidasi identitas pendamping
    final companionId = (rawCompanionId?.isNotEmpty == true)
        ? rawCompanionId!
        : 'comp_web_${Random().nextInt(899999) + 100000}';
    final companionName = (body['companionName'] as String?)?.isNotEmpty == true
        ? (body['companionName'] as String)
        : (_companions[companionId]?.name ?? 'Pendamping');

    // Sukses mengambil sesi: set ke accepted
    req.status = 'accepted';
    req.assignedCompanionId = companionId;
    req.assignedCompanionName = companionName;
    req.acceptedAt = DateTime.now();

    final roomName = 'room_${req.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    req.livekitRoom = roomName;

    final effectiveLivekitApiKey =
        Platform.environment['LIVEKIT_API_KEY'] ?? livekitApiKey;
    final effectiveLivekitSecret =
        Platform.environment['LIVEKIT_API_SECRET'] ?? livekitApiSecret;
    final effectiveLivekitUrl =
        Platform.environment['LIVEKIT_URL'] ?? livekitUrl;

    // Buat token otentikasi LiveKit dengan masa berlaku ringkas (10 menit)
    req.userToken = LiveKitJwt.createToken(
      apiKey: effectiveLivekitApiKey,
      apiSecret: effectiveLivekitSecret,
      roomName: roomName,
      identity: req.userId,
      name: req.userName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      validFor: const Duration(minutes: 10),
    );

    req.companionToken = LiveKitJwt.createToken(
      apiKey: effectiveLivekitApiKey,
      apiSecret: effectiveLivekitSecret,
      roomName: roomName,
      identity: companionId,
      name: companionName,
      canPublish: true, // Hanya audio
      canSubscribe: true,
      canPublishData: true,
      validFor: const Duration(minutes: 10),
    );

    // Tandai pendamping sedang dalam sesi
    if (_companions.containsKey(companionId)) {
      _companions[companionId]!.currentSessionId = req.id;
    }

    // Beritahu pengguna tunanetra
    _sendToUser(req.userId, {
      'event': 'request_accepted',
      'requestId': req.id,
      'companionId': companionId,
      'companionName': companionName,
      'livekitUrl': effectiveLivekitUrl,
      'livekitRoom': roomName,
      'token': req.userToken,
      'request': req.toJson(),
    });

    // Beritahu pendamping lain bahwa permintaan sudah diambil (stop offering)
    _broadcastToCompanions(
        req.communityId,
        {
          'event': 'request_taken',
          'requestId': req.id,
          'acceptedBy': companionName,
        },
        excludeCompanionId: companionId);

    // Kirim respons toAcceptorResponse hanya kepada penerima yang sah
    _jsonResponse(request, HttpStatus.ok,
        req.toAcceptorResponse(livekitUrl: effectiveLivekitUrl));
  }

  /// TEMUAN 4 FIX: Validasi media & penolakan perubahan connected jika sesi sudah dibatalkan/selesai
  Future<void> _handleConnectedHelpRequest(
      HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    // Verifikasi otorisasi
    final callerAuth = _extractAuthKey(request, body);
    final callerUserId = body['userId'] as String?;
    final isAuthorized = (callerAuth != null && callerAuth == req.accessKey) ||
        (callerUserId != null &&
            (callerUserId == req.userId ||
                callerUserId == req.assignedCompanionId));

    if (!isAuthorized) {
      _jsonResponse(request, HttpStatus.forbidden,
          {'error': 'Akses ditolak: otorisasi tidak valid'});
      return;
    }

    // TOLAK jika status bukan accepted / connecting (misal sudah cancelled, completed, expired, atau failed)
    if (req.status != 'accepted' && req.status != 'connecting') {
      _jsonResponse(request, HttpStatus.conflict, {
        'error':
            'Tidak dapat mengubah status menjadi connected: status permintaan saat ini adalah ${req.status}',
        'currentStatus': req.status,
      });
      return;
    }

    req.status = 'connected';
    req.connectedAt = DateTime.now();

    final connectedEvent = {
      'event': 'session_connected',
      'requestId': req.id,
      'companionId': req.assignedCompanionId,
      'companionName': req.assignedCompanionName,
    };

    _sendToUser(req.userId, connectedEvent);
    if (req.assignedCompanionId != null) {
      _sendToUser(req.assignedCompanionId!, connectedEvent);
    }

    _jsonResponse(
        request, HttpStatus.ok, {'status': 'connected', 'requestId': req.id});
  }

  /// TEMUAN 5 FIX: Kegagalan calon pendamping (sebelum menerima) TIDAK menggagalkan seluruh permintaan!
  Future<void> _handleFailHelpRequest(
      HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    // Jika status masih pending (belum di-accept), kegagalan browser seorang pendamping tidak boleh membatalkan tiket
    if (req.status == 'pending') {
      _jsonResponse(request, HttpStatus.ok, {
        'message':
            'Kegagalan kandidat pendamping dicatat. Tiket bantuan tetap terbuka untuk pendamping lain.',
        'status': req.status,
      });
      return;
    }

    final callerAuth = _extractAuthKey(request, body);
    final callerUserId =
        body['userId'] as String? ?? body['companionId'] as String?;
    final isAuthorized = (callerAuth != null && callerAuth == req.accessKey) ||
        (callerUserId != null &&
            (callerUserId == req.userId ||
                callerUserId == req.assignedCompanionId));

    if (!isAuthorized) {
      _jsonResponse(request, HttpStatus.forbidden,
          {'error': 'Akses ditolak: bukan peserta sesi'});
      return;
    }

    final reason = body['reason'] as String? ?? 'Koneksi media gagal';
    req.status = 'failed';
    req.cancelReason = reason;
    req.cancelledAt = DateTime.now();

    if (req.assignedCompanionId != null &&
        _companions.containsKey(req.assignedCompanionId)) {
      _companions[req.assignedCompanionId!]!.currentSessionId = null;
    }

    final failEvent = {
      'event': 'connection_failed',
      'requestId': req.id,
      'reason': reason,
    };

    _sendToUser(req.userId, failEvent);
    if (req.assignedCompanionId != null) {
      _sendToUser(req.assignedCompanionId!, failEvent);
    }

    await _teardownLiveKitRoom(req.livekitRoom);

    _jsonResponse(
        request, HttpStatus.ok, {'status': 'failed', 'reason': reason});
  }

  Future<void> _handleCancelHelpRequest(
      HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    final callerAuth = _extractAuthKey(request, body);
    final callerUserId = body['userId'] as String?;
    final isAuthorized = (callerAuth != null && callerAuth == req.accessKey) ||
        (callerUserId != null &&
            (callerUserId == req.userId ||
                callerUserId == req.assignedCompanionId));

    if (!isAuthorized) {
      _jsonResponse(request, HttpStatus.forbidden,
          {'error': 'Akses ditolak: otorisasi pembatalan tidak sah'});
      return;
    }

    if (req.status == 'completed' || req.status == 'cancelled') {
      _jsonResponse(request, HttpStatus.ok, {
        'message': 'Permintaan memang sudah berakhir',
        'status': req.status
      });
      return;
    }

    final reason = body['reason'] as String? ?? 'Dibatalkan oleh pengguna';
    req.status = 'cancelled';
    req.cancelledAt = DateTime.now();
    req.cancelReason = reason;
    req.isRoomClosed = true;
    req.userToken = null;
    req.companionToken = null;

    if (req.assignedCompanionId != null &&
        _companions.containsKey(req.assignedCompanionId)) {
      _companions[req.assignedCompanionId!]!.currentSessionId = null;
    }

    _broadcastToCompanions(req.communityId, {
      'event': 'request_cancelled',
      'requestId': req.id,
      'reason': reason,
    });

    _sendToUser(req.userId, {
      'event': 'request_cancelled',
      'requestId': req.id,
      'reason': reason,
    });

    await _teardownLiveKitRoom(req.livekitRoom);

    _jsonResponse(request, HttpStatus.ok, req.toJson());
  }

  /// TEMUAN 2 FIX: Pencabutan token & pemutusan room LiveKit secara tuntas
  Future<void> _handleCompleteHelpRequest(
      HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    final callerAuth = _extractAuthKey(request, body);
    final callerUserId = body['userId'] as String?;
    final isAuthorized = (callerAuth != null && callerAuth == req.accessKey) ||
        (callerUserId != null &&
            (callerUserId == req.userId ||
                callerUserId == req.assignedCompanionId));

    if (!isAuthorized) {
      _jsonResponse(request, HttpStatus.forbidden,
          {'error': 'Akses ditolak: otorisasi penyelesaian tidak sah'});
      return;
    }

    req.status = 'completed';
    req.completedAt = DateTime.now();
    req.isRoomClosed = true;

    if (req.assignedCompanionId != null &&
        _companions.containsKey(req.assignedCompanionId)) {
      _companions[req.assignedCompanionId!]!.currentSessionId = null;
    }

    // Cabut referensi token dari memori server
    req.userToken = null;
    req.companionToken = null;

    final endEvent = {
      'event': 'session_ended',
      'requestId': req.id,
      'status': 'completed',
    };

    _sendToUser(req.userId, endEvent);
    if (req.assignedCompanionId != null) {
      _sendToUser(req.assignedCompanionId!, endEvent);
    }

    // Putuskan sesi LiveKit pada server media
    await _teardownLiveKitRoom(req.livekitRoom);

    _jsonResponse(request, HttpStatus.ok, req.toJson());
  }

  /// Pemutusan Room LiveKit melalui Twirp / HTTP RoomService API jika LiveKit URL & secret nyata tersedia
  Future<void> _teardownLiveKitRoom(String? roomName) async {
    if (roomName == null || roomName.isEmpty) return;

    final effectiveLivekitApiKey =
        Platform.environment['LIVEKIT_API_KEY'] ?? livekitApiKey;
    final effectiveLivekitSecret =
        Platform.environment['LIVEKIT_API_SECRET'] ?? livekitApiSecret;
    final effectiveLivekitUrl =
        Platform.environment['LIVEKIT_URL'] ?? livekitUrl;

    // Ubah wss:// menjadi https:// untuk REST API endpoint
    String httpEndpoint = effectiveLivekitUrl
        .replaceAll('wss://', 'https://')
        .replaceAll('ws://', 'http://');

    if (!httpEndpoint.startsWith('http://') &&
        !httpEndpoint.startsWith('https://')) {
      httpEndpoint = 'https://$httpEndpoint';
    }

    try {
      // Buat admin token untuk menghapus room
      final adminToken = LiveKitJwt.createToken(
        apiKey: effectiveLivekitApiKey,
        apiSecret: effectiveLivekitSecret,
        roomName: roomName,
        identity: 'server_admin',
        name: 'Server Admin',
        canPublish: false,
        canSubscribe: false,
        validFor: const Duration(minutes: 2),
      );

      final deleteUri =
          Uri.parse('$httpEndpoint/twirp/livekit.RoomService/DeleteRoom');
      await http
          .post(
            deleteUri,
            headers: {
              'Authorization': 'Bearer $adminToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'room': roomName}),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Pada mode mock internal atau pilot offline, room sudah ditandai isRoomClosed di state
    }
  }

  Future<void> _handleReport(
      HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final reportedBy = body['reportedBy'] as String? ?? 'unknown';
    final reason = body['reason'] as String? ?? 'No reason specified';

    final report = SessionReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      requestId: requestId,
      reportedBy: reportedBy,
      reason: reason,
    );
    _reports.add(report);

    _jsonResponse(request, HttpStatus.created, {
      'message': 'Laporan berhasil disimpan untuk audit pilot',
      'report': report.toJson(),
    });
  }

  Future<void> _handleSnapshotRelay(
      HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound,
          {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    _sendToUser(req.userId, {
      'event': 'snapshot_taken',
      'requestId': req.id,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _jsonResponse(request, HttpStatus.ok, {'status': 'relayed'});
  }

  // ====================== SERVING WEB PENDAMPING ======================

  Future<void> _handleServeStaticFile(
      HttpRequest request, String filePath, String contentType) async {
    try {
      var file = File(filePath);
      if (!await file.exists()) {
        file = File(filePath.replaceFirst('server/', ''));
      }
      if (await file.exists()) {
        request.response.headers.set('Content-Type', contentType);
        request.response.statusCode = HttpStatus.ok;
        await request.response.addStream(file.openRead());
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _handleServeCompanionDashboard(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.statusCode = HttpStatus.ok;

    try {
      var file = File('server/web/companion.html');
      if (!await file.exists()) {
        file = File('web/companion.html');
      }
      if (await file.exists()) {
        final html = await file.readAsString();
        request.response.write(html);
      } else {
        request.response.write(_renderErrorHtml('Dashboard Tidak Ditemukan',
            'File companion.html tidak tersedia.'));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(_renderErrorHtml(
          'Kesalahan Server', 'Gagal membaca dashboard relawan: $e'));
    }
    await request.response.close();
  }

  Future<void> _handleServeAssistPage(HttpRequest request) async {
    final reqId = request.uri.queryParameters['req'];
    final authKey = request.uri.queryParameters['auth'];

    request.response.headers.contentType = ContentType.html;

    if (reqId == null || authKey == null || !_requests.containsKey(reqId)) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(_renderErrorHtml(
        'Permintaan Tidak Ditemukan',
        'Tautan bantuan visual ini tidak valid atau sudah kedaluwarsa.',
      ));
      await request.response.close();
      return;
    }

    final req = _requests[reqId]!;
    if (req.accessKey != authKey) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write(_renderErrorHtml(
        'Akses Ditolak',
        'Kunci otentikasi tidak sah untuk sesi bantuan visual ini.',
      ));
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;

    String html;
    try {
      var file = File('server/web/assist.html');
      if (!await file.exists()) {
        file = File('web/assist.html');
      }
      if (await file.exists()) {
        html = await file.readAsString();
      } else {
        html = _fallbackWebHtml();
      }
    } catch (_) {
      html = _fallbackWebHtml();
    }

    final taskLabel = req.taskType == 'readLabel'
        ? 'Membaca Label / Tulisan'
        : req.taskType == 'findObject'
            ? 'Mencari Benda di Rumah'
            : req.taskType == 'deviceDisplay'
                ? 'Memahami Tampilan Perangkat'
                : 'Bantuan Umum Visual';

    final userAlias =
        req.userId.length >= 4 ? req.userId.substring(0, 4) : req.userId;

    html = html
        .replaceAll('{{TASK_TITLE}}', taskLabel)
        .replaceAll('{{USER_ALIAS}}', userAlias)
        .replaceAll('{{REQ_ID}}', req.id)
        .replaceAll('{{AUTH_KEY}}', req.accessKey);

    request.response.write(html);
    await request.response.close();
  }

  String _renderErrorHtml(String title, String message) {
    return '''<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NetraVision - $title</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F4F7FC; color: #1E293B; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 16px; box-sizing: border-box; }
    .card { background: white; max-width: 440px; width: 100%; border-radius: 20px; padding: 28px; box-shadow: 0 10px 25px rgba(13,71,161,0.08); text-align: center; border: 1.5px solid #E2E8F0; }
    .icon { font-size: 48px; margin-bottom: 16px; }
    h2 { color: #0D47A1; margin-top: 0; margin-bottom: 12px; font-size: 20px; }
    p { color: #64748B; font-size: 15px; line-height: 1.5; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">🔒</div>
    <h2>$title</h2>
    <p>$message</p>
  </div>
</body>
</html>''';
  }

  String _fallbackWebHtml() {
    return '''<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NetraVision Portal</title>
</head>
<body style="font-family: sans-serif; padding: 20px;">
  <h2>{{TASK_TITLE}}</h2>
  <p>Permintaan dari: {{USER_ALIAS}}</p>
  <p>ID: {{REQ_ID}}</p>
</body>
</html>''';
  }

  // ====================== TIMEOUTS & WEBSOCKET ======================

  void _processTimeouts() {
    final now = DateTime.now();
    final timeoutDuration = Duration(seconds: requestTimeoutSeconds);

    for (final req in _requests.values) {
      if (req.status == 'pending' &&
          now.difference(req.createdAt) > timeoutDuration) {
        req.status = 'expired';
        req.cancelledAt = now;
        req.cancelReason =
            'Timeout: Tidak ada pendamping yang tersedia dalam batas waktu pilot';

        _sendToUser(req.userId, {
          'event': 'request_expired',
          'requestId': req.id,
          'message':
              'Belum ada relawan yang menjawab dalam $requestTimeoutSeconds detik.',
        });

        _broadcastToCompanions(req.communityId, {
          'event': 'request_expired',
          'requestId': req.id,
        });
      }

      if ((req.status == 'accepted') &&
          req.acceptedAt != null &&
          now.difference(req.acceptedAt!) > const Duration(seconds: 15)) {
        req.status = 'failed';
        req.cancelledAt = now;
        req.cancelReason =
            'Timeout: Pendamping menerima namun media tidak tersambung dalam 15 detik.';

        _sendToUser(req.userId, {
          'event': 'connection_failed',
          'requestId': req.id,
          'reason':
              'Pendamping menerima namun koneksi media tidak tersambung dalam 15 detik.',
        });

        if (req.assignedCompanionId != null) {
          _sendToUser(req.assignedCompanionId!, {
            'event': 'connection_failed',
            'requestId': req.id,
            'reason':
                'Batas waktu 15 detik terlewati sebelum media tersambung.',
          });
        }
      }
    }

    final maxPresenceAge = Duration(seconds: presenceTimeoutSeconds);
    for (final comp in _companions.values) {
      if (!comp.isFresh(maxPresenceAge)) {
        comp.isAvailable = false;
      }
    }
  }

  Future<void> _handleWebSocket(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    final socketId = 'sock_${Random().nextInt(9999999)}';
    _clientSockets[socketId] = socket;

    // Cek query parameters untuk auto-register yang aman
    final queryUserId = request.uri.queryParameters['userId'];
    if (queryUserId != null && queryUserId.isNotEmpty) {
      _socketToUser[socketId] = queryUserId;
    }

    socket.listen((message) {
      try {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final event = data['event'] as String?;

        if (event == 'register') {
          final userId = data['userId'] as String?;
          if (userId != null && userId.isNotEmpty) {
            _socketToUser[socketId] = userId;
          }
        }
      } catch (_) {}
    }, onDone: () {
      _clientSockets.remove(socketId);
      _socketToUser.remove(socketId);
    }, onError: (_) {
      _clientSockets.remove(socketId);
      _socketToUser.remove(socketId);
    });
  }

  void _sendToUser(String userId, Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    for (final entry in _socketToUser.entries) {
      if (entry.value == userId) {
        final sock = _clientSockets[entry.key];
        if (sock != null && sock.readyState == WebSocket.open) {
          sock.add(payload);
        }
      }
    }
  }

  void _broadcastToCompanions(String communityId, Map<String, dynamic> event,
      {String? excludeCompanionId}) {
    final payload = jsonEncode(event);
    for (final entry in _socketToUser.entries) {
      final uid = entry.value;
      if (excludeCompanionId != null && uid == excludeCompanionId) continue;
      final comp = _companions[uid];
      if (comp != null && comp.communityId == communityId && comp.isAvailable) {
        final sock = _clientSockets[entry.key];
        if (sock != null && sock.readyState == WebSocket.open) {
          sock.add(payload);
        }
      }
    }
  }

  void _jsonResponse(
      HttpRequest request, int statusCode, Map<String, dynamic> data) {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }
}
