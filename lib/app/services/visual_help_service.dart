import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/visual_help_models.dart';

class VisualHelpService extends GetxService {
  static const String _serverUrlKey = 'netravision_pilot_server_url';
  static const String _userRoleKey = 'netravision_active_role';
  static const String _userIdKey = 'netravision_user_id';
  static const String _userNameKey = 'netravision_user_name';

  // Alamat default: 10.0.2.2 untuk Android emulator, 127.0.0.1 untuk desktop/pengujian lokal
  final RxString serverBaseUrl = 'http://127.0.0.1:8080'.obs;
  final RxString currentRole = 'user'.obs; // 'user' (tunanetra) atau 'companion' (relawan)
  final RxString currentUserId = ''.obs;
  final RxString currentUserName = ''.obs;
  final RxString communityId = 'komunitas_netra_pilot'.obs;

  // Status ketersediaan relawan
  final RxBool isCompanionAvailable = true.obs;

  // Sesi aktif saat ini
  final Rx<VisualHelpRequestModel?> activeRequest = Rx<VisualHelpRequestModel?>(null);

  // Daftar permintaan masuk (khusus peran pendamping)
  final RxList<VisualHelpRequestModel> incomingRequests = <VisualHelpRequestModel>[].obs;

  WebSocket? _webSocket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  // Callback listener untuk notifikasi event realtime
  Function(Map<String, dynamic> event)? onSocketEvent;

