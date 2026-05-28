import '../database/database_helper.dart';
import '../models/ocr_correction.dart';
import '../models/show_template.dart';
import '../models/actor.dart';
import '../utils/ocr_service.dart' show CastEntry;
import '../utils/fuzzy_matcher.dart';

/// OCR 纠错后的结果，包含修改标记用于 UI 高亮
class CorrectedCastEntry {
  final String role;
  final String actor;
  final bool roleCorrected;   // 角色名是否被知识库纠正
  final bool actorCorrected;  // 演员名是否被知识库纠正
  final String? originalRole; // 原始 OCR 识别的角色名（如果有纠正）
  final String? originalActor;// 原始 OCR 识别的演员名（如果有纠正）

  CorrectedCastEntry({
    required this.role,
    required this.actor,
    this.roleCorrected = false,
    this.actorCorrected = false,
    this.originalRole,
    this.originalActor,
  });
}

class CorrectedResult {
  final String? showName;
  final String? theater;
  final List<CorrectedCastEntry> castList;
  final bool showNameCorrected;
  final bool theaterCorrected;
  final ShowTemplate? matchedTemplate;

  CorrectedResult({
    this.showName,
    this.theater,
    required this.castList,
    this.showNameCorrected = false,
    this.theaterCorrected = false,
    this.matchedTemplate,
  });
}

// ===== 纠错入口 =====

/// 对 OCR 识别结果进行知识库纠错
///
/// 纠错优先级：
/// 1. 精确匹配 ocr_corrections（ocr_text 完全一致）
/// 2. 模糊匹配 ocr_corrections（相似度 ≥ 0.6）
/// 3. 模糊匹配 show_templates.roles（角色名）
/// 4. 模糊匹配 actors.name（演员名）
Future<CorrectedResult> correctOcrResult({
  required String? showName,
  required String? theater,
  required List<CastEntry> castList,
}) async {
  final db = DatabaseHelper.instance;

  // 1. 纠正剧目名
  String? correctedShowName = showName;
  bool showCorrected = false;
  ShowTemplate? matchedTemplate;

  if (showName != null && showName.isNotEmpty) {
    // 1a. 精确匹配 ocr_corrections
    final showCorrection = await db.getOcrCorrectionByText(showName, 'show_name');
    if (showCorrection != null) {
      correctedShowName = showCorrection.correctedText;
      showCorrected = true;
    } else {
      // 1b. 模糊匹配 show_templates
      final templates = await db.getAllShowTemplates();
      final templateNames = templates.map((t) => t.name).toList();
      final match = FuzzyMatcher.findBestMatch(showName, templateNames, threshold: 0.6);
      if (match.match != null) {
        correctedShowName = match.match;
        matchedTemplate = templates.firstWhere((t) => t.name == match.match);
        showCorrected = true;
      }
    }
  }

  // 2. 纠正剧场
  String? correctedTheater = theater;
  bool theaterCorrected = false;
  if (theater != null && theater.isNotEmpty) {
    final theaterCorrection = await db.getOcrCorrectionByText(theater, 'theater');
    if (theaterCorrection != null) {
      correctedTheater = theaterCorrection.correctedText;
      theaterCorrected = true;
    }
  }

  // 3. 准备角色和演员的候选列表
  final roleCorrections = await db.getOcrCorrectionsByCategory('role');
  final actorCorrections = await db.getOcrCorrectionsByCategory('actor');
  final allActors = await db.getAllActors();
  final actorNames = allActors.map((a) => a.name).toList();

  // 模板角色列表（如果匹配到模板）
  final templateRoleNames = matchedTemplate?.roles ?? [];

  // 4. 逐条纠正卡司
  final correctedCastList = <CorrectedCastEntry>[];

  for (final entry in castList) {
    var correctedRole = entry.role;
    var correctedActor = entry.actor;
    var roleWasCorrected = false;
    var actorWasCorrected = false;
    String? originalRole;
    String? originalActor;

    // 4a. 纠正角色名
    // 精确匹配 ocr_corrections
    final roleCorr = roleCorrections.where((c) => c.ocrText == entry.role).firstOrNull;
    if (roleCorr != null) {
      originalRole = entry.role;
      correctedRole = roleCorr.correctedText;
      roleWasCorrected = true;
    } else if (templateRoleNames.isNotEmpty) {
      // 模糊匹配模板角色
      final roleMatch = FuzzyMatcher.findBestMatch(entry.role, templateRoleNames, threshold: 0.5);
      if (roleMatch.match != null && roleMatch.match != entry.role) {
        originalRole = entry.role;
        correctedRole = roleMatch.match!;
        roleWasCorrected = true;
      }
    }

    // 4b. 纠正演员名
    // 精确匹配 ocr_corrections
    final actorCorr = actorCorrections.where((c) => c.ocrText == entry.actor).firstOrNull;
    if (actorCorr != null) {
      originalActor = entry.actor;
      correctedActor = actorCorr.correctedText;
      actorWasCorrected = true;
    } else if (actorNames.isNotEmpty) {
      // 模糊匹配演员库
      final actorMatch = FuzzyMatcher.findBestMatch(entry.actor, actorNames, threshold: 0.5);
      if (actorMatch.match != null && actorMatch.match != entry.actor) {
        originalActor = entry.actor;
        correctedActor = actorMatch.match!;
        actorWasCorrected = true;
      }
    }

    correctedCastList.add(CorrectedCastEntry(
      role: correctedRole,
      actor: correctedActor,
      roleCorrected: roleWasCorrected,
      actorCorrected: actorWasCorrected,
      originalRole: originalRole,
      originalActor: originalActor,
    ));
  }

  return CorrectedResult(
    showName: correctedShowName,
    theater: correctedTheater,
    castList: correctedCastList,
    showNameCorrected: showCorrected,
    theaterCorrected: theaterCorrected,
    matchedTemplate: matchedTemplate,
  );
}

