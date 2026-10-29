/// Model data dan state machine untuk sesi Bantuan Visual NetraVision V2
library;

class HelpRequest {
  final String id;
  final String accessKey;
  final String userId;
  final String userName;
  final String taskType;
  final String? taskTarget;
  final String? unverifiedAiLabel;
  final String? notes;
  final String sourceScreen;
  final String recipientTarget;
  final String communityId;
  String status; // pending, accepted, connecting, connected, reconnecting, cancelled, expired, failed, completed
  String? assignedCompanionId;
  String? assignedCompanionName;
  String? livekitRoom;
  String? userToken;
  String? companionToken;
  bool isRoomClosed;
  final DateTime createdAt;
  DateTime? acceptedAt;
  DateTime? connectedAt;
  DateTime? completedAt;
  DateTime? cancelledAt;
  String? cancelReason;

  HelpRequest({
    required this.id,
    required this.accessKey,
    required this.userId,
    required this.userName,
    required this.taskType,
    this.taskTarget,
    this.unverifiedAiLabel,
    this.notes,
    required this.sourceScreen,
    required this.recipientTarget,
    required this.communityId,
    this.status = 'pending',
    this.assignedCompanionId,
    this.assignedCompanionName,
    this.livekitRoom,
    this.userToken,
    this.companionToken,
    this.isRoomClosed = false,
    DateTime? createdAt,
    this.acceptedAt,
    this.connectedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Detail publik yang aman: TIDAK MEMBOCORKAN accessKey, userToken, atau companionToken!
  Map<String, dynamic> toJson({bool forCompanionOffer = false}) {
    if (forCompanionOffer) {
      return {
        'id': id,
        'taskType': taskType,
        'taskTarget': taskTarget,
        'unverifiedAiLabel': unverifiedAiLabel,
        'recipientTarget': recipientTarget,
        'communityId': communityId,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'requesterAlias': 'Pengguna Komunitas (\)',
      };
    }

    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'taskType': taskType,
      'taskTarget': taskTarget,
      'unverifiedAiLabel': unverifiedAiLabel,
      'notes': notes,
      'sourceScreen': sourceScreen,
      'recipientTarget': recipientTarget,
      'communityId': communityId,
      'status': status,
      'assignedCompanionId': assignedCompanionId,
      'assignedCompanionName': assignedCompanionName,
      'livekitRoom': livekitRoom,
      'isRoomClosed': isRoomClosed,
      'createdAt': createdAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'connectedAt': connectedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelReason': cancelReason,
    };
  }

  /// Khusus untuk respon pembuatan sesi ke pembuat (pengguna tunanetra)
  Map<String, dynamic> toCreatorResponse({required String webAssistUrl}) {
    final data = toJson();
    data['accessKey'] = accessKey;
    data['webAssistUrl'] = webAssistUrl;
    if (userToken != null) {
      data['token'] = userToken;
    }
    return data;
  }

  /// Khusus untuk respon penerimaan sesi ke pendamping terverifikasi
  Map<String, dynamic> toAcceptorResponse({required String livekitUrl}) {
    return {
      'message': 'Permintaan berhasil diterima secara atomik.',
      'id': id,
      'status': status,
      'livekitUrl': livekitUrl,
      'livekitRoom': livekitRoom,
      'token': companionToken,
      'request': toJson(),
    };
  }
}

class CompanionPresence {
  final String companionId;
  final String name;
  final String communityId;
  bool isAvailable;
  String? currentSessionId;
  DateTime lastHeartbeat;

  CompanionPresence({
    required this.companionId,
    required this.name,
    required this.communityId,
    this.isAvailable = true,
    this.currentSessionId,
    DateTime? lastHeartbeat,
  }) : lastHeartbeat = lastHeartbeat ?? DateTime.now();

  bool isFresh(Duration maxAge) {
    return DateTime.now().difference(lastHeartbeat) <= maxAge;
  }

  Map<String, dynamic> toJson() => {
    'companionId': companionId,
    'name': name,
    'communityId': communityId,
    'isAvailable': isAvailable,
    'currentSessionId': currentSessionId,
    'lastHeartbeat': lastHeartbeat.toIso8601String(),
  };
}

class SessionReport {
  final String id;
  final String requestId;
  final String reportedBy;
  final String reason;
  final DateTime createdAt;

  SessionReport({
    required this.id,
    required this.requestId,
    required this.reportedBy,
    required this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'requestId': requestId,
    'reportedBy': reportedBy,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };
}
