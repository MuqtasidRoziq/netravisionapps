import 'dart:io';
import '../lib/pilot_server.dart';

void main(List<String> args) async {
  final portStr = Platform.environment['PORT'] ?? '8080';
  final port = int.tryParse(portStr) ?? 8080;

  final livekitUrl = Platform.environment['LIVEKIT_URL'] ?? 'wss://pilot.netravision.internal';
  final livekitApiKey = Platform.environment['LIVEKIT_API_KEY'] ?? 'netra_pilot_key';
  final livekitApiSecret = Platform.environment['LIVEKIT_API_SECRET'] ?? 'netra_pilot_secret_998244353';
  final requestTimeout = int.tryParse(Platform.environment['REQUEST_TIMEOUT_SECONDS'] ?? '45') ?? 45;

  final server = PilotServer(
    port: port,
    livekitUrl: livekitUrl,
    livekitApiKey: livekitApiKey,
    livekitApiSecret: livekitApiSecret,
    requestTimeoutSeconds: requestTimeout,
  );

  await server.start();
  // ignore: avoid_print
  print('====================================================');
  // ignore: avoid_print
  print('NetraVision Bantuan Visual V2 - Pilot Server Aktif');
  // ignore: avoid_print
  print('Port             : $port');
  // ignore: avoid_print
  print('LiveKit URL      : $livekitUrl');
  // ignore: avoid_print
  print('Request Timeout  : ${requestTimeout}s');
  // ignore: avoid_print
  print('Health Check     : http://localhost:$port/api/health');
  // ignore: avoid_print
  print('WebSocket URL    : ws://localhost:$port/ws');
  // ignore: avoid_print
  print('====================================================');

  ProcessSignal.sigint.watch().listen((_) async {
    // ignore: avoid_print
    print('\nMematikan server NetraVision...');
    await server.stop();
    exit(0);
  });
}
