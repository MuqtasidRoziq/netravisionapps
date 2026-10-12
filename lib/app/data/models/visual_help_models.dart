import 'dart:typed_data';

/// Jenis tugas visual yang dihadapi pengguna tunanetra
enum TaskType {
  findObject,
  readLabel,
  deviceDisplay,
  generalHelp,
}

extension TaskTypeExtension on TaskType {
  String get label {
    switch (this) {
      case TaskType.findObject:
        return 'Mencari Benda di Rumah';
      case TaskType.readLabel:
        return 'Membaca Label / Tulisan';
      case TaskType.deviceDisplay:
        return 'Memahami Tampilan Perangkat';
      case TaskType.generalHelp:
        return 'Bantuan Umum Visual';
    }
  }

  String get shortCode {
    switch (this) {
      case TaskType.findObject:
        return 'findObject';
      case TaskType.readLabel:
        return 'readLabel';
      case TaskType.deviceDisplay:
        return 'deviceDisplay';
      case TaskType.generalHelp:
        return 'generalHelp';
    }
  }

  static TaskType fromCode(String code) {
    switch (code) {
      case 'findObject':
        return TaskType.findObject;
      case 'readLabel':
        return TaskType.readLabel;
      case 'deviceDisplay':
        return TaskType.deviceDisplay;
      default:
        return TaskType.generalHelp;
    }
  }
}

/// Jalur penerima permintaan bantuan
enum RecipientTarget {
  communityVolunteers,
  trustedContacts,
}

extension RecipientTargetExtension on RecipientTarget {
  String get label {
    switch (this) {
      case RecipientTarget.communityVolunteers:
        return 'Relawan Komunitas';
      case RecipientTarget.trustedContacts:
        return 'Kontak Tepercaya';
    }
  }

  String get code {
    switch (this) {
      case RecipientTarget.communityVolunteers:
        return 'communityVolunteers';
      case RecipientTarget.trustedContacts:
        return 'trustedContacts';
    }
  }

  static RecipientTarget fromCode(String code) {
    if (code == 'trustedContacts') {
      return RecipientTarget.trustedContacts;
    }
    return RecipientTarget.communityVolunteers;
  }
}

/// Status lifecycle sesi bantuan visual
enum HelpSessionState {
  pending,
  accepted,
  connecting,
  connected,
  reconnecting,
  cancelled,
  expired,
  failed,
  completed,
}

extension HelpSessionStateExtension on HelpSessionState {
  String get description {
    switch (this) {
      case HelpSessionState.pending:
        return 'Menunggu relawan menerima permintaan...';
      case HelpSessionState.accepted:
        return 'Permintaan diterima oleh relawan.';
      case HelpSessionState.connecting:
        return 'Menghubungkan kamera dan audio dua arah...';
      case HelpSessionState.connected:
        return 'Terhubung langsung dengan pendamping.';
      case HelpSessionState.reconnecting:
        return 'Menyambungkan kembali koneksi...';
      case HelpSessionState.cancelled:
        return 'Permintaan bantuan dibatalkan.';
      case HelpSessionState.expired:
        return 'Batas waktu pencarian relawan habis.';
      case HelpSessionState.failed:
        return 'Gagal menghubungkan sesi media.';
      case HelpSessionState.completed:
        return 'Sesi bantuan selesai.';
    }
  }

  static HelpSessionState fromString(String val) {
    switch (val) {
      case 'accepted':
        return HelpSessionState.accepted;
      case 'connecting':
        return HelpSessionState.connecting;
      case 'connected':
        return HelpSessionState.connected;
      case 'reconnecting':
        return HelpSessionState.reconnecting;
      case 'cancelled':
        return HelpSessionState.cancelled;
      case 'expired':
        return HelpSessionState.expired;
      case 'failed':
        return HelpSessionState.failed;
      case 'completed':
        return HelpSessionState.completed;
      default:
        return HelpSessionState.pending;
    }
  }
}

/// Konteks tugas yang dibawa dari aktivitas pengguna
class TaskContext {
  final TaskType taskType;
  final String? targetName;
  final String? unverifiedAiLabel;
  final String? notes;
  final String sourceScreen;