// ===== 保存入口 =====

/// 保存用户确认后的数据到知识库
///
/// [originalCastList] 是 OCR 原始解析结果，用于建立纠错映射
Future<void> saveToKnowledgeBase({
  required String showName,
  required String? theater,
  required List<CastEntry> castList,
  List<CastEntry>? originalCastList,
}) async {
  final db = DatabaseHelper.instance;
  final now = DateTime.now().toIso8601String();

  // 1. 保存/更新剧目模板
  final roles = castList.map((c) => c.role).toList();
  await db.createShowTemplate(ShowTemplate(
    name: showName,
    theater: theater,
    roles: roles,
    updatedAt: now,
  ));

  // 2. 保存演员到 actors 表（已有逻辑，这里额外确保）
  for (final entry in castList) {
    if (entry.actor.isNotEmpty) {
      await db.createActor(Actor(name: entry.actor));
    }
  }

  // 3. 保存 OCR 纠错映射（原始 vs 最终）
  if (originalCastList != null && originalCastList.length == castList.length) {
    for (var i = 0; i < castList.length; i++) {
      final original = originalCastList[i];
      final corrected = castList[i];

      // 角色名纠错映射
      if (original.role != corrected.role &&
          original.role.isNotEmpty &&
          corrected.role.isNotEmpty) {
        await db.createOcrCorrection(OcrCorrection(
          ocrText: original.role,
          correctedText: corrected.role,
          category: 'role',
          createdAt: now,
        ));
      }

      // 演员名纠错映射
      if (original.actor != corrected.actor &&
          original.actor.isNotEmpty &&
          corrected.actor.isNotEmpty) {
        await db.createOcrCorrection(OcrCorrection(
          ocrText: original.actor,
          correctedText: corrected.actor,
          category: 'actor',
          createdAt: now,
        ));
      }
    }
  }
}
