import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import 'ocr_mobile.dart' if (dart.library.html) 'ocr_web.dart';
export 'ocr_mobile.dart' if (dart.library.html) 'ocr_web.dart';

// ===== 百度 OCR 配置 =====

class BaiduOcrKeys {
  final String? apiKey;
  final String? secretKey;
  final int quota;
  const BaiduOcrKeys({this.apiKey, this.secretKey, this.quota = BaiduOcrConfig.defaultQuota});
  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty && secretKey != null && secretKey!.isNotEmpty;
}

class BaiduOcrConfig {
  static const _apiKeyPrefix = 'baidu_ocr_api_key_';
  static const _secretKeyPrefix = 'baidu_ocr_secret_key_';
  static const _quotaPrefix = 'baidu_ocr_quota_';
  static const defaultQuota = 1000;

  static Future<String> _username() async {
    return (await UserService.getCurrentUsername()) ?? 'default';
  }

  static Future<BaiduOcrKeys> load() async {
    final user = await _username();
    final prefs = await SharedPreferences.getInstance();
    return BaiduOcrKeys(
      apiKey: prefs.getString('$_apiKeyPrefix$user'),
      secretKey: prefs.getString('$_secretKeyPrefix$user'),
      quota: prefs.getInt('$_quotaPrefix$user') ?? defaultQuota,
    );
  }

  static Future<void> save({required String apiKey, required String secretKey, int? quota}) async {
    final user = await _username();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_apiKeyPrefix$user', apiKey);
    await prefs.setString('$_secretKeyPrefix$user', secretKey);
    if (quota != null) {
      await prefs.setInt('$_quotaPrefix$user', quota);
    }
  }

  static Future<void> clear() async {
    final user = await _username();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_apiKeyPrefix$user');
    await prefs.remove('$_secretKeyPrefix$user');
    await prefs.remove('$_quotaPrefix$user');
  }
}

// ===== 百度 OCR 额度计数（按 API Key 独立计数） =====

class BaiduOcrUsage {
  static const _countPrefix = 'baidu_ocr_usage_count_';
  static const _monthPrefix = 'baidu_ocr_usage_month_';
  static Future<int> getQuota() async {
    final config = await BaiduOcrConfig.load();
    return config.quota;
  }

  static Future<String> _apiKey() async {
    final keys = await BaiduOcrConfig.load();
    return keys.apiKey ?? '';
  }

  static Future<int> getUsage() async {
    final key = await _apiKey();
    if (key.isEmpty) return 0;

    final prefs = await SharedPreferences.getInstance();
    final countKey = '$_countPrefix$key';
    final monthKey = '$_monthPrefix$key';
    final savedMonth = prefs.getString(monthKey) ?? '';
    final currentMonth = _currentMonthKey();

    if (savedMonth != currentMonth) {
      await prefs.setString(monthKey, currentMonth);
      await prefs.setInt(countKey, 0);
      return 0;
    }
    return prefs.getInt(countKey) ?? 0;
  }

  static Future<void> increment() async {
    final key = await _apiKey();
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final countKey = '$_countPrefix$key';
    final current = await getUsage();
    await prefs.setInt(countKey, current + 1);
  }

  static Future<void> clear() async {
    final key = await _apiKey();
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_countPrefix$key');
    await prefs.remove('$_monthPrefix$key');
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}

// ===== 百度 OCR 调用 =====

class BaiduOcrException implements Exception {
  final String message;
  BaiduOcrException(this.message);
  @override
  String toString() => 'BaiduOcrException: $message';
}

/// 使用百度通用文字识别（标准版）识别图片
/// 文档: https://cloud.baidu.com/doc/OCR/s/zk3h7xw5e
Future<String> recognizeWithBaidu(Uint8List imageBytes, {bool highAccuracy = false}) async {
  if (kIsWeb) {
    throw BaiduOcrException('Web 端暂不支持百度 OCR（浏览器跨域限制），请在移动端 App 中使用，或继续使用本地识别');
  }

  final keys = await BaiduOcrConfig.load();
  if (!keys.isConfigured) {
    throw BaiduOcrException('百度 OCR 未配置，请先设置 API Key');
  }

  // 1. 获取 access_token
  final token = await _getAccessToken(keys.apiKey!, keys.secretKey!);

  // 2. 调用 OCR 接口
  final endpoint = highAccuracy
      ? 'https://aip.baidubce.com/rest/2.0/ocr/v1/general'
      : 'https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic';
  final url = Uri.parse('$endpoint?access_token=$token');

  final base64Image = base64Encode(imageBytes);
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {'image': base64Image, 'language_type': 'CHN_ENG'},
  );

