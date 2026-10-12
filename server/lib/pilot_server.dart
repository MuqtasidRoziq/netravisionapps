import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'livekit_jwt.dart';
import 'models/session_models.dart';

class PilotServer {
  final int port;
  final String livekitUrl;
  final String livekitApiKey;
  final String livekitApiSecret;
  final int requestTimeoutSeconds;
  final int presenceTimeoutSeconds;

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
  });

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    // ignore: avoid_print
    print('NetraVision Pilot Server berjalan di port $port');

    // Timer pembersihan berkala (timeout permintaan & presence)
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _processTimeouts();
    });

    _server!.listen((HttpRequest request) async {
      // Set CORS Headers untuk web testing / inspection
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

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

      // Handle REST API
      try {
        if (request.method == 'GET') {
          if (path == '/api/health') {
            _jsonResponse(request, HttpStatus.ok, {
              'status': 'ok',
              'version': '2.0.0',
              'pilot': 'NetraVision Visual Help Pilot Server',
              'activeRequests': _requests.values.where((r) => r.status == 'pending' || r.status == 'accepted').length,
              'activeCompanions': _companions.values.where((c) => c.isAvailable && c.isFresh(Duration(seconds: presenceTimeoutSeconds))).length,
            });
            return;
          }

          if (path == '/api/companions/available') {
            final communityId = request.uri.queryParameters['communityId'] ?? 'komunitas_netra_pilot';
            final freshCompanions = _companions.values.where((c) =>
                c.communityId == communityId &&
                c.isAvailable &&
                c.currentSessionId == null &&
                c.isFresh(Duration(seconds: presenceTimeoutSeconds))
            ).map((c) => c.toJson()).toList();

            _jsonResponse(request, HttpStatus.ok, {'companions': freshCompanions});
            return;
          }

          if (path.startsWith('/api/help-requests/')) {
            final id = path.replaceFirst('/api/help-requests/', '');
            final req = _requests[id];
            if (req == null) {
              _jsonResponse(request, HttpStatus.notFound, {'error': 'Permintaan tidak ditemukan'});
            } else {
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

          if (path.endsWith('/accept') && path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleAcceptHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/cancel') && path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleCancelHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/complete') && path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleCompleteHelpRequest(request, id, body);
            return;
          }

          if (path.endsWith('/report') && path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleReport(request, id, body);
            return;
          }

          if (path.endsWith('/snapshot') && path.contains('/api/help-requests/')) {
            final id = path.split('/')[3];
            await _handleSnapshotRelay(request, id, body);
            return;
          }
        }

        _jsonResponse(request, HttpStatus.notFound, {'error': 'Rute tidak ditemukan: $path'});
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

  // ====================== AUTH & PRESENCE ======================

  Future<void> _handleLogin(HttpRequest request, Map<String, dynamic> body) async {
    final id = body['id'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final name = body['name'] as String? ?? 'Pengguna';
    final role = body['role'] as String? ?? 'user';
    final communityId = body['communityId'] as String? ?? 'komunitas_netra_pilot';

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

  Future<void> _handleAvailabilityToggle(HttpRequest request, Map<String, dynamic> body) async {
    final companionId = body['companionId'] as String?;
    final isAvailable = body['isAvailable'] as bool? ?? false;

    if (companionId == null || !_companions.containsKey(companionId)) {
      _jsonResponse(request, HttpStatus.notFound, {'error': 'Pendamping tidak terdaftar'});
      return;
    }

    _companions[companionId]!.isAvailable = isAvailable;
    _companions[companionId]!.lastHeartbeat = DateTime.now();
    _jsonResponse(request, HttpStatus.ok, _companions[companionId]!.toJson());
  }

  Future<void> _handleHeartbeat(HttpRequest request, Map<String, dynamic> body) async {
    final companionId = body['companionId'] as String?;
    if (companionId == null) {
      _jsonResponse(request, HttpStatus.badRequest, {'error': 'companionId dibutuhkan'});
      return;
    }

    if (_companions.containsKey(companionId)) {
      _companions[companionId]!.lastHeartbeat = DateTime.now();
      _jsonResponse(request, HttpStatus.ok, {'status': 'pong', 'companionId': companionId});
    } else {
      _jsonResponse(request, HttpStatus.notFound, {'error': 'Pendamping tidak ditemukan'});
    }
  }

  // ====================== HELP REQUESTS & ATOMIC MATCHING ======================

  Future<void> _handleCreateHelpRequest(HttpRequest request, Map<String, dynamic> body) async {
    final userId = body['userId'] as String?;
    final userName = body['userName'] as String? ?? 'Pengguna Tunanetra';
    final taskType = body['taskType'] as String? ?? 'generalHelp';
    final taskTarget = body['taskTarget'] as String?;
    final unverifiedAiLabel = body['unverifiedAiLabel'] as String?;
    final notes = body['notes'] as String?;
    final sourceScreen = body['sourceScreen'] as String? ?? 'home';
    final recipientTarget = body['recipientTarget'] as String? ?? 'communityVolunteers';
    final communityId = body['communityId'] as String? ?? 'komunitas_netra_pilot';

    if (userId == null) {
      _jsonResponse(request, HttpStatus.badRequest, {'error': 'userId tidak boleh kosong'});
      return;
    }

    // Cegah permintaan ganda: Cek apakah user sudah punya permintaan aktif
    final activeExisting = _requests.values.where((r) =>
        r.userId == userId &&
        (r.status == 'pending' || r.status == 'accepted' || r.status == 'connecting' || r.status == 'connected')
    ).toList();

    if (activeExisting.isNotEmpty) {
      _jsonResponse(request, HttpStatus.conflict, {
        'error': 'Pengguna sudah memiliki sesi bantuan yang sedang aktif.',
        'activeRequest': activeExisting.first.toJson(),
      });
      return;
    }

    final id = 'req_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final helpReq = HelpRequest(
      id: id,
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

    // Broadcast ke pendamping yang memenuhi syarat ketersediaan & komunitas
    _broadcastToCompanions(communityId, {
      'event': 'new_help_request',
      'request': helpReq.toJson(forCompanionOffer: true),
    });

    _jsonResponse(request, HttpStatus.created, helpReq.toJson());
  }

  /// ATOMIC ACCEPTANCE: Menjamin tepat satu pendamping yang berhasil menerima
  Future<void> _handleAcceptHelpRequest(HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final companionId = body['companionId'] as String?;
    final companionName = body['companionName'] as String? ?? 'Pendamping';

    if (companionId == null) {
      _jsonResponse(request, HttpStatus.badRequest, {'error': 'companionId tidak boleh kosong'});
      return;
    }

    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound, {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    // ATOMIC CHECK: Hanya jika status masih 'pending', permintaan boleh diambil
    if (req.status != 'pending') {
      _jsonResponse(request, HttpStatus.conflict, {
        'error': 'Permintaan sudah diambil oleh pendamping lain atau telah dibatalkan/kedaluwarsa.',
        'status': req.status,
        'assignedCompanionId': req.assignedCompanionId,
      });
      return;
    }

    // Sukses mengambil sesi
    req.status = 'accepted';
    req.assignedCompanionId = companionId;
    req.assignedCompanionName = companionName;
    req.acceptedAt = DateTime.now();

    final roomName = 'room_${req.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    req.livekitRoom = roomName;

    // Buat token otentikasi LiveKit dengan batasan hak akses minimum
    // Pengguna: Publish kamera & mikrofon, subscribe audio pendamping
    req.userToken = LiveKitJwt.createToken(
      apiKey: livekitApiKey,
      apiSecret: livekitApiSecret,
      roomName: roomName,
      identity: req.userId,
      name: req.userName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    );

    // Pendamping: Publish mikrofon saja (kamera pendamping tidak perlu), subscribe kamera pengguna
    req.companionToken = LiveKitJwt.createToken(
      apiKey: livekitApiKey,
      apiSecret: livekitApiSecret,
      roomName: roomName,
      identity: companionId,
      name: companionName,
      canPublish: true, // Hanya untuk track audio
      canSubscribe: true,
      canPublishData: true,
    );

    // Tandai pendamping sedang dalam sesi
    if (_companions.containsKey(companionId)) {
      _companions[companionId]!.currentSessionId = req.id;
    }

    // Beritahu pengguna bahwa bantuan telah diterima pendamping
    _sendToUser(req.userId, {
      'event': 'request_accepted',
      'requestId': req.id,
      'companionId': companionId,
      'companionName': companionName,
      'livekitUrl': livekitUrl,
      'livekitRoom': roomName,
      'token': req.userToken,
      'request': req.toJson(),
    });

    // Beritahu pendamping lain bahwa permintaan sudah diambil (stop offering)
    _broadcastToCompanions(req.communityId, {
      'event': 'request_taken',
      'requestId': req.id,
      'acceptedBy': companionName,
    }, excludeCompanionId: companionId);

    _jsonResponse(request, HttpStatus.ok, {
      'message': 'Permintaan berhasil diterima secara atomik.',
      'livekitUrl': livekitUrl,
      'livekitRoom': roomName,
      'token': req.companionToken,
      'request': req.toJson(),
    });
  }

  Future<void> _handleCancelHelpRequest(HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final userId = body['userId'] as String?;
    final reason = body['reason'] as String? ?? 'Dibatalkan oleh pengguna';

    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound, {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    if (req.status == 'completed' || req.status == 'cancelled') {
      _jsonResponse(request, HttpStatus.ok, {'message': 'Permintaan memang sudah berakhir', 'status': req.status});
      return;
    }

    req.status = 'cancelled';
    req.cancelledAt = DateTime.now();
    req.cancelReason = reason;

    if (req.assignedCompanionId != null && _companions.containsKey(req.assignedCompanionId)) {
      _companions[req.assignedCompanionId!]!.currentSessionId = null;
    }

    // Broadcast pembatalan ke pendamping
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

    _jsonResponse(request, HttpStatus.ok, req.toJson());
  }

  Future<void> _handleCompleteHelpRequest(HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound, {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    req.status = 'completed';
    req.completedAt = DateTime.now();

    if (req.assignedCompanionId != null && _companions.containsKey(req.assignedCompanionId)) {
      _companions[req.assignedCompanionId!]!.currentSessionId = null;
    }

    // Cabut token dari memori server
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

    _jsonResponse(request, HttpStatus.ok, req.toJson());
  }

  Future<void> _handleReport(HttpRequest request, String requestId, Map<String, dynamic> body) async {
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
      'message': 'Laporan berhasil dicatat untuk evaluasi pengelola pilot.',
      'report': report.toJson(),
    });
  }

  Future<void> _handleSnapshotRelay(HttpRequest request, String requestId, Map<String, dynamic> body) async {
    final req = _requests[requestId];
    if (req == null) {
      _jsonResponse(request, HttpStatus.notFound, {'error': 'Permintaan tidak ditemukan'});
      return;
    }

    final action = body['action'] as String? ?? 'request';

    if (action == 'request') {
      _sendToUser(req.userId, {
        'event': 'snapshot_requested',
        'requestId': req.id,
        'companionId': req.assignedCompanionId,
      });
    } else if (action == 'granted') {
      if (req.assignedCompanionId != null) {
        _sendToUser(req.assignedCompanionId!, {
          'event': 'snapshot_granted',
          'requestId': req.id,
        });
      }
    }

    _jsonResponse(request, HttpStatus.ok, {'status': 'relayed', 'action': action});
  }

  // ====================== TIMEOUTS & EXPIRATIONS ======================

  void _processTimeouts() {
    final now = DateTime.now();
    final timeoutDuration = Duration(seconds: requestTimeoutSeconds);

    for (final req in _requests.values) {
      if (req.status == 'pending' && now.difference(req.createdAt) > timeoutDuration) {
        req.status = 'expired';
        req.cancelledAt = now;
        req.cancelReason = 'Timeout: Tidak ada pendamping yang tersedia dalam batas waktu pilot';

        _sendToUser(req.userId, {
          'event': 'request_expired',
          'requestId': req.id,
          'message': 'Belum ada relawan yang menjawab dalam $requestTimeoutSeconds detik.',
        });

        _broadcastToCompanions(req.communityId, {
          'event': 'request_expired',
          'requestId': req.id,
        });
      }
    }

    // Refresh presence stale
    final maxPresenceAge = Duration(seconds: presenceTimeoutSeconds);
    for (final comp in _companions.values) {
      if (!comp.isFresh(maxPresenceAge)) {
        comp.isAvailable = false;
      }
    }
  }

  // ====================== WEBSOCKET HANDLING ======================

  Future<void> _handleWebSocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    final userId = request.uri.queryParameters['userId'];
    final role = request.uri.queryParameters['role'] ?? 'user';
    final communityId = request.uri.queryParameters['communityId'] ?? 'komunitas_netra_pilot';

    if (userId != null) {
      _clientSockets[userId] = socket;
      _socketToUser[socket.hashCode.toString()] = userId;

      if (role == 'companion') {
        _companions.putIfAbsent(userId, () => CompanionPresence(
          companionId: userId,
          name: request.uri.queryParameters['userName'] ?? 'Pendamping',
          communityId: communityId,
        )).isAvailable = true;
      }
    }

    socket.listen(
      (data) {
        // Ping/Pong atau sinyal custom jika diperlukan
        try {
          final msg = jsonDecode(data.toString()) as Map<String, dynamic>;
          if (msg['type'] == 'ping' && userId != null && _companions.containsKey(userId)) {
            _companions[userId]!.lastHeartbeat = DateTime.now();
            socket.add(jsonEncode({'type': 'pong'}));
          }
        } catch (_) {}
      },
      onDone: () {
        if (userId != null) {
          _clientSockets.remove(userId);
          if (role == 'companion' && _companions.containsKey(userId)) {
            _companions[userId]!.isAvailable = false;
          }
        }
      },
      onError: (_) {
        if (userId != null) {
          _clientSockets.remove(userId);
        }
      },
    );
  }

  void _sendToUser(String userId, Map<String, dynamic> data) {
    final socket = _clientSockets[userId];
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(data));
    }
  }

  void _broadcastToCompanions(String communityId, Map<String, dynamic> data, {String? excludeCompanionId}) {
    for (final companion in _companions.values) {
      if (companion.communityId == communityId && companion.companionId != excludeCompanionId) {
        _sendToUser(companion.companionId, data);
      }
    }
  }

  void _jsonResponse(HttpRequest request, int statusCode, Map<String, dynamic> data) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data))
      ..close();
  }
}