  Future<VisualHelpService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_serverUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      serverBaseUrl.value = savedUrl;
    } else {
      // Deteksi platform: jika bukan android/ios (mis. Windows / Linux desktop saat dev), gunakan 127.0.0.1
      serverBaseUrl.value = 'http://127.0.0.1:8080';
    }

    currentRole.value = prefs.getString(_userRoleKey) ?? 'user';
    currentUserId.value = prefs.getString(_userIdKey) ??
        'usr_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    currentUserName.value = prefs.getString(_userNameKey) ??
        (currentRole.value == 'companion' ? 'Relawan Netra' : 'Pengguna Netra');

    // Hubungkan WebSocket untuk notifikasi real-time
    await connectWebSocket();

    // Start heartbeat jika peran adalah companion
    if (currentRole.value == 'companion') {
      _startHeartbeat();
    }

    return this;
  }

  Future<void> updateServerUrl(String url) async {
    serverBaseUrl.value = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, serverBaseUrl.value);
    await connectWebSocket();
  }

  Future<void> switchRole(String newRole) async {
    currentRole.value = newRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, newRole);

    if (newRole == 'companion') {
      _startHeartbeat();
    } else {
      _heartbeatTimer?.cancel();
    }

    await connectWebSocket();
  }

  Future<void> updateProfile({required String name, required String id}) async {
    currentUserName.value = name;
    currentUserId.value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userIdKey, id);
    await connectWebSocket();
  }

  // ====================== WEBSOCKET HANDLING ======================

  Future<void> connectWebSocket() async {
    try {
      await _webSocket?.close();
      final base = Uri.parse(serverBaseUrl.value);
      final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = base.replace(
        scheme: wsScheme,
        path: '/ws',
        queryParameters: {
          'userId': currentUserId.value,
          'userName': currentUserName.value,
          'role': currentRole.value,
          'communityId': communityId.value,
        },
      );

      _webSocket = await WebSocket.connect(wsUri.toString())
          .timeout(const Duration(seconds: 4));

      _webSocket!.listen(
        (data) => _handleSocketMessage(data.toString()),
        onDone: () => _scheduleReconnect(),
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connectWebSocket();
    });
  }

  void _handleSocketMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final event = data['event'] as String?;

      if (event == 'new_help_request') {
        final reqJson = data['request'] as Map<String, dynamic>;
        final req = VisualHelpRequestModel.fromJson(reqJson);
        if (!incomingRequests.any((r) => r.id == req.id)) {
          incomingRequests.insert(0, req);
        }
      } else if (event == 'request_taken' || event == 'request_cancelled' || event == 'request_expired') {
        final reqId = data['requestId'] as String?;
        if (reqId != null) {
          incomingRequests.removeWhere((r) => r.id == reqId);
        }

        if (activeRequest.value?.id == reqId) {
          if (event == 'request_cancelled') {
            activeRequest.value?.status = HelpSessionState.cancelled;
          } else if (event == 'request_expired') {
            activeRequest.value?.status = HelpSessionState.expired;
          }
          activeRequest.refresh();
        }
      } else if (event == 'request_accepted') {
        final reqJson = data['request'] as Map<String, dynamic>?;
        if (reqJson != null) {
          final acceptedReq = VisualHelpRequestModel.fromJson(reqJson);
          acceptedReq.livekitToken = data['token'] as String?;
          acceptedReq.assignedCompanionName = data['companionName'] as String?;
          acceptedReq.assignedCompanionId = data['companionId'] as String?;
          activeRequest.value = acceptedReq;
        }
      } else if (event == 'session_ended') {
        if (activeRequest.value != null) {
          activeRequest.value!.status = HelpSessionState.completed;
          activeRequest.refresh();
        }
      }

      onSocketEvent?.call(data);
    } catch (_) {}
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (currentRole.value == 'companion') {
        try {
          final uri = Uri.parse('${serverBaseUrl.value}/api/presence/heartbeat');
          await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'companionId': currentUserId.value}),
          ).timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    });
  }

  // ====================== REST API CALLS ======================

  Future<VisualHelpRequestModel?> createHelpRequest({
    required TaskContext taskContext,
    required RecipientTarget recipientTarget,
  }) async {
    final uri = Uri.parse('${serverBaseUrl.value}/api/help-requests');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': currentUserId.value,
          'userName': currentUserName.value,
          'taskType': taskContext.taskType.shortCode,
          'taskTarget': taskContext.targetName,
          'unverifiedAiLabel': taskContext.unverifiedAiLabel,
          'notes': taskContext.notes,
          'sourceScreen': taskContext.sourceScreen,
          'recipientTarget': recipientTarget.code,
          'communityId': communityId.value,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 201) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final req = VisualHelpRequestModel.fromJson(json);
        activeRequest.value = req;
        return req;
      } else if (res.statusCode == 409) {
        // Sudah ada sesi aktif
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json.containsKey('activeRequest')) {
          final req = VisualHelpRequestModel.fromJson(json['activeRequest'] as Map<String, dynamic>);
          activeRequest.value = req;
          return req;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> cancelHelpRequest(String requestId, {String? reason}) async {
    final uri = Uri.parse('${serverBaseUrl.value}/api/help-requests/$requestId/cancel');
    final authKey = activeRequest.value?.accessKey;
    try {
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (authKey != null) 'X-Auth-Key': authKey,
        },
        body: jsonEncode({
          'userId': currentUserId.value,
          if (authKey != null) 'authKey': authKey,
          'reason': reason ?? 'Dibatalkan oleh pengguna',
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        if (activeRequest.value?.id == requestId) {
          activeRequest.value?.status = HelpSessionState.cancelled;
          activeRequest.refresh();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// ATOMIC ACCEPTANCE: Relawan mengambil sesi bantuan
  Future<Map<String, dynamic>> acceptHelpRequest(String requestId) async {
    final uri = Uri.parse('${serverBaseUrl.value}/api/help-requests/$requestId/accept');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'companionId': currentUserId.value,
          'companionName': currentUserName.value,
        }),
      ).timeout(const Duration(seconds: 5));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final reqJson = json['request'] as Map<String, dynamic>;
        final req = VisualHelpRequestModel.fromJson(reqJson);
        req.livekitToken = json['token'] as String?;
        activeRequest.value = req;
        incomingRequests.removeWhere((r) => r.id == requestId);
        return {'success': true, 'request': req, 'token': json['token']};
      } else if (res.statusCode == 409) {
        // Sudah diambil oleh orang lain
        incomingRequests.removeWhere((r) => r.id == requestId);
        return {'success': false, 'error': json['error'] ?? 'Sesi sudah diambil oleh relawan lain.'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Gagal menghubungkan ke server: $e'};
    }
    return {'success': false, 'error': 'Gagal memproses penerimaan sesi.'};
  }

  Future<bool> completeHelpRequest(String requestId) async {
    final uri = Uri.parse('${serverBaseUrl.value}/api/help-requests/$requestId/complete');
    final authKey = activeRequest.value?.accessKey;
    try {
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (authKey != null) 'X-Auth-Key': authKey,
        },
        body: jsonEncode({
          'userId': currentUserId.value,
          if (authKey != null) 'authKey': authKey,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        if (activeRequest.value?.id == requestId) {
          activeRequest.value?.status = HelpSessionState.completed;
          activeRequest.refresh();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> reportSession(String requestId, String reason) async {
    final uri = Uri.parse('${serverBaseUrl.value}/api/help-requests/$requestId/report');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportedBy': currentUserId.value,
          'reason': reason,
        }),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 201;
    } catch (_) {}
    return false;
  }

  Future<void> toggleCompanionAvailability(bool available) async {
    isCompanionAvailable.value = available;
    final uri = Uri.parse('${serverBaseUrl.value}/api/companions/availability');
    try {
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'companionId': currentUserId.value,
          'isAvailable': available,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> requestSnapshot(String requestId) async {
    final uri = Uri.parse('${serverBaseUrl.value}/api/help-requests/$requestId/snapshot');
    try {
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'request'}),
      );
    } catch (_) {}
  }

  @override
  void onClose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _webSocket?.close();
    super.onClose();
  }
}