  if (response.statusCode != 200) {
    throw BaiduOcrException('HTTP ${response.statusCode}: ${response.body}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;

  if (json['error_code'] != null) {
    final code = json['error_code'];
    final msg = json['error_msg'] ?? '';
    if (code == 18 || msg.contains('qps') || msg.contains('limit')) {
      throw BaiduOcrException('百度 OCR 请求太频繁（QPS 超限），请稍等几秒再试');
    }
    throw BaiduOcrException('$code: $msg');
  }

  final results = json['words_result'] as List<dynamic>?;
  if (results == null || results.isEmpty) {
    await BaiduOcrUsage.increment();
    return '';
  }

  await BaiduOcrUsage.increment();
  return results.map((r) => r['words'] as String).join('\n');
}

/// 测试百度 OCR 连接（仅验证 Key 是否能获取 Token）
Future<String> testBaiduOcrConnection() async {
  if (kIsWeb) {
    return 'Web 端暂不支持百度 OCR，请在移动端 App 中使用';
  }

  final keys = await BaiduOcrConfig.load();
  if (!keys.isConfigured) {
    return '未配置 API Key';
  }

  try {
    final token = await _getAccessToken(keys.apiKey!, keys.secretKey!);
    if (token.isNotEmpty) {
      return '连接成功！Key 配置正确';
    }
    return '获取 Token 失败';
  } on BaiduOcrException catch (e) {
    return '连接失败: ${e.message}';
  } catch (e) {
    return '连接失败: $e';
  }
}

/// 自动选择引擎：配置了百度Key就用百度，否则用本地Tesseract
Future<String> recognizeTextAuto(Uint8List imageBytes) async {
  final keys = await BaiduOcrConfig.load();
  if (keys.isConfigured) {
    try {
      return await recognizeWithBaidu(imageBytes);
    } on BaiduOcrException catch (_) {
      // 百度失败时降级到本地
      rethrow;
    }
  }
  return recognizeText(imageBytes);
}

Future<String> _getAccessToken(String apiKey, String secretKey) async {
  final url = Uri.parse(
    'https://aip.baidubce.com/oauth/2.0/token'
    '?grant_type=client_credentials'
    '&client_id=$apiKey'
    '&client_secret=$secretKey',
  );

  final response = await http.post(url);
  if (response.statusCode != 200) {
    throw BaiduOcrException('获取 Token 失败: HTTP ${response.statusCode}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final token = json['access_token'] as String?;
  if (token == null || token.isEmpty) {
    throw BaiduOcrException('获取 Token 失败: ${json['error_description'] ?? json['error']}');
  }
  return token;
}

/// 单场卡司信息
class CastEntry {
  final String role;
  final String actor;
  const CastEntry(this.role, this.actor);
}

/// 排期表中的一场演出
class ScheduleEntry {
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final List<CastEntry> castList;
  const ScheduleEntry({required this.date, required this.time, required this.castList});
}

/// 从 OCR 文本中解析角色-演员对应关系（简单模式）
List<CastEntry> parseCastText(String text) {
  final results = <CastEntry>[];
  final lines = text.split('\n');

  final skipPatterns = [
    RegExp(r'^\s*卡司\s*$', caseSensitive: false),
    RegExp(r'^\s*cast\s*$', caseSensitive: false),
    RegExp(r'^\s*主演\s*$'),
    RegExp(r'^\s*演员表\s*$'),
    RegExp(r'^\s*角色\s*$'),
    RegExp(r'^\s*演员\s*$'),
    RegExp(r'^\s*排期\s*$'),
    RegExp(r'^\s*日期\s*$'),
    RegExp(r'^\s*时间\s*$'),
    RegExp(r'^\s*剧院\s*$'),
    RegExp(r'^\s*剧场\s*$'),
    RegExp(r'^\s*本场\s*$'),
    RegExp(r'^\s*今日\s*$'),
    RegExp(r'^\s*卡司排期\s*$', caseSensitive: false),
    RegExp(r'^\s*演出场次\s*$'),
    RegExp(r'^\s*casting\s*$', caseSensitive: false),
  ];

  for (final rawLine in lines) {
    var line = rawLine.trim();
    if (line.isEmpty) continue;

    line = line.replaceFirst(RegExp(r'^[_\-·•\s]+'), '');
    if (skipPatterns.any((p) => p.hasMatch(line))) continue;
    if (RegExp(r'^\d+$').hasMatch(line)) continue;
    // 跳过包含日期+时间的行（排期表数据行用 parseSchedule 处理）
    if (RegExp(r'\d+月\d+日').hasMatch(line)) continue;

    final separators = ['  ', '\t', '——', '—', '–', '-', '：', ':', '·', '•'];
    String? foundRole;
    String? foundActor;

    for (final sep in separators) {
      if (!line.contains(sep)) continue;
      final idx = line.indexOf(sep);
      final role = line.substring(0, idx).trim();
      final actor = line.substring(idx + sep.length).trim();
      if (_isValidName(role) && _isValidName(actor)) {
        foundRole = role;
        foundActor = actor;
        break;
      }
    }

    if (foundRole == null) {
      final parts = line.split(' ');
      if (parts.length == 2 && _isValidName(parts[0]) && _isValidName(parts[1])) {
        foundRole = parts[0];
        foundActor = parts[1];
      }
    }

    if (foundRole != null && foundActor != null) {
      results.add(CastEntry(foundRole, foundActor));
    }
  }

  return results;
}

/// 从 OCR 文本中解析排期表（多场次 + 多角色）
///
/// 支持两种格式：
/// 格式 A（正常表格）：
///   演出场次 顾静薇 瞿健雄 丁奚林
///   5月29日（周五）19:30 孙新雨 张会芳 关皓天
///
/// 格式 B（Tesseract 混乱 OCR，每行一个单元格）：
///   CASTING SCHEDULE
///   演出场次
///   顾静薇
///   瞿健雄
///   丁奚林
///   5月29日（周五）19:30
///   孙新雨
///   张会芳
///   关皓天
List<ScheduleEntry> parseSchedule(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final entries = <ScheduleEntry>[];

  // 1. 找关键词位置——优先找表格真正的表头行 "演出场次" / "CASTING"
  // 避免被 "卡司排期" 等标题干扰（标题通常在表格上方，中间有很多噪声）
  int headerIndex = -1;

  // 第一轮：找最具体的表头关键词
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('演出场次') ||
        lines[i].contains('CASTING') ||
        lines[i].contains('SCHEDULE')) {
      headerIndex = i;
      break;
    }
  }

  // 第二轮：找 "场次"（但排除 "卡司排期"）
  if (headerIndex == -1) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('场次') && !line.contains('卡司')) {
        headerIndex = i;
        break;
      }
    }
  }

  // 第三轮："卡司排期" 作为最后的 fallback
  if (headerIndex == -1) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('卡司排期')) {
        headerIndex = i;
        break;
      }
    }
  }

  if (headerIndex == -1) return entries;

  // 2. 找出所有日期行位置
  final dateIndices = <int>[];
  for (var i = headerIndex + 1; i < lines.length; i++) {
    if (_extractDateTime(lines[i]) != null) {
      dateIndices.add(i);
    }
  }
  if (dateIndices.isEmpty) return entries;

  // 3. 推断角色数：看每场之间有多少个像演员名的文本
  final counts = <int>[];
  for (var i = 0; i < dateIndices.length; i++) {
    final start = dateIndices[i] + 1;
    final end = (i + 1 < dateIndices.length) ? dateIndices[i + 1] : lines.length;
    var count = 0;
    for (var j = start; j < end; j++) {
      if (_isValidName(lines[j]) && _looksLikeRoleOrActor(lines[j])) count++;
    }
    counts.add(count);
  }

  final roleCount = _mode(counts);
  if (roleCount == null || roleCount < 2 || roleCount > 10) return entries;

  // 4. 提取角色：关键词之后、第一个日期之前
  var roles = <String>[];
  for (var i = headerIndex + 1; i < dateIndices.first && roles.length < roleCount; i++) {
    if (_isValidName(lines[i]) && _looksLikeRoleOrActor(lines[i])) {
      roles.add(lines[i]);
    }
  }

  // 如果角色不够，用第一场的演员反向推断
  if (roles.length < roleCount) {
    final firstActors = <String>[];
    for (var j = dateIndices.first + 1; j < (dateIndices.length > 1 ? dateIndices[1] : lines.length); j++) {
      if (_isValidName(lines[j]) && _looksLikeRoleOrActor(lines[j])) {
        firstActors.add(lines[j]);
      }
    }
    if (firstActors.length >= roleCount) {
      roles = firstActors.sublist(0, roleCount);
    }
  }

  if (roles.isEmpty) return entries;

  // 5. 提取每场
  for (var i = 0; i < dateIndices.length; i++) {
    final dt = _extractDateTime(lines[dateIndices[i]])!;
    final actors = <String>[];
    final start = dateIndices[i] + 1;
    final end = (i + 1 < dateIndices.length) ? dateIndices[i + 1] : lines.length;

    for (var j = start; j < end && actors.length < roles.length; j++) {
      if (_isValidName(lines[j]) && _looksLikeRoleOrActor(lines[j])) {
        actors.add(lines[j]);
      }
    }

    // 也尝试从日期行本身提取演员（正常表格格式）
    if (actors.length < roles.length) {
      final inlineActors = _extractActors(lines[dateIndices[i]], roles.length);
      if (inlineActors.length >= roles.length) {
        actors.clear();
        actors.addAll(inlineActors.sublist(0, roles.length));
      }
    }

    if (actors.length >= roles.length) {
      final castList = <CastEntry>[];
      for (var j = 0; j < roles.length; j++) {
        castList.add(CastEntry(roles[j], actors[j]));
      }
      entries.add(ScheduleEntry(
        date: dt.date,
        time: dt.time,
        castList: castList,
      ));
    }
  }

  return entries;
}

