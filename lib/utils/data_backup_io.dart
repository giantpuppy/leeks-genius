import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'data_backup.dart';

class DataBackup {
  static Future<void> exportToJson() async {
    final exportData = await DataBackupCore.exportData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
    final bytes = utf8.encode(jsonStr);

    final tempDir = await getTemporaryDirectory();
    final fileName = '排期助手备份_${DateTime.now().toIso8601String().split('T').first}.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '排期助手数据备份',
    );
  }

  static Future<String?> importFromJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null; // 用户取消
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      return '读取文件失败';
    }

    final content = utf8.decode(bytes);
    return DataBackupCore.importData(content);
  }
}
