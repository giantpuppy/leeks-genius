import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

@JS('ocrRecognize')
external JSPromise<JSAny?> _ocrRecognize(JSString dataUrl);

Future<String> recognizeText(Uint8List imageBytes) async {
  final base64 = base64Encode(imageBytes);
  final dataUrl = 'data:image/jpeg;base64,$base64';
  final result = await _ocrRecognize(dataUrl.toJS).toDart;
  return result?.toString() ?? '';
}