/// 检测 OCR 文本是排期表格式还是简单卡司格式
bool isScheduleFormat(String text) {
  final lines = text.split('\n');
  var hasHeader = false;
  var dateTimeLines = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.contains('演出场次') ||
        trimmed.contains('卡司排期') ||
        trimmed.contains('CASTING') ||
        trimmed.contains('SCHEDULE') ||
        trimmed.contains('场次')) {
      hasHeader = true;
    }
    if (_extractDateTime(trimmed) != null) {
      dateTimeLines++;
    }
  }

  // 放宽条件：有表头 + 至少1个日期行 即尝试排期表解析
  return hasHeader && dateTimeLines >= 1;
}

// ===== 内部辅助 =====

List<String> _splitLine(String line) {
  return line.split(RegExp(r'[\s\t]+')).where((p) => p.isNotEmpty).toList();
}

({String date, String time, String raw})? _extractDateTime(String line) {
  // 匹配 2026年5月29日...19:30 或 5月29日...19：30（支持中英文冒号）
  final patterns = [
    (
      regex: RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日.*?(\d{1,2})[:：](\d{2})'),
      yearGroup: 1,
      monthGroup: 2,
      dayGroup: 3,
      hourGroup: 4,
      minGroup: 5,
    ),
    (
      regex: RegExp(r'(\d{1,2})月(\d{1,2})日.*?(\d{1,2})[:：](\d{2})'),
      yearGroup: null,
      monthGroup: 1,
      dayGroup: 2,
      hourGroup: 3,
      minGroup: 4,
    ),
  ];

  for (final p in patterns) {
    final m = p.regex.firstMatch(line);
    if (m != null) {
      final year = p.yearGroup != null
          ? m.group(p.yearGroup!)!
          : DateTime.now().year.toString();
      final month = m.group(p.monthGroup)!.padLeft(2, '0');
      final day = m.group(p.dayGroup)!.padLeft(2, '0');
      final hour = m.group(p.hourGroup)!.padLeft(2, '0');
      final minute = m.group(p.minGroup)!;
      final raw = m.group(0)!;
      return (
        date: '$year-$month-$day',
        time: '$hour:$minute',
        raw: raw,
      );
    }
  }
  return null;
}

