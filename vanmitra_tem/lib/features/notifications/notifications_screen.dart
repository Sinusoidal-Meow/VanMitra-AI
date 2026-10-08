// Messages for the signed-in user from the VanMitra backend (for example: a claim was
// closed because it was not resubmitted within 60 days). The same messages also arrive
// as phone push messages.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../form_b/form_b_api.dart';
import '../form_b/form_b_models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsPage? _page;
  String? _error;

  bool get _marathi => Localizations.localeOf(context).languageCode == 'mr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await formBApi.notifications();
      if (!mounted) return;
      setState(() {
        _page = page;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Cannot load messages: $e');
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      try {
        await formBApi.markNotificationRead(n.id);
      } catch (_) {}
      await _load();
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_marathi ? n.titleMr : n.titleEn),
        content: Text(_marathi ? n.bodyMr : n.bodyEn),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _readAll() async {
    try {
      final page = await formBApi.markAllNotificationsRead();
      if (mounted) setState(() => _page = page);
    } catch (e) {
      if (mounted) setState(() => _error = 'Cannot update messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: Colors.white,
        title: const Text('Messages · सूचना'),
        actions: [
          if (page != null && page.unread > 0)
            TextButton(
              onPressed: _readAll,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: AppColors.alertRed)),
              ),
            if (page == null && _error == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            if (page != null && page.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No messages yet · अद्याप सूचना नाहीत',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            if (page != null)
              for (final n in page.items)
                Card(
                  child: ListTile(
                    leading: Icon(
                      n.read ? Icons.mark_email_read_outlined : Icons.mark_email_unread,
                      color: n.read ? AppColors.textSecondary : AppColors.saffron,
                    ),
                    title: Text(
                      _marathi ? n.titleMr : n.titleEn,
                      style: TextStyle(fontWeight: n.read ? FontWeight.w400 : FontWeight.w700),
                    ),
                    subtitle: Text(
                      _marathi ? n.bodyMr : n.bodyEn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(_date(n.createdAt), style: const TextStyle(fontSize: 12)),
                    onTap: () => _open(n),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
