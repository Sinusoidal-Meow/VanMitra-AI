import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/resolution_model.dart';
import '../../providers/gram_sabha_module_c_provider.dart';
import '../../widgets/trilingual_summary_tabs.dart';
import 'package:uuid/uuid.dart';

/// Module C §B.3 — Resolution Recording Screen
///
/// The Secretary reviews the raw STT transcript and confirms/edits all three
/// language versions before the resolution is finalized. The AI-Generated banner
/// persists until confirmed — no way to bypass the review step.
///
/// Returns: routes back to GramSabhaLogScreen with a confirmed [ResolutionModel]
/// stored in provider state.
class ResolutionRecordingScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final String villageId;
  final String language;

  const ResolutionRecordingScreen({
    super.key,
    required this.meetingId,
    required this.villageId,
    required this.language,
  });

  @override
  ConsumerState<ResolutionRecordingScreen> createState() =>
      _ResolutionRecordingScreenState();
}

class _ResolutionRecordingScreenState
    extends ConsumerState<ResolutionRecordingScreen> {
  bool _isListening = false;
  bool _isTranslating = false;
  String _rawTranscript = '';
  String _textEn = '';
  String _textHi = '';
  String _textMr = '';
  bool _isUserReviewed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  Future<void> _startListening() async {
    final stt = ref.read(sttServiceProvider);
    final isSupported = await stt.checkLocaleAvailable('${widget.language}_IN');

    if (!isSupported) {
      // Show text input fallback for Gondi/Warli or if locale not installed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.language == 'gon' || widget.language == 'wbr'
                  ? 'No device STT for ${widget.language == 'gon' ? 'Gondi' : 'Warli'} — please type the resolution below'
                  : 'Hindi/Marathi language pack not installed. Please install it in device Settings → Language.',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    await stt.startListening(
      locale: '${widget.language}_IN',
      onPartialResult: (text) {
        if (mounted) setState(() => _rawTranscript = text);
      },
      onFinalResult: (text) async {
        if (mounted) {
          setState(() {
            _rawTranscript = text;
            _isListening = false;
            _isTranslating = true;
          });
          await _buildTranslations(text);
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('STT error: $err'), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await ref.read(sttServiceProvider).stopListening();
    setState(() => _isListening = false);
    if (_rawTranscript.isNotEmpty) {
      setState(() => _isTranslating = true);
      await _buildTranslations(_rawTranscript);
    }
  }

  Future<void> _buildTranslations(String text) async {
    final translator = ref.read(translationServiceProvider);
    final result = await translator.buildTrilingualSummary(
      text: text,
      sourceLang: widget.language,
    );
    if (mounted) {
      setState(() {
        _textEn = result['textEn'] ?? '';
        _textHi = result['textHi'] ?? '';
        _textMr = result['textMr'] ?? text;
        _isTranslating = false;
      });
    }
  }

  Future<void> _confirmResolution() async {
    setState(() => _isSaving = true);

    final resolution = ResolutionModel(
      id: const Uuid().v4(),
      meetingId: widget.meetingId,
      villageId: widget.villageId,
      sourceLanguage: widget.language,
      rawTranscript: _rawTranscript,
      textEn: _textEn,
      textHi: _textHi,
      textMr: _textMr,
      createdAt: DateTime.now(),
      isAiGenerated: true,
      isUserReviewed: true, // Secretary explicitly confirmed
    );

    // TODO: Pass resolution back to GramSabhaLogScreen via provider
    // For now: store in a confirmed resolution provider
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resolution confirmed ✅ — ready for MoM assembly'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context, resolution);
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final isReady = ref.watch(translationReadyProvider);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        title: const Text('Record Resolution'),
        backgroundColor: c.scaffoldBg,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STT status / mic button
            _SttStatusBar(
              isListening: _isListening,
              isTranslating: _isTranslating,
              language: widget.language,
              onStop: _stopListening,
              onRestart: _startListening,
            ),
            const SizedBox(height: 16),

            // Raw transcript (editable)
            Text(
              'Transcript (${widget.language.toUpperCase()})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey(_rawTranscript),
              initialValue: _rawTranscript,
              onChanged: (v) => _rawTranscript = v,
              maxLines: 4,
              style: TextStyle(
                fontFamily: 'NotoSansDevanagari',
                fontSize: 14,
                height: 1.6,
                color: c.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: _isListening
                    ? 'Listening…'
                    : 'Transcript will appear here, or type manually',
                hintStyle: TextStyle(color: c.textTertiary),
                filled: c.isDark,
                fillColor: c.isDark ? c.sunkenBg : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                suffixIcon: _isListening
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Translate button (if transcript ready but not yet translated)
            if (!_isListening && _rawTranscript.isNotEmpty && _textEn.isEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isTranslating
                      ? null
                      : () => _buildTranslations(_rawTranscript),
                  icon: _isTranslating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate),
                  label: Text(
                      _isTranslating ? 'Translating…' : 'Generate Translations'),
                ),
              ),
            const SizedBox(height: 20),

            // Trilingual tabs (editable)
            if (_textEn.isNotEmpty || _textHi.isNotEmpty || _textMr.isNotEmpty) ...[
              Text(
                'Trilingual Summary — Review Each Tab',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TrilingualSummaryTabs(
                textEn: _textEn,
                textHi: _textHi,
                textMr: _textMr,
                isEditable: true,
                isTranslationReady: isReady,
                onEnChanged: (v) => setState(() => _textEn = v),
                onHiChanged: (v) => setState(() => _textHi = v),
                onMrChanged: (v) => setState(() => _textMr = v),
              ),
              const SizedBox(height: 20),

              // Confirm review checkbox
              CheckboxListTile(
                value: _isUserReviewed,
                onChanged: (v) => setState(() => _isUserReviewed = v ?? false),
                title: Text(
                  'मी हे पुनरावलोकन केले आहे | I have reviewed all three language versions',
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: c.isDark ? AppColors.accentSaffron : const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Resolution button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isUserReviewed && !_isSaving)
                      ? _confirmResolution
                      : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                      _isSaving ? 'Saving…' : 'Confirm Resolution'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUserReviewed
                        ? (c.isDark ? AppColors.accentSaffron : const Color(0xFF2E7D32))
                        : (c.isDark ? c.sunkenBg : Colors.grey),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SttStatusBar extends StatelessWidget {
  final bool isListening;
  final bool isTranslating;
  final String language;
  final VoidCallback onStop;
  final VoidCallback onRestart;

  const _SttStatusBar({
    required this.isListening,
    required this.isTranslating,
    required this.language,
    required this.onStop,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color color;
    final String label;
    final Widget trailing;

    if (isListening) {
      color = const Color(0xFFC62828);
      label = '🎙 Listening… tap STOP when done';
      trailing = ElevatedButton(
        onPressed: onStop,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
        child: const Text('STOP', style: TextStyle(color: Colors.white)),
      );
    } else if (isTranslating) {
      color = const Color(0xFF1565C0);
      label = '⏳ Generating translations…';
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      color = c.textSecondary;
      label = 'Tap to re-record or edit manually below';
      trailing = OutlinedButton.icon(
        onPressed: onRestart,
        icon: const Icon(Icons.mic),
        label: const Text('Re-record'),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.isDark ? AppColors.accentSaffron : AppColors.primary,
          side: BorderSide(color: c.border),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ),
          trailing,
        ],
      ),
    );
  }
}
