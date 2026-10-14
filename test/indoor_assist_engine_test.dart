import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/indoor_assist_engine.dart';

IndoorObservation observation(
  String label,
  Rect box, {
  double confidence = 0.80,
}) {
  return IndoorObservation(label: label, confidence: confidence, box: box);
}

void main() {
  group('IndoorAssistEngine analisis risiko', () {
    test('kursi dekat di tengah menjadi peringatan jalur', () {
      final scene = IndoorAssistEngine.analyze([
        observation('kursi', const Rect.fromLTRB(0.35, 0.35, 0.65, 0.80)),
      ]);

      expect(scene.primaryHazard, isNotNull);
      expect(scene.primaryHazard!.risk, IndoorRiskLevel.warning);
      expect(scene.primaryHazard!.direction, IndoorDirection.depan);
      expect(
        IndoorAssistEngine.warningSpeech(scene.primaryHazard!),
        contains('Hati-hati'),
      );
    });

    test('rintangan yang memenuhi frame menjadi peringatan berhenti', () {
      final scene = IndoorAssistEngine.analyze([
        observation('orang', const Rect.fromLTRB(0.12, 0.05, 0.88, 0.98)),
      ]);

      expect(scene.primaryHazard!.risk, IndoorRiskLevel.critical);
      expect(
        IndoorAssistEngine.warningSpeech(scene.primaryHazard!),
        startsWith('Berhenti.'),
      );
    });

    test('kursi di sisi frame tidak diklaim menghalangi jalur', () {
      final scene = IndoorAssistEngine.analyze([
        observation('kursi', const Rect.fromLTRB(0.02, 0.30, 0.25, 0.90)),
      ]);

      expect(scene.primaryHazard, isNull);
      expect(scene.targets.single.direction, IndoorDirection.kiri);
      expect(scene.targets.single.risk, IndoorRiskLevel.none);
    });

    test('objek kecil non-mobilitas tidak memicu alarm', () {
      final scene = IndoorAssistEngine.analyze([
        observation('ponsel', const Rect.fromLTRB(0.30, 0.20, 0.70, 0.85)),
      ]);

      expect(scene.primaryHazard, isNull);
      expect(scene.targets.single.risk, IndoorRiskLevel.none);
    });

    test('objek atas yang tidak mencapai area jalur tidak memicu alarm', () {
      final scene = IndoorAssistEngine.analyze([
        observation('orang', const Rect.fromLTRB(0.35, 0.02, 0.65, 0.40)),
      ]);

      expect(scene.primaryHazard, isNull);
      expect(scene.targets.single.inTravelPath, isFalse);
    });
  });

  group('IndoorAssistEngine ringkasan', () {
    test('ringkasan memprioritaskan bahaya dan dibatasi tiga objek', () {
      final scene = IndoorAssistEngine.analyze([
        observation('buku', const Rect.fromLTRB(0.02, 0.10, 0.18, 0.30)),
        observation('kursi', const Rect.fromLTRB(0.34, 0.30, 0.66, 0.82)),
        observation('orang', const Rect.fromLTRB(0.72, 0.10, 0.96, 0.82)),
        observation('televisi', const Rect.fromLTRB(0.05, 0.20, 0.30, 0.60)),
      ]);

      final summary = IndoorAssistEngine.sceneSummary(scene);
      expect(summary, startsWith('Ringkasan sekitar. kursi'));
      expect(summary, contains('Ada rintangan di jalur'));
      expect(summary, isNot(contains('buku')));
    });

    test('hasil kosong tidak pernah menyatakan jalur aman', () {
      const scene = IndoorScene(targets: []);
      final summary = IndoorAssistEngine.sceneSummary(scene);

      expect(summary, contains('bukan berarti jalur aman'));
      expect(summary, contains('tongkat'));
    });

    test('duplikat label dan arah tidak dibacakan berulang', () {
      final scene = IndoorAssistEngine.analyze([
        observation('kursi', const Rect.fromLTRB(0.35, 0.35, 0.55, 0.75)),
        observation('kursi', const Rect.fromLTRB(0.45, 0.40, 0.65, 0.78)),
      ]);
      final summary = IndoorAssistEngine.sceneSummary(scene);

      expect('kursi'.allMatches(summary).length, 1);
    });
  });

  group('IndoorAlertGate', () {
    late IndoorTarget warning;

    setUp(() {
      warning = IndoorAssistEngine.analyze([
        observation('kursi', const Rect.fromLTRB(0.35, 0.35, 0.65, 0.80)),
      ]).primaryHazard!;
    });

    test('peringatan biasa harus stabil dua frame', () {
      final gate = IndoorAlertGate();
      final now = DateTime(2026, 10, 14);

      expect(gate.evaluate(warning, now).speak, isFalse);
      expect(
        gate
            .evaluate(warning, now.add(const Duration(milliseconds: 500)))
            .speak,
        isTrue,
      );
    });

    test('alarm sama diredam sampai cooldown selesai', () {
      final gate = IndoorAlertGate();
      final now = DateTime(2026, 10, 14);

      gate.evaluate(warning, now);
      expect(
        gate
            .evaluate(warning, now.add(const Duration(milliseconds: 500)))
            .speak,
        isTrue,
      );
      expect(
        gate.evaluate(warning, now.add(const Duration(seconds: 2))).speak,
        isFalse,
      );
      expect(
        gate.evaluate(warning, now.add(const Duration(seconds: 7))).speak,
        isTrue,
      );
    });

    test('alarm kritis tetap menunggu dua frame lalu urgent', () {
      final critical = IndoorAssistEngine.analyze([
        observation('orang', const Rect.fromLTRB(0.10, 0.05, 0.90, 0.98)),
      ]).primaryHazard!;
      final gate = IndoorAlertGate();
      final now = DateTime(2026, 10, 14);

      expect(gate.evaluate(critical, now).speak, isFalse);
      final confirmed = gate.evaluate(
        critical,
        now.add(const Duration(milliseconds: 250)),
      );

      expect(confirmed.speak, isTrue);
      expect(confirmed.urgent, isTrue);
    });

    test('bahaya yang hilang lalu muncul kembali dianggap episode baru', () {
      final gate = IndoorAlertGate();
      final now = DateTime(2026, 10, 14);

      gate.evaluate(warning, now);
      expect(
        gate
            .evaluate(warning, now.add(const Duration(milliseconds: 250)))
            .speak,
        isTrue,
      );
      gate.reset();
      expect(
        gate.evaluate(warning, now.add(const Duration(seconds: 1))).speak,
        isFalse,
      );
      expect(
        gate
            .evaluate(warning, now.add(const Duration(milliseconds: 1250)))
            .speak,
        isTrue,
      );
    });
  });
}
