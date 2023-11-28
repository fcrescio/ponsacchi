import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeech {
  FlutterTts flutterTts;

  TextToSpeech() : flutterTts = FlutterTts();

  Future speak(String text) async {
    await flutterTts.setLanguage("it-IT");
    await flutterTts.setPitch(1.0); // Adjust the pitch level if needed
    await flutterTts.speak(text);
  }

  Future stop() async {
    await flutterTts.stop();
  }
}