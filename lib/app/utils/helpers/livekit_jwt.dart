import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Helper untuk membuat token otorisasi LiveKit sesuai standar JWT HS256
/// Referensi: https://docs.livekit.io/frontends/reference/tokens-grants/
class LiveKitJwt {
  static String base64UrlNoPad(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Membuat JWT LiveKit dengan video grants minimum yang dibutuhkan
  static String createToken({
    required String apiKey,
    required String apiSecret,
    required String roomName,
    required String identity,
    required String name,
    bool canPublish = true,
    bool canSubscribe = true,
    bool canPublishData = true,
    Duration validFor = const Duration(hours: 2),
  }) {
    final now = DateTime.now().toUtc();
    final nbf = now.millisecondsSinceEpoch ~/ 1000;
    final exp = nbf + validFor.inSeconds;

    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    final payload = {
      'exp': exp,
      'iss': apiKey,
      'nbf': nbf,
      'sub': identity,
      'name': name,
      'video': {
        'room': roomName,
        'roomJoin': true,
        'canPublish': canPublish,
        'canSubscribe': canSubscribe,
        'canPublishData': canPublishData,
      },
    };

    final headerB64 = base64UrlNoPad(utf8.encode(jsonEncode(header)));
    final payloadB64 = base64UrlNoPad(utf8.encode(jsonEncode(payload)));
    final unsignedToken = '$headerB64.$payloadB64';

    final hmac = Hmac(sha256, utf8.encode(apiSecret));
    final signature = hmac.convert(utf8.encode(unsignedToken));
    final signatureB64 = base64UrlNoPad(signature.bytes);

    return '$unsignedToken.$signatureB64';
  }
}
