import 'dart:convert';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/actor.dart';
import '../models/cast_member.dart';
export 'data_backup_io.dart' if (dart.library.html) 'data_backup_web.dart';

class DataBackupCore {
  static Future<Map<String, dynamic>> exportData() async {
    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    final performances = await db.getAllPerformances();
    final actors = await db.getAllActors();
    final castMembers = await db.getAllCastMembers();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'shows': shows.map((s) => s.toMap()).toList(),
      'performances': performances.map((p) => p.toMap()).toList(),
      'actors': actors.map((a) => a.toMap()).toList(),
      'castMembers': castMembers.map((c) => c.toMap()).toList(),
    };
  }

  static Future<String?> importData(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      await _doImport(data);
      return '导入成功';
    } catch (e) {
      return '导入失败: $e';
    }
  }

  static Future<void> _doImport(Map<String, dynamic> data) async {
    final db = DatabaseHelper.instance;

    final allPerfs = await db.getAllPerformances();
    for (final p in allPerfs) {
      if (p.id != null) {
        await db.deleteCastMembersByPerformanceId(p.id!);
        await db.deletePerformance(p.id!);
      }
    }
    final allShows = await db.getAllShows();
    for (final s in allShows) {
      if (s.id != null) await db.deleteShow(s.id!);
    }
    final allActors = await db.getAllActors();
    for (final a in allActors) {
      if (a.id != null) await db.deleteActor(a.id!);
    }

    final showIdMap = <int, int>{};
    final shows = data['shows'] as List<dynamic>? ?? [];
    for (final s in shows) {
      final oldId = s['id'] as int?;
      final newShow = await db.createShow(Show(
        name: s['name'] as String,
        theater: s['theater'] as String?,
        createdAt: s['created_at'] as String?,
      ));
      if (oldId != null && newShow.id != null) {
        showIdMap[oldId] = newShow.id!;
      }
    }

    final actorIdMap = <int, int>{};
    final actors = data['actors'] as List<dynamic>? ?? [];
    for (final a in actors) {
      final oldId = a['id'] as int?;
      try {
        final newActor = await db.createActor(Actor(
          name: a['name'] as String,
          note: a['note'] as String?,
          createdAt: a['created_at'] as String?,
        ));
        if (oldId != null && newActor.id != null) {
          actorIdMap[oldId] = newActor.id!;
        }
      } catch (_) {
        final existing = await db.getActorByName(a['name'] as String);
        if (oldId != null && existing?.id != null) {
          actorIdMap[oldId] = existing!.id!;
        }
      }
    }

    final perfIdMap = <int, int>{};
    final performances = data['performances'] as List<dynamic>? ?? [];
    for (final p in performances) {
      final oldId = p['id'] as int?;
      final oldShowId = p['show_id'] as int?;
      final newShowId = showIdMap[oldShowId] ?? oldShowId;

      final newPerf = await db.createPerformance(Performance(
        showId: newShowId ?? 0,
        date: p['date'] as String,
        time: p['time'] as String?,
        seat: p['seat'] as String?,
        price: p['price'] != null ? (p['price'] as num).toDouble() : null,
        actualPrice: p['actual_price'] != null
            ? (p['actual_price'] as num).toDouble()
            : null,
        status: p['status'] as String? ?? 'unmarked',
        createdAt: p['created_at'] as String?,
      ));
      if (oldId != null && newPerf.id != null) {
        perfIdMap[oldId] = newPerf.id!;
      }
    }

    final castMembers = data['castMembers'] as List<dynamic>? ??
        (data['cast_members'] as List<dynamic>? ?? []);
    for (final c in castMembers) {
      final oldPerfId = c['performance_id'] as int?;
      final newPerfId = perfIdMap[oldPerfId] ?? oldPerfId;
      if (newPerfId != null) {
        await db.createCastMember(CastMember(
          performanceId: newPerfId,
          role: c['role'] as String,
          actorName: c['actor_name'] as String,
          isFeatured: (c['is_featured'] as int?) == 1 ||
              (c['is_featured'] as bool?) == true,
          createdAt: c['created_at'] as String?,
        ));
      }
    }
  }
}
