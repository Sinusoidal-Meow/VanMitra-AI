import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_capture_service.dart';

/// Mandatory consent-recording gate for face enrolment.
///
/// The Secretary must record the member saying the consent phrase in Marathi
/// before the Save Enrolment button unlocks. Raw photo is discarded immediately
/// after embedding extraction — only the audio consent and the 128-dim vector
/// are stored (§7 data minimisation).
///
/// [onConsentRecorded] fires with the temp audio file path once recording stops.
/// The parent widget should enable its Save button only after this fires.
class ConsentRecorderWidget extends StatefulWidget {
  final void Function(String audioPath) onConsentRecorded;
  final String memberName;

  const ConsentRecorderWidget({
    super.key,
    required this.onConsentRecorded,
    required this.memberName,
  });

  @override
  State<ConsentRecorderWidget> createState() => _ConsentRecorderWidgetState();
}

class _ConsentRecorderWidgetState extends State<ConsentRecorderWidget>
    with SingleTickerProviderStateMixin {
  final AudioCaptureService _audio = AudioCaptureService();
  bool _isRecording = false;
  bool _isDone = false;
  String? _audioPath;
  double _amplitude = 0;
  Timer? _durationTimer;
  int _elapsedSeconds = 0;
  StreamSubscription? _ampSub;

  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _audio.dispose();
    _durationTimer?.cancel();
    _ampSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audio.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    await _audio.startRecording();
    _pulseController.repeat(reverse: true);
    _ampSub = _audio.amplitudeStream.listen((amp) {
      if (mounted) setState(() => _amplitude = (amp.current + 60) / 60);
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    _pulseController.stop();
    _durationTimer?.cancel();
    _ampSub?.cancel();
    final path = await _audio.stopRecording();
    if (path != null) {
      setState(() {
        _isRecording = false;
        _isDone = true;
        _audioPath = path;
        _amplitude = 0;
        _elapsedSeconds = 0;
      });
      widget.onConsentRecorded(path);
    }
  }

  Future<void> _reRecord() async {
    if (_audioPath != null) await _audio.deleteRecording(_audioPath!);
    setState(() {
      _isDone = false;
      _audioPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF57F17).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Consent prompt header
          Row(
            children: [
              const Icon(Icons.record_voice_over,
                  color: Color(0xFFF57F17), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'संमती रेकॉर्ड करा | Record Consent',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF57F17),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Consent phrase in Marathi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFFF57F17).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'म्हणा | Say:',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"मी ${widget.memberName} माझ्या चेहऱ्याची ओळख नोंदवण्यास संमती देतो/देते."',
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"I, ${widget.memberName}, consent to face enrolment for attendance."',
                  style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isDone)
            // Done state
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                const Text(
                  'Consent recorded ✓',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reRecord,
                  child: const Text('Re-record'),
                ),
              ],
            )
          else
            // Recording controls
            Row(
              children: [
                // Waveform visualizer
                Expanded(
                  child: _isRecording
                      ? SizedBox(
                          height: 32,
                          child: _WaveformBar(amplitude: _amplitude),
                        )
                      : const Text(
                          'Tap the mic to start',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                ),
                if (_isRecording) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_elapsedSeconds}s',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                // Mic / Stop button
                ScaleTransition(
                  scale: _isRecording ? _pulse : const AlwaysStoppedAnimation(1.0),
                  child: GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? const Color(0xFFC62828)
                            : const Color(0xFFF57F17),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFFF57F17))
                                .withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WaveformBar extends StatelessWidget {
  final double amplitude; // 0.0 – 1.0

  const _WaveformBar({required this.amplitude});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(12, (i) {
        final height = 4 + (amplitude * 24 * (0.4 + 0.6 * ((i % 3) / 2)));
        return Container(
          width: 4,
          height: height.clamp(4.0, 28.0),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF57F17).withOpacity(0.7 + amplitude * 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
