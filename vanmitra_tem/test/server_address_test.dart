import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanmitra_ai/core/api/api_endpoints.dart';
import 'package:vanmitra_ai/core/api/server_address.dart';
import 'package:vanmitra_ai/widgets/server_address_dialog.dart';

void main() {
  group('ServerAddress.normalise', () {
    test('adds https to a bare web address and drops slashes and /api/v1', () {
      expect(ServerAddress.normalise('vanmitra.up.railway.app'),
          'https://vanmitra.up.railway.app');
      expect(ServerAddress.normalise('  https://vanmitra.up.railway.app/  '),
          'https://vanmitra.up.railway.app');
      expect(ServerAddress.normalise('https://x.app/api/v1/'), 'https://x.app');
    });

    test('keeps http for a local or private address', () {
      expect(ServerAddress.normalise('192.168.1.7:8000'), 'http://192.168.1.7:8000');
      expect(ServerAddress.normalise('127.0.0.1:8000'), 'http://127.0.0.1:8000');
      expect(ServerAddress.normalise('http://10.0.2.2:8000'), 'http://10.0.2.2:8000');
    });

    test('empty stays empty', () {
      expect(ServerAddress.normalise('   '), '');
    });

    test('describe shows the host and port only', () {
      expect(ServerAddress.describe('https://vanmitra.up.railway.app'),
          'vanmitra.up.railway.app');
      expect(ServerAddress.describe('http://127.0.0.1:8000'), '127.0.0.1:8000');
    });
  });

  group('ApiEndpoints with a typed address', () {
    tearDown(() => ApiEndpoints.serverOverride = null);

    test('the typed address wins over the compiled-in one', () {
      ApiEndpoints.serverOverride = 'https://vanmitra.up.railway.app';
      expect(ApiEndpoints.baseUrl, 'https://vanmitra.up.railway.app/api/v1');
      expect(ApiEndpoints.serverRoot, 'https://vanmitra.up.railway.app');
      expect(ApiEndpoints.isConfigured, isTrue);
    });

    test('accepts an address that already ends with /api/v1', () {
      ApiEndpoints.serverOverride = 'https://x.app/api/v1';
      expect(ApiEndpoints.baseUrl, 'https://x.app/api/v1');
      expect(ApiEndpoints.serverRoot, 'https://x.app');
    });

    test('an empty typed address counts as not set', () {
      ApiEndpoints.serverOverride = '';
      expect(ApiEndpoints.isConfigured, isFalse);
    });
  });

  group('checkServer', () {
    Future<ServerCheck> check(http.Response Function(http.Request) answer) =>
        checkServer(
          'https://vanmitra.example',
          client: MockClient((r) async => answer(r)),
        );

    test('a healthy server and database', () async {
      final r = await check((req) {
        expect(req.url.toString(), 'https://vanmitra.example/api/v1/health');
        return http.Response(
            '{"status":"ok","service":"vanmitra-backend","database":"ok"}', 200);
      });
      expect(r.ok, isTrue);
    });

    test('the server is up but the database is not: says what to do', () async {
      final r = await check((_) => http.Response(
          '{"status":"ok","service":"vanmitra-backend","database":"unavailable"}',
          200));
      expect(r.ok, isFalse);
      expect(r.message, contains('database'));
    });

    test('some other website is not accepted as VanMitra', () async {
      expect((await check((_) => http.Response('{"hello":1}', 200))).ok, isFalse);
      expect((await check((_) => http.Response('nope', 404))).ok, isFalse);
    });

    test('no connection is reported, not thrown', () async {
      final r = await checkServer(
        'https://vanmitra.example',
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      expect(r.ok, isFalse);
    });

    test('nothing typed', () async {
      expect((await checkServer('  ')).ok, isFalse);
    });
  });
}
