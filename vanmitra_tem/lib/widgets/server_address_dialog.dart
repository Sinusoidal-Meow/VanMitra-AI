import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api/api_endpoints.dart';
import '../core/api/server_address.dart';
import '../core/theme/app_colors.dart';

/// What a connection test found, in words a person at a demo can act on.
class ServerCheck {
  const ServerCheck(this.ok, this.message);
  final bool ok;
  final String message;
}

/// Asks the server at [root] for its health (a public, read-only call). Never throws.
Future<ServerCheck> checkServer(
  String root, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final address = ServerAddress.normalise(root);
  if (address.isEmpty) return const ServerCheck(false, 'Type the server address first.');
  final c = client ?? http.Client();
  try {
    final r = await c.get(Uri.parse('$address/api/v1/health')).timeout(timeout);
    if (r.statusCode != 200) {
      return ServerCheck(false, 'The address answered, but not as VanMitra (HTTP ${r.statusCode}).');
    }
    final body = jsonDecode(r.body);
    if (body is! Map || body['service'] != 'vanmitra-backend') {
      return const ServerCheck(false, 'The address answered, but it is not a VanMitra server.');
    }
    if (body['database'] == 'ok') {
      return const ServerCheck(true, 'Connected. The server and its database are working.');
    }
    return const ServerCheck(
      false,
      'The server is reachable but cannot reach its database. Ask the team to allow the '
      'server in the database network settings.',
    );
  } on TimeoutException {
    return const ServerCheck(false, 'No answer in time. Check the address and the internet.');
  } catch (_) {
    return const ServerCheck(false, 'Could not connect. Check the address and the internet.');
  } finally {
    if (client == null) c.close();
  }
}

/// The sign-in screen's "Server" button: see, test, change or forget the server address.
Future<void> showServerAddressDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ServerAddressDialog(),
  );
}

class _ServerAddressDialog extends StatefulWidget {
  const _ServerAddressDialog();

  @override
  State<_ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<_ServerAddressDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: ApiEndpoints.isConfigured ? ApiEndpoints.serverRoot : '',
  );
  bool _testing = false;
  ServerCheck? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final r = await checkServer(_controller.text);
    if (mounted) {
      setState(() {
        _testing = false;
        _result = r;
      });
    }
  }

  Future<void> _save() async {
    await ServerAddress.save(_controller.text);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await ServerAddress.save(null);
    if (!mounted) return;
    _controller.text = ApiEndpoints.isConfigured ? ApiEndpoints.serverRoot : '';
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AlertDialog(
      title: const Text('Server address'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The web address of the VanMitra server, for example vanmitra.up.railway.app. '
              'The team gives you this.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Server address',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _result = null),
            ),
            const SizedBox(height: 8),
            if (_testing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (r != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 20,
                      color: r.ok ? AppColors.successGreen : AppColors.alertRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.message, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _testing ? null : _reset, child: const Text('Use default')),
        TextButton(onPressed: _testing ? null : _test, child: const Text('Test')),
        FilledButton(onPressed: _testing ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