List<String> _extractActors(String line, int roleCount) {
  var remaining = line;
  final dt = _extractDateTime(line);
  if (dt != null) {
    final idx = line.indexOf(dt.raw);
    if (idx >= 0) {
      remaining = line.substring(idx + dt.raw.length);
    }
  }

  final parts = _splitLine(remaining);
  return parts.where((p) {
    if (p.isEmpty || p.length > 10) return false;
    if (RegExp(r'^\d+$').hasMatch(p)) return false;
    if (p.contains('地点') || p.contains('剧院') || p.contains('剧场')) return false;
    return true;
  }).toList();
}

// 已知噪声词：App UI 元素、购票平台文案等
const _noiseWords = {
  '详情', '热评', '须知', '推荐',
  '已想看', '已买', '缺货登记', '立即购买',
  '卡司排期', '演出场次', 'CASTING', 'SCHEDULE',
  '加场', '我们在', '春日里', '相逢',
};

/// 判断字符串是否像角色/演员名（更严格的过滤）
bool _looksLikeRoleOrActor(String name) {
  if (name.length < 2 || name.length > 8) return false;
  // 排除包含数字的
  if (RegExp(r'\d').hasMatch(name)) return false;
  // 排除全英文
  if (RegExp(r'^[A-Za-z\s]+$').hasMatch(name)) return false;
  // 排除特殊符号
  if (name.contains('·') || name.contains('•') || name.contains('★') || name.contains('☆')) return false;
  // 排除纯标点
  if (RegExp(r'^[\p{P}\s]+$').hasMatch(name)) return false;
  return true;
}

/// 取列表的众数
int? _mode(List<int> values) {
  if (values.isEmpty) return null;
  final freq = <int, int>{};
  for (final v in values) {
    freq[v] = (freq[v] ?? 0) + 1;
  }
  var maxCount = 0;
  int? mode;
  for (final entry in freq.entries) {
    if (entry.value > maxCount) {
      maxCount = entry.value;
      mode = entry.key;
    }
  }
  return mode;
}

bool _isValidName(String name) {
  if (name.isEmpty || name.length > 20 || name.length < 2) return false;
  if (RegExp(r'^\d+$').hasMatch(name)) return false;
  if (name.contains('排期') || name.contains('演出')) return false;
  // 排除全英文（通常不是中文角色/演员名）
  if (RegExp(r'^[A-Za-z\s]+$').hasMatch(name)) return false;
  // 排除包含评分、特殊符号的
  if (name.contains('★') || name.contains('☆')) return false;
  // 排除已知噪声词
  for (final noise in _noiseWords) {
    if (name.contains(noise)) return false;
  }
  return true;
}
