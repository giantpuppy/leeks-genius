import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'data_backup.dart';

class DataBackup {
  static Future<void> exportToJson() async {
    final exportData = await DataBackupCore.exportData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
    final bytes = utf8.encode(jsonStr);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download',
          '排期助手备份_${DateTime.now().toIso8601String().split('T').first}.json')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  static Future<String?> importFromJson() async {
    final completer = Completer<String?>();

    final input = html.FileUploadInputElement()..accept = '.json';
    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }

      final reader = html.FileReader();
      reader.onLoadEnd.listen((event) async {
        final result = await DataBackupCore.importData(reader.result as String);
        completer.complete(result);
      });

      reader.onError.listen((event) {
        completer.complete('读取文件失败');
      });

      reader.readAsText(files.first);
    });

    input.click();
    return completer.future;
  }
}
