import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

Future<String> recognizeText(Uint8List imageBytes) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await tempFile.writeAsBytes(imageBytes);

  final inputImage = InputImage.fromFilePath(tempFile.path);
  final recognizer = TextRecognizer();
  final result = await recognizer.processImage(inputImage);
  await recognizer.close();
  await tempFile.delete();
  return result.text;
}