  const TaskContext({
    required this.taskType,
    this.targetName,
    this.unverifiedAiLabel,
    this.notes,
    this.sourceScreen = 'home',
  });

  Map<String, dynamic> toJson() => {
    'taskType': taskType.shortCode,
    'taskTarget': targetName,
    'unverifiedAiLabel': unverifiedAiLabel,
    'notes': notes,
    'sourceScreen': sourceScreen,
  };

  factory TaskContext.fromJson(Map<String, dynamic> json) => TaskContext(
    taskType: TaskTypeExtension.fromCode(json['taskType'] as String? ?? 'generalHelp'),
    targetName: json['taskTarget'] as String?,
    unverifiedAiLabel: json['unverifiedAiLabel'] as String?,
    notes: json['notes'] as String?,
    sourceScreen: json['sourceScreen'] as String? ?? 'home',
  );

  /// Menghasilkan deskripsi yang jelas dan dapat dibacakan TTS
  String toSpokenText() {
    final buffer = StringBuffer('Kebutuhan: ${taskType.label}. ');
    if (targetName != null && targetName!.trim().isNotEmpty) {
      buffer.write('Target: $targetName. ');
    }
    if (unverifiedAiLabel != null && unverifiedAiLabel!.trim().isNotEmpty) {
      buffer.write('Deteksi AI (belum diverifikasi): $unverifiedAiLabel. ');
    }
    return buffer.toString();
  }
}

/// Model permintaan bantuan visual di sisi klien
class VisualHelpRequestModel {
  final String id;
  final String userId;
  final String userName;
  final TaskContext taskContext;
  final RecipientTarget recipientTarget;
  final String communityId;
  HelpSessionState status;
  String? assignedCompanionId;
  String? assignedCompanionName;
  String? livekitRoom;
  String? livekitToken;
  final DateTime createdAt;

  VisualHelpRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.taskContext,
    required this.recipientTarget,
    required this.communityId,
    required this.status,
    this.assignedCompanionId,
    this.assignedCompanionName,
    this.livekitRoom,
    this.livekitToken,
    required this.createdAt,
  });

  factory VisualHelpRequestModel.fromJson(Map<String, dynamic> json) {
    return VisualHelpRequestModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Pengguna Tunanetra',
      taskContext: TaskContext.fromJson(json),
      recipientTarget: RecipientTargetExtension.fromCode(json['recipientTarget'] as String? ?? 'communityVolunteers'),
      communityId: json['communityId'] as String? ?? 'komunitas_netra_pilot',
      status: HelpSessionStateExtension.fromString(json['status'] as String? ?? 'pending'),
      assignedCompanionId: json['assignedCompanionId'] as String?,
      assignedCompanionName: json['assignedCompanionName'] as String?,
      livekitRoom: json['livekitRoom'] as String?,
      livekitToken: json['token'] as String? ?? json['userToken'] as String? ?? json['companionToken'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Model kontak tepercaya lokal untuk opsi fallback panggilan langsung
class TrustedContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String relationship;
  final bool isWhatsAppAvailable;

  const TrustedContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
    this.isWhatsAppAvailable = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'relationship': relationship,
    'isWhatsAppAvailable': isWhatsAppAvailable,
  };

  factory TrustedContact.fromJson(Map<String, dynamic> json) => TrustedContact(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] as String? ?? 'Kontak',
    phoneNumber: json['phoneNumber'] as String? ?? '',
    relationship: json['relationship'] as String? ?? 'Keluarga',
    isWhatsAppAvailable: json['isWhatsAppAvailable'] as bool? ?? true,
  );
}

/// Model cuplikan frame sementara di sisi pendamping (hanya di memori volatile)
class SessionSnapshot {
  final String id;
  final DateTime timestamp;
  final Uint8List imageBytes;
  final int width;
  final int height;

  SessionSnapshot({
    required this.id,
    required this.timestamp,
    required this.imageBytes,
    required this.width,
    required this.height,
  });
}
