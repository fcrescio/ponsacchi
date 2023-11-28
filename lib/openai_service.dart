import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:http_parser/http_parser.dart';

class OpenAIService {
  final String apiKey; // Your OpenAI API key

  OpenAIService(this.apiKey);

  Future<File> resizeImage(String imagePath, int maxWidth, int maxHeight) async {
    // Read the image file
    File originalImageFile = File(imagePath);
    Uint8List imageBytes = await originalImageFile.readAsBytes();

    // Decode the image
    img.Image? originalImage = img.decodeImage(imageBytes);

    // Resize the image
    img.Image resizedImage = img.copyResize(originalImage!, width: maxWidth, height: maxHeight);

    // Save the resized image to a new file
    File resizedImageFile = File(imagePath + '_resized.jpg');
    await resizedImageFile.writeAsBytes(img.encodeJpg(resizedImage));

    return resizedImageFile;
  }

  Future<String> understandQuestion(File audio) async {
    // Replace [API_ENDPOINT] with the actual endpoint of the OpenAI API for image analysis
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    print("Asking OpenAI Whisper");

//    var length = await audio.length();
    var request = http.MultipartRequest("POST", uri);
    final headers = request.headers;
    headers['Authorization'] = 'Bearer $apiKey';
    //var multipartFile = http.MultipartFile('file', stream, length);
    //contentType: new MediaType('image', 'png'));
    final formFields = request.fields;
    formFields['model'] = "whisper-1";
    final formFiles = request.files;
    formFiles.add(http.MultipartFile.fromBytes('file', await File.fromUri(Uri.parse(audio.path)).readAsBytes(), filename: 'audio.m4a', contentType:  MediaType('audio','m4a')));
    final streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      // Parse the JSON response
      var jsonResponse = jsonDecode(response.body);

      // Extract the content field
      print(jsonResponse);
      String content = jsonResponse['text'];

      String keyPhrase = "Cosa cerchi?";

      if (content.startsWith(keyPhrase)) {
          content = content.substring(keyPhrase.length).trim(); // .trim() removes leading/trailing whitespace
      }
     return content; // Process and return the response
    } else {
      final errorMessage = 'Failed call to OpenAI Whisper:\nStatus code: ${response.statusCode}\nHeaders: ${response.headers}\nBody: ${response.body}\n';
      print(response.statusCode);
      print(response.headers);
      print(response.body);
      throw Exception(errorMessage);
    }
  }

  Future<String> analyzeImage(File imageFile, String question, String detail, String context) async {
    // Replace [API_ENDPOINT] with the actual endpoint of the OpenAI API for image analysis
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    print("Asking OpenAI");

    // Resize to 512x512
    String base64Image;
    if (detail == "low") {
      File resizedImage = await resizeImage(imageFile.path, 512, 512);
      // Convert image file to base64
      final bytes = await resizedImage.readAsBytes();
      base64Image = base64Encode(bytes);
    } else {
      final bytes = await imageFile.readAsBytes();
      base64Image = base64Encode(bytes);
    }

    // Prepare the request body
    var body = jsonEncode(
        {
          "model": "gpt-4-vision-preview",
          "messages": [
            {
              "role": "system",
              "content": [
                {"type": "text", "text": context},
              ]
            },
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": question
                },
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/jpeg;base64,$base64Image}",
                    "detail": detail
                  }
                }
              ]
            }
          ],
          "max_tokens": 300
        }
    );

    // Send the request
    final response = await http.post(uri, headers: headers, body: body);
    if (response.statusCode == 200) {
      // Parse the JSON response
      var jsonResponse = jsonDecode(response.body);

      // Extract the content field
      String content = jsonResponse['choices'][0]['message']['content'];

      return content; // Process and return the response
    } else {
      final errorMessage = 'Failed call to OpenAI:\nStatus code: '+response.statusCode.toString()+'\nHeaders: '+response.headers.toString()+'\nBody: '+response.body+'\n';
      //print(response.statusCode);
      //print(response.headers);
      //print(response.body);
      throw Exception(errorMessage);
    }
  }
}