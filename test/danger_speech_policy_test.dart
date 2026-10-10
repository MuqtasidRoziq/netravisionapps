import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/danger_speech_policy.dart';
import 'package:netravisionapps/app/utils/helpers/spatial_estimator.dart';

void main() {
  group('DangerSpeechPolicy.decide', () {
    const minGap = 2000;
    const cooldown = 5000;

    test('bahaya pertama kali langsung diumumkan (urgent)', () {
      final d = DangerSpeechPolicy.decide(
        firstDanger: true,
        worsened: false,
        msSinceLast: 0,
        escalationMinGapMs: minGap,
        periodicCooldownMs: cooldown,
      );
      expect(d.speak, isTrue);
      expect(d.urgent, isTrue);
    });

    test('memburuk tapi jeda <2s tidak bicara (anti-flicker)', () {
      final d = DangerSpeechPolicy.decide(
        firstDanger: false,
        worsened: true,
        msSinceLast: 500,
        escalationMinGapMs: minGap,
        periodicCooldownMs: cooldown,
      );
      expect(d.speak, isFalse);
    });

    test('memburuk dengan jeda >=2s diumumkan (urgent)', () {
      final d = DangerSpeechPolicy.decide(
        firstDanger: false,
        worsened: true,
        msSinceLast: 2100,
        escalationMinGapMs: minGap,
        periodicCooldownMs: cooldown,
      );
      expect(d.speak, isTrue);
      expect(d.urgent, isTrue);
    });

    test('tenang tapi belum lewat cooldown → diam (getar tetap jalan)', () {
      final d = DangerSpeechPolicy.decide(
        firstDanger: false,
        worsened: false,
        msSinceLast: 3000,
        escalationMinGapMs: minGap,
        periodicCooldownMs: cooldown,
      );
      expect(d.speak, isFalse);
    });

    test('bahaya menetap >=5s → pengingat periodik (non-urgent)', () {
      final d = DangerSpeechPolicy.decide(
        firstDanger: false,
        worsened: false,
        msSinceLast: 5200,
        escalationMinGapMs: minGap,
        periodicCooldownMs: cooldown,
      );
      expect(d.speak, isTrue);
      expect(d.urgent, isFalse);
    });
  });

  group('DangerSpeechPolicy.worsened', () {
    test('label berubah dianggap memburuk', () {
      expect(
        DangerSpeechPolicy.worsened(
          label: 'truk',
          band: ProximityBand.dekat,
          meters: 2.0,
          prevLabel: 'mobil',
          prevBand: ProximityBand.dekat,
          prevMeters: 2.0,
        ),
        isTrue,
      );
    });

    test('naik ke sangatDekat dianggap memburuk', () {
      expect(
        DangerSpeechPolicy.worsened(
          label: 'mobil',
          band: ProximityBand.sangatDekat,
          meters: 0.8,
          prevLabel: 'mobil',
          prevBand: ProximityBand.dekat,
          prevMeters: 2.0,
        ),
        isTrue,
      );
    });

    test('jarak menyusut >30% dianggap memburuk', () {
      expect(
        DangerSpeechPolicy.worsened(
          label: 'mobil',
          band: ProximityBand.dekat,
          meters: 1.2,
          prevLabel: 'mobil',
          prevBand: ProximityBand.dekat,
          prevMeters: 1.8,
        ),
        isTrue,
      );
    });

    test('situasi sama / membaik tidak dianggap memburuk', () {
      expect(
        DangerSpeechPolicy.worsened(
          label: 'mobil',
          band: ProximityBand.dekat,
          meters: 1.9,
          prevLabel: 'mobil',
          prevBand: ProximityBand.dekat,
          prevMeters: 1.8,
        ),
        isFalse,
      );
    });
  });
}