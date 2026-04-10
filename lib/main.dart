import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clap Flikker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ClapDetectorScreen(),
    );
  }
}

class ClapDetectorScreen extends StatefulWidget {
  const ClapDetectorScreen({super.key});

  @override
  State<ClapDetectorScreen> createState() => _ClapDetectorScreenState();
}

class _ClapDetectorScreenState extends State<ClapDetectorScreen> {
  bool _isListening = false;
  bool _torchOn = false;
  String _status = 'Tap to start listening for claps';
  FlutterTts? _tts;
  StreamSubscription<Uint8List>? _micSubscription;
  Timer? _torchTimer;
  late final AudioRecorder _record;

  // Clap detection state
  final double _clapThreshold = 0.05; // Lowered for better sensitivity
  double _lastRMS = 0.0; // For debug display
  bool _clapDebounce = false;
  Timer? _debounceTimer;

  // Custom speech feature
  static const String _speechPreferenceKey = 'customSpeechText';
  final String _defaultText = "hi sudhaaamani";
  final TextEditingController _speechController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _record = AudioRecorder();
    _initTts();
    _loadSavedSpeechText();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts!.setLanguage("en-US");
    await _tts!.setSpeechRate(0.5);
  }

  Future<void> _loadSavedSpeechText() async {
    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString(_speechPreferenceKey);
    setState(() {
      _speechController.text = savedText?.isNotEmpty == true ? savedText! : _defaultText;
    });
  }

  Future<void> _saveSpeechText() async {
    final speechText = _speechController.text.trim();
    if (speechText.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_speechPreferenceKey, speechText);

    if (!mounted) return;
    setState(() {
      _status = 'Saved speech phrase';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom speech phrase saved')),
    );
  }

  String get _speechText {
    final text = _speechController.text.trim();
    return text.isEmpty ? _defaultText : text;
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.camera, // Torch needs camera on some devices
    ].request();
    return statuses[Permission.microphone]!.isGranted &&
           statuses[Permission.camera]!.isGranted;
  }

  void _toggleListening() async {
    if (!_isListening) {
      if (await _requestPermissions()) {
        setState(() {
          _isListening = true;
          _status = 'Listening for clap...';
        });
        _startMicStream();
      } else {
        setState(() {
          _status = 'Permissions denied';
        });
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() async {
    setState(() {
      _isListening = false;
      _status = 'Stopped';
    });
    await _record.stop();
    _micSubscription?.cancel();
    _torchTimer?.cancel();
    _debounceTimer?.cancel();
    TorchLight.disableTorch();
    _torchOn = false;
    _clapDebounce = false;
  }

  void _startMicStream() async {
    try {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final stream = await _record.startStream(config);
      _micSubscription = stream.listen(
        (Uint8List buffer) {
          final rms = _computeRMS(buffer);
          // Debug: print RMS values to console
          debugPrint('RMS: ${rms.toStringAsFixed(4)} | threshold: $_clapThreshold | debounce: $_clapDebounce');
          setState(() {
            _lastRMS = rms;
          });
          if (rms > _clapThreshold && !_clapDebounce) {
            _clapDebounce = true;
            _onClapDetected();
            // 12s debounce to cover the full 3-cycle repeat
            _debounceTimer = Timer(const Duration(seconds: 12), () {
              _clapDebounce = false;
            });
          }
        },
        onError: (error) {
          setState(() {
            _status = 'Mic error: $error';
          });
        },
      );
    } catch (e) {
      setState(() {
        _status = 'Failed to start mic: $e';
        _isListening = false;
      });
    }
  }

  double _computeRMS(Uint8List data) {
    // PCM 16-bit: each sample is 2 bytes (little-endian signed int16)
    if (data.length < 2) return 0.0;
    final byteData = ByteData.sublistView(data);
    final sampleCount = data.length ~/ 2;
    double sum = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      final normalized = sample / 32768.0; // int16 to [-1, 1]
      sum += normalized * normalized;
    }
    return math.sqrt(sum / sampleCount);
  }

  Future<void> _onClapDetected() async {
    // Repeat the torch + TTS cycle 3 times
    for (int i = 1; i <= 3; i++) {
      if (!_isListening) break; // Stop if user pressed stop

      setState(() {
        _status = 'Clap detected! Round $i/3 - Torch on.';
        _torchOn = true;
      });

      debugPrint('Round $i start');
      try {
        await TorchLight.enableTorch();
      } catch (e) {
        debugPrint('Error enabling torch: $e');
      }
      
      await _tts!.speak(_speechText);

      // Wait for TTS to finish + keep torch on for 3 seconds
      await Future.delayed(const Duration(seconds: 3));

      try {
        await TorchLight.disableTorch();
      } catch (e) {
        debugPrint('Error disabling torch: $e');
      }
      
      setState(() {
        _torchOn = false;
      });

      // Brief pause between rounds (except after last)
      if (i < 3) {
        await Future.delayed(const Duration(seconds: 1));
      }
      debugPrint('Round $i end');
    }

    if (_isListening) {
      setState(() {
        _status = 'Listening for clap...';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Clap Flikker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              size: 100,
              color: _isListening ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _toggleListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              child: Text(_isListening ? 'Stop' : 'Start Listening'),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _speechController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Custom speech phrase',
                      hintText: _defaultText,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveSpeechText(),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _saveSpeechText,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save phrase'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _torchOn ? 'Torch: ON' : 'Torch: OFF',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'RMS: ${_lastRMS.toStringAsFixed(4)} / Threshold: $_clapThreshold',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopListening();
    _record.dispose();
    _speechController.dispose();
    _tts?.stop();
    super.dispose();
  }
}
