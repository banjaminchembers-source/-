import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const String apiBaseUrl = String.fromEnvironment(
  'APP_API_BASE_URL',
  defaultValue: 'https://dimon-assistant-api.onrender.com',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DimonApp());
}

class DimonApp extends StatelessWidget {
  const DimonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Димон',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42A5F5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        useMaterial3: true,
      ),
      home: const DimonHomePage(),
    );
  }
}

class DimonHomePage extends StatefulWidget {
  const DimonHomePage({super.key});

  @override
  State<DimonHomePage> createState() => _DimonHomePageState();
}

class _DimonHomePageState extends State<DimonHomePage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _useNaturalVoice = true;
  final TextEditingController _inputController = TextEditingController();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isBusy = false;
  bool _speakReplies = true;
  String _text = 'Здорово, босс. Нажми на микрофон или напиши сообщение.';
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    await [Permission.microphone].request();
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }

    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setPitch(0.95);
      await _tts.setSpeechRate(0.48);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Some Android TTS engines may not support every setting.
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (_isBusy) return;
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      final command = _recognizedText.trim();
      if (command.isNotEmpty) await _processCommand(command);
      return;
    }

    if (!_speechAvailable) {
      await _speak('Распознавание речи недоступно. Проверь разрешение микрофона и голосовой сервис.');
      if (mounted) setState(() => _text = 'Распознавание речи недоступно. Проверь разрешение микрофона.');
      return;
    }

    _recognizedText = '';
    try {
      await _speech.listen(
        localeId: 'ru_RU',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          if (mounted) setState(() => _text = _recognizedText.isEmpty ? 'Слушаю...' : _recognizedText);
          if (result.finalResult && _recognizedText.trim().isNotEmpty) {
            // The user can tap the microphone again to submit the recognized phrase.
          }
        },
      );
      if (mounted) setState(() => _isListening = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _text = 'Не удалось запустить микрофон. Проверь разрешения Android.';
        });
      }
    }
  }

  Future<void> _sendTypedMessage() async {
    final message = _inputController.text.trim();
    if (message.isEmpty || _isBusy) return;
    _inputController.clear();
    await _processCommand(message);
  }

  Future<void> _processCommand(String command) async {
    final lower = command.toLowerCase();

    if (lower.contains('открой') || lower.contains('запусти')) {
      if (lower.contains('ютуб') || lower.contains('youtube')) {
        await _speak('Открываю YouTube, босс.');
        final opened = await launchUrl(Uri.parse('https://www.youtube.com'), mode: LaunchMode.externalApplication);
        if (!opened) {
          await _speak('Не получилось открыть YouTube. Возможно, приложение не установлено.');
        }
        return;
      }
      if (lower.contains('телеграм') || lower.contains('telegram')) {
        await _speak('Секунду, запускаю Telegram.');
        final opened = await launchUrl(Uri.parse('https://t.me'), mode: LaunchMode.externalApplication);
        if (!opened) {
          await _speak('Не получилось открыть Telegram. Возможно, приложение не установлено.');
        }
        return;
      }
      if (lower.contains('настройки')) {
        await _speak('Открываю настройки приложения.');
        await openAppSettings();
        return;
      }
    }

    await _askAssistant(command);
  }

  Future<void> _askAssistant(String prompt) async {
    if (apiBaseUrl.trim().isEmpty) {
      const message = 'ИИ пока не подключён. Настрой сервер и GitHub Secret APP_API_BASE_URL — ключ OpenAI нельзя хранить внутри APK.';
      if (mounted) setState(() => _text = message);
      await _speak('Босс, сервер ИИ пока не настроен.');
      return;
    }

    setState(() {
      _isBusy = true;
      _text = 'Димон думает...';
    });

    try {
      final uri = Uri.parse('${apiBaseUrl.replaceAll(RegExp(r'/+$'), '')}/chat');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'message': prompt}),
          )
          .timeout(const Duration(seconds: 45));

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          decoded['reply'] is String) {
        final reply = (decoded['reply'] as String).trim();
        if (mounted) setState(() => _text = reply);
        if (_speakReplies) await _speak(reply);
      } else {
        final serverMessage = decoded is Map && decoded['error'] is String
            ? decoded['error'] as String
            : 'Сервер вернул ошибку ${response.statusCode}.';
        if (mounted) setState(() => _text = serverMessage);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _text = 'Не удалось связаться с сервером. Проверь интернет и адрес APP_API_BASE_URL.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _speak(String text) async {
    // Prefer natural server-generated Russian speech; fall back to Android TTS.
    if (_useNaturalVoice && apiBaseUrl.trim().isNotEmpty && text.trim().isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('${apiBaseUrl.replaceAll(RegExp(r'/+

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _audioPlayer.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ДИМОН ИИ'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _speakReplies ? 'Выключить озвучку' : 'Включить озвучку',
            onPressed: () => setState(() => _speakReplies = !_speakReplies),
            icon: Icon(_speakReplies ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF15283B),
                  border: Border.all(color: const Color(0xFF42A5F5), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x3342A5F5), blurRadius: 24, spreadRadius: 3),
                  ],
                ),
                child: const Icon(Icons.graphic_eq, size: 56, color: Color(0xFF90CAF9)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121922),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 19, height: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTypedMessage(),
                decoration: InputDecoration(
                  hintText: 'Напиши Димону...',
                  filled: true,
                  fillColor: const Color(0xFF121922),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  suffixIcon: IconButton(
                    onPressed: _isBusy ? null : _sendTypedMessage,
                    icon: const Icon(Icons.send),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red.shade700 : const Color(0xFF1976D2),
                  ),
                  child: Icon(
                    _isBusy
                        ? Icons.hourglass_top
                        : _isListening
                            ? Icons.stop
                            : Icons.mic,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isBusy
                    ? 'Димон обрабатывает запрос...'
                    : _isListening
                        ? 'Слушаю. Нажми, чтобы отправить.'
                        : 'Нажми на микрофон, скажи команду и нажми снова',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
), '')}/speech'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'text': text}),
        ).timeout(const Duration(seconds: 45));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await _tts.stop();
          await _audioPlayer.stop();
          await _audioPlayer.play(BytesSource(response.bodyBytes, mimeType: 'audio/mpeg'));
          return;
        }
      } catch (_) {
        // If network/TTS service is unavailable, use the device's voice.
      }
    }
    try {
      await _audioPlayer.stop();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Keep the app usable if the device has no configured TTS engine.
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ДИМОН ИИ'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _speakReplies ? 'Выключить озвучку' : 'Включить озвучку',
            onPressed: () => setState(() => _speakReplies = !_speakReplies),
            icon: Icon(_speakReplies ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF15283B),
                  border: Border.all(color: const Color(0xFF42A5F5), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x3342A5F5), blurRadius: 24, spreadRadius: 3),
                  ],
                ),
                child: const Icon(Icons.graphic_eq, size: 56, color: Color(0xFF90CAF9)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121922),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 19, height: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTypedMessage(),
                decoration: InputDecoration(
                  hintText: 'Напиши Димону...',
                  filled: true,
                  fillColor: const Color(0xFF121922),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  suffixIcon: IconButton(
                    onPressed: _isBusy ? null : _sendTypedMessage,
                    icon: const Icon(Icons.send),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red.shade700 : const Color(0xFF1976D2),
                  ),
                  child: Icon(
                    _isBusy
                        ? Icons.hourglass_top
                        : _isListening
                            ? Icons.stop
                            : Icons.mic,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isBusy
                    ? 'Димон обрабатывает запрос...'
                    : _isListening
                        ? 'Слушаю. Нажми, чтобы отправить.'
                        : 'Нажми на микрофон, скажи команду и нажми снова',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
