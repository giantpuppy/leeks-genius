import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';

Future<void> seedTestData() async {
  final db = DatabaseHelper.instance;

  // 如果已有数据则跳过
  final shows = await db.getAllShows();
  if (shows.isNotEmpty) return;

  // 创建剧目
  final show = await db.createShow(Show(
    name: '春逝',
    theater: '国家话剧院',
    createdAt: DateTime.now().toIso8601String(),
  ));

  // 角色定义
  final roles = ['顾静薇', '瞿健雄', '丁奚林'];

  // Excel 数据：日期 | 时间 | 顾静薇 | 瞿健雄 | 丁奚林
  final data = [
    {'date': '2026-05-29', 'time': '19:30', 'cast': ['孙新雨', '张会芳', '关皓天']},
    {'date': '2026-05-30', 'time': '14:30', 'cast': ['路雯', '赵艾尼苏', '关皓天']},
    {'date': '2026-05-30', 'time': '19:30', 'cast': ['吕昕蔚', '路雯', '李晓辉']},
    {'date': '2026-05-31', 'time': '14:30', 'cast': ['吕昕蔚', '赵艾尼苏', '李晓辉']},
    {'date': '2026-05-31', 'time': '19:30', 'cast': ['路雯', '张会芳', '关皓天']},
  ];

  for (final item in data) {
    final perf = await db.createPerformance(Performance(
      showId: show.id!,
      date: item['date'] as String,
      time: item['time'] as String,
      status: 'unmarked',
      createdAt: DateTime.now().toIso8601String(),
    ));

    final cast = item['cast'] as List<String>;
    for (int i = 0; i < roles.length; i++) {
      await db.createCastMember(CastMember(
        performanceId: perf.id!,
        role: roles[i],
        actorName: cast[i],
        isFeatured: true,
        createdAt: DateTime.now().toIso8601String(),
      ));

      try {
        await db.createActor(Actor(
          name: cast[i],
          createdAt: DateTime.now().toIso8601String(),
        ));
      } catch (_) {
        // 演员已存在（unique 约束），忽略
      }
    }
  }
}
