import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
// Import the OpenAI service
import 'openai_service.dart';
import 'native_tts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const CameraApp());
}

class CameraApp extends StatefulWidget {
  // Add a Key parameter to the constructor
  const CameraApp({Key? key}) : super(key: key);

  @override
  CameraAppState createState() => CameraAppState();
}

class CameraAppState extends State<CameraApp> {
  CameraController? controller;
  TextToSpeech tts = TextToSpeech();
  String lastResponse = "";
  String baseContext = "You provide guidance to a vision impaired person. You reply in Italian. ";
  AudioRecorder? recorder;
  bool _customQuestion = false;
  String _recordedFilePath = "";

  @override
  void initState() {
    super.initState();
    initCamera();
    recorder = AudioRecorder();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras[0], ResolutionPreset.max);
      controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const MaterialApp(
          home: Scaffold(
          body: Center(child: CircularProgressIndicator()), // Or some other placeholder
        ),
      );
    }

    return MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          onTap: () => captureImage(),
          onLongPressStart: (_) => _startRecording(),
          onLongPressEnd: (_) => _stopRecording(),
          onHorizontalDragEnd: (details) {
            // Check the direction of the drag
            if (details.primaryVelocity! > 0) {
              // Swiped Left
              handleSwipeLeft();
            }
          },
          child: CameraPreview(controller!), // Or your existing camera preview widget
        ),
      ),
    );
  }

  Future<void> captureImage() async {
    try {
      final image = await controller!.takePicture();
      String question = "What’s in this image?";
      String detail = "low";
      String context = "";
      OpenAIService openAIService = OpenAIService(dotenv.env['APIKEY']!);
      if (_customQuestion) {
        _recordedFilePath = (await recorder?.stop())!;
        await tts.speak("Ho capito ora ci penso");
        question = await openAIService.understandQuestion(File(_recordedFilePath));
        if (question.startsWith("Impostazione")) {
          baseContext = question.substring("Impostazione sistema".length).trim();
          await tts.speak("Nuovo contesto: $baseContext");
          return;
        }
        detail = "high";
        context = "You always provide a very short summary of the question asked before answering.";
        setState(() => _customQuestion = false);
      } else {
        await tts.speak("Immagine catturata! Ora aspetta che ci penso un po'");
      }
      String analysisResult = '${await openAIService.analyzeImage(File(image.path),question,detail,baseContext+context)}\nAnalisi dell\'immagine terminata';

      // Process the analysis result
      // You might want to display it or use it in your app
      //print('OpenAI Analysis Result: $analysisResult');
      lastResponse = analysisResult;
      await tts.speak(analysisResult);
    } catch (e) {
      // Handle error
      Clipboard.setData(ClipboardData(text: e.toString()));
      await tts.speak("Qualcosa è andato storto! Bisogna chiedere a Francesco. L'errore si trova nella clipboard basta incollarlo su telegram nella chat di famiglia.");
      //print('Error capturing or analyzing image: $e');
    }
  }

  void handleSwipeLeft() {
    if (lastResponse.isNotEmpty) {
      tts.speak(lastResponse);
    }
  }

  Future<void> _startRecording() async {
    await tts.speak("Cosa cerchi?");
    var tempDir = await getTemporaryDirectory();
    await recorder?.start(const RecordConfig(), path: '${tempDir.path}/ponsacchiaudio.m4a');
    setState(() => _customQuestion = true);
  }

  Future<void> _stopRecording() async {
//    _recordedFilePath = (await recorder?.stop())!;
//    await tts.speak("Ho capito ora ci penso");
//    setState(() => _customQuestion = true);
//    captureImage();
  }

  @override
  void dispose() {
    controller?.dispose();
    recorder?.dispose();
    tts.stop();
    super.dispose();
  }
}