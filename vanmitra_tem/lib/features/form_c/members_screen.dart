// Gram Sabha member roster: feeds the Form C member sheet (item 5), FRC composition and quorum.
// Kept by the Gram Sabha Secretary [Rule 11(6)]; other roles can view it.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../form_b/form_b_api.dart';
import 'form_c_models.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.villageId, required this.canEdit});

  final String villageId;
  final bool canEdit;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<GsMember>? _members;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await formBApi.listMembers(widget.villageId);
      setState(() {
        _members = list;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    var gender = 'female';
    var category = 'st';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Gram Sabha member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'female', label: Text('Woman')),
                  ButtonSegment(value: 'male', label: Text('Man')),
                  ButtonSegment(value: 'other', label: Text('Other')),
                ],
                selected: {gender},
                onSelectionChanged: (s) => setSheet(() => gender = s.first),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'st', label: Text('ST')),
                  ButtonSegment(value: 'otfd', label: Text('OTFD')),
                  ButtonSegment(value: 'other', label: Text('Other')),
                ],
                selected: {category},
                onSelectionChanged: (s) => setSheet(() => category = s.first),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.forestCanopy, minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add member'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await formBApi.addMember(widget.villageId, name: name.text.trim(), gender: gender, category: category);
      await _load();
    } on ApiException catch (e) {
      _snack('Not added: $e');
    }
  }

  Future<void> _deactivate(GsMember m) async {
    try {
      await formBApi.updateMember(m.id, {'active': false});
      await _load();
    } on ApiException catch (e) {
      _snack('Not changed: $e');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final members = _members;
    final women = members?.where((m) => m.gender == 'female').length ?? 0;
    final st = members?.where((m) => m.category == 'st').length ?? 0;
    final otfd = members?.where((m) => m.category == 'otfd').length ?? 0;
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: Colors.white,
        title: const Text('Gram Sabha members · सदस्य'),
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.saffron,
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add member'),
            )
          : null,
      body: members == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text('${members.length} members · $women women · $st ST · $otfd OTFD',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (!widget.canEdit)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('View only: the roster is kept by the Gram Sabha Secretary.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  for (final m in members)
                    Card(
                      child: ListTile(
                        leading: Icon(m.gender == 'female' ? Icons.woman : Icons.man, color: AppColors.forestSage),
                        title: Text(m.name),
                        subtitle: Text(kMemberCategories[m.category] ?? m.category),
                        trailing: widget.canEdit
                            ? IconButton(
                                tooltip: 'Mark as no longer a member',
                                icon: const Icon(Icons.person_off_outlined),
                                onPressed: () => _deactivate(m),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
