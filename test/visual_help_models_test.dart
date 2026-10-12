import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/data/models/visual_help_models.dart';

void main() {
  group('Visual Help Models & Context Tests', () {
    test('TaskType memetakan kode dan label secara konsisten', () {
      expect(TaskType.findObject.label, 'Mencari Benda di Rumah');
      expect(TaskType.readLabel.label, 'Membaca Label / Tulisan');
      expect(TaskType.deviceDisplay.label, 'Memahami Tampilan Perangkat');
      expect(TaskType.generalHelp.label, 'Bantuan Umum Visual');

      expect(TaskTypeExtension.fromCode('findObject'), TaskType.findObject);
      expect(TaskTypeExtension.fromCode('readLabel'), TaskType.readLabel);
      expect(TaskTypeExtension.fromCode('deviceDisplay'), TaskType.deviceDisplay);
      expect(TaskTypeExtension.fromCode('other'), TaskType.generalHelp);
    });

    test('TaskContext mempertahankan label AI belum diverifikasi dan membuat teks audio yang jujur', () {
      const context = TaskContext(
        taskType: TaskType.readLabel,
        targetName: 'Kemasan Obat Batuk',
        unverifiedAiLabel: 'botol',
        notes: 'Periksa tanggal kedaluwarsa',
        sourceScreen: 'detector_indoor',
      );

      final json = context.toJson();
      expect(json['taskType'], 'readLabel');
      expect(json['taskTarget'], 'Kemasan Obat Batuk');
      expect(json['unverifiedAiLabel'], 'botol');
      expect(json['sourceScreen'], 'detector_indoor');

      final reconstructed = TaskContext.fromJson(json);
      expect(reconstructed.taskType, TaskType.readLabel);
      expect(reconstructed.targetName, 'Kemasan Obat Batuk');
      expect(reconstructed.unverifiedAiLabel, 'botol');

      final spoken = context.toSpokenText();
      expect(spoken, contains('Membaca Label / Tulisan'));
      expect(spoken, contains('Kemasan Obat Batuk'));
      expect(spoken, contains('belum diverifikasi'));
      expect(spoken, contains('botol'));
    });

    test('RecipientTarget memetakan jalur komunitas dan kontak tepercaya', () {
      expect(RecipientTarget.communityVolunteers.label, 'Relawan Komunitas');
      expect(RecipientTarget.trustedContacts.label, 'Kontak Tepercaya');

      expect(RecipientTargetExtension.fromCode('trustedContacts'), RecipientTarget.trustedContacts);
      expect(RecipientTargetExtension.fromCode('communityVolunteers'), RecipientTarget.communityVolunteers);
    });

    test('HelpSessionState mencakup status penanganan panggilan', () {
      expect(HelpSessionStateExtension.fromString('pending'), HelpSessionState.pending);
      expect(HelpSessionStateExtension.fromString('accepted'), HelpSessionState.accepted);
      expect(HelpSessionStateExtension.fromString('connecting'), HelpSessionState.connecting);
      expect(HelpSessionStateExtension.fromString('connected'), HelpSessionState.connected);
      expect(HelpSessionStateExtension.fromString('cancelled'), HelpSessionState.cancelled);
      expect(HelpSessionStateExtension.fromString('expired'), HelpSessionState.expired);
      expect(HelpSessionStateExtension.fromString('completed'), HelpSessionState.completed);
    });

    test('TrustedContact serialisasi dan deserialisasi', () {
      const contact = TrustedContact(
        id: 'c1',
        name: 'Kakak Pertama',
        phoneNumber: '08123456789',
        relationship: 'Keluarga',
        isWhatsAppAvailable: true,
      );

      final json = contact.toJson();
      final fromJson = TrustedContact.fromJson(json);

      expect(fromJson.id, 'c1');
      expect(fromJson.name, 'Kakak Pertama');
      expect(fromJson.phoneNumber, '08123456789');
      expect(fromJson.relationship, 'Keluarga');
      expect(fromJson.isWhatsAppAvailable, true);
    });
  });
}
