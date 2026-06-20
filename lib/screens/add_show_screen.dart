import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';
import '../models/ticket.dart';
import '../utils/ocr_service.dart';
import '../utils/knowledge_base.dart';
import '../utils/cover_helper.dart';
import '../widgets/show_header_editor.dart';
import '../widgets/show_table_editor.dart';
import 'show_management_screen.dart';

class AddShowScreen extends StatefulWidget {
  final Show? initialShow;
  final List<Performance>? initialPerformances;
  final bool isEditMode;

  const AddShowScreen({
    super.key,
    this.initialShow,
    this.initialPerformances,
    this.isEditMode = false,
  });

  @override
  State<AddShowScreen> createState() => _AddShowScreenState();
}

class _AddShowScreenState extends State<AddShowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _theaterController = TextEditingController();
  final List<PerformanceEntry> _performances = [];
  final List<RoleColumn> _roles = [];

  bool _isSaving = false;
  bool _isRecognizing = false;
  List<CastEntry>? _lastOcrRawResult;
  List<String> _actorNames = [];
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.initialShow != null) {
      _nameController.text = widget.initialShow!.name;
      _theaterController.text = widget.initialShow!.theater ?? '';
      _coverPath = widget.initialShow!.coverPath;
      _loadEditModeData();
    } else {
      _addPerformance();
      _addRole();
    }
    _loadActorNames();
  }

  Future<void> _loadEditModeData() async {
    final perfs = widget.initialPerformances ?? [];
    final data = await ShowTableData.fromPerformanceList(perfs);
    _performances.addAll(data.performances);
    _roles.addAll(data.roles);

    if (_performances.isEmpty) {
      _addPerformance();
    }
    if (_roles.isEmpty) {
      _addRole();
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadActorNames() async {
    final actors = await DatabaseHelper.instance.getAllActors();
    if (mounted) {
      setState(() {
        _actorNames = actors.map((a) => a.name).toList();
      });
    }
  }

  void _addPerformance() {
    setState(() {
      _performances.add(PerformanceEntry());
      for (final role in _roles) {
        role.sync(_performances.length);
      }
    });
  }

  void _removePerformance(int index) {
    setState(() {
      final removed = _performances.removeAt(index);
      removed.dispose();
      for (final role in _roles) {
        role.sync(_performances.length);
      }
    });
  }

  void _addRole() {
    setState(() {
      final role = RoleColumn();
      role.sync(_performances.length);
      _roles.add(role);
    });
  }

  void _removeRole(int index) {
    setState(() {
      _roles[index].dispose();
      _roles.removeAt(index);
    });
  }

  // ==================== OCR ====================

  Future<void> _pickImageAndRecognize() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isRecognizing = true);
    try {
      final bytes = await picked.readAsBytes();
      String text;
      try {
        text = await recognizeTextAuto(bytes);
      } on BaiduOcrException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('百度 OCR 失败: $e，请检查配置')),
          );
        }
        return;
      }

      if (text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未识别到文字，请尝试更清晰的图片')),
          );
        }
        return;
      }

      if (mounted) {
        if (isScheduleFormat(text)) {
          final schedule = parseSchedule(text);
          if (schedule.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未解析到排期信息')),
              );
            }
            return;
          }
          if (schedule.isNotEmpty) {
            _lastOcrRawResult = schedule.first.castList;
          }
          final correctedSchedule = await _correctSchedule(schedule);
          _fillScheduleToForm(correctedSchedule);
        } else {
          final castList = parseCastText(text);
          if (castList.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未识别到卡司信息，请尝试手动输入')),
              );
            }
            return;
          }
          _lastOcrRawResult = castList;
          final corrected = await correctOcrResult(
            showName: null,
            theater: null,
            castList: castList,
          );
          final castEntries = corrected.castList
              .map((c) => CastEntry(c.role, c.actor))
              .toList();
          _fillCastListToForm(castEntries);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  Future<List<ScheduleEntry>> _correctSchedule(List<ScheduleEntry> schedule) async {
    final corrected = <ScheduleEntry>[];
    for (final entry in schedule) {
      final result = await correctOcrResult(
        showName: null,
        theater: null,
        castList: entry.castList,
      );
      corrected.add(ScheduleEntry(
        date: entry.date,
        time: entry.time,
        castList: result.castList.map((c) => CastEntry(c.role, c.actor)).toList(),
      ));
    }
    return corrected;
  }

  void _fillCastListToForm(List<CastEntry> castList) {
    final oldRoles = List<RoleColumn>.from(_roles);
    setState(() {
      _roles.clear();
      for (final entry in castList) {
        final role = RoleColumn();
        role.roleController.text = entry.role;
        role.sync(_performances.length);
        if (_performances.isNotEmpty) {
          role.actorControllers[0].text = entry.actor;
        }
        _roles.add(role);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final r in oldRoles) { r.dispose(); }
    });
  }

  void _fillScheduleToForm(List<ScheduleEntry> schedule) {
    final oldPerformances = List<PerformanceEntry>.from(_performances);
    final oldRoles = List<RoleColumn>.from(_roles);
    setState(() {
      _performances.clear();
      _roles.clear();

      if (schedule.isNotEmpty) {
        final firstEntry = schedule.first;
        for (final cast in firstEntry.castList) {
          final role = RoleColumn();
          role.roleController.text = cast.role;
          role.sync(schedule.length);
          _roles.add(role);
        }

        for (var i = 0; i < schedule.length; i++) {
          final entry = schedule[i];
          final perf = PerformanceEntry();
          perf.dateController.text = entry.date;
          perf.time = entry.time;
          _performances.add(perf);

          for (var j = 0; j < entry.castList.length && j < _roles.length; j++) {
            _roles[j].actorControllers[i].text = entry.castList[j].actor;
          }
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final p in oldPerformances) { p.dispose(); }
      for (final r in oldRoles) { r.dispose(); }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已填充 ${schedule.length} 场演出，${schedule.first.castList.length} 个角色')),
    );
  }

  // ==================== 事务级保存 ====================

  Future<void> _saveShow() async {
    if (!_formKey.currentState!.validate()) return;
    if (_performances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一场演出')));
      return;
    }
    for (int i = 0; i < _performances.length; i++) {
      if (_performances[i].dateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请填写第${i + 1}场的日期')));
        return;
      }
    }

    setState(() => _isSaving = true);
    int? newShowId;
    try {
      final db = DatabaseHelper.instance;
      final showName = _nameController.text.trim();
      final theater = _theaterController.text.trim().isNotEmpty
          ? _theaterController.text.trim() : null;

      // 编辑模式下：海报改名联动
      String? finalCoverPath = _coverPath;
      if (widget.isEditMode && widget.initialShow != null) {
        final oldName = widget.initialShow!.name;
        if (oldName != showName && _coverPath != null && _coverPath!.isNotEmpty) {
          finalCoverPath = await CoverHelper.renameCoverImage(_coverPath, showName);
        }
      }

      if (widget.isEditMode && widget.initialShow != null) {
        // 编辑模式：更新 show + 事务替换 performances
        final updatedShow = widget.initialShow!.copyWith(
          name: showName,
          theater: theater,
          coverPath: finalCoverPath,
        );
        await db.updateShow(updatedShow);
        newShowId = updatedShow.id;

        // 构建 performances + casts 数据
        final perfDataList = <Map<String, dynamic>>[];
        for (int pi = 0; pi < _performances.length; pi++) {
          final perfEntry = _performances[pi];
          final casts = <CastMember>[];
          for (final role in _roles) {
            final roleName = role.roleController.text.trim();
            final actorName = role.actorControllers[pi].text.trim();
            if (roleName.isNotEmpty && actorName.isNotEmpty) {
              casts.add(CastMember(
                performanceId: 0, // 会在 replaceAllPerformances 中被替换
                role: roleName,
                actorName: actorName,
                isFeatured: false,
                createdAt: DateTime.now().toIso8601String(),
              ));
            }
          }
          perfDataList.add({
            'performance': Performance(
              showId: widget.initialShow!.id!,
              date: perfEntry.dateController.text,
              time: perfEntry.time,
              status: 'unmarked',
              createdAt: DateTime.now().toIso8601String(),
            ),
            'casts': casts,
            'ticket': _buildTicketFromPerfEntry(perfEntry),
          });
        }
        await db.replaceAllPerformances(widget.initialShow!.id!, perfDataList);
      } else {
        // 新增模式：事务级保存
        final show = await db.createShow(Show(
          name: showName,
          theater: theater,
          coverPath: finalCoverPath,
          isInScheduleFlow: false,
          createdAt: DateTime.now().toIso8601String(),
        ));

        final perfDataList = <Map<String, dynamic>>[];
        for (int pi = 0; pi < _performances.length; pi++) {
          final perfEntry = _performances[pi];
          final casts = <CastMember>[];
          for (final role in _roles) {
            final roleName = role.roleController.text.trim();
            final actorName = role.actorControllers[pi].text.trim();
            if (roleName.isNotEmpty && actorName.isNotEmpty) {
              casts.add(CastMember(
                performanceId: 0,
                role: roleName,
                actorName: actorName,
                isFeatured: false,
                createdAt: DateTime.now().toIso8601String(),
              ));
            }
          }
          perfDataList.add({
            'performance': Performance(
              showId: show.id!,
              date: perfEntry.dateController.text,
              time: perfEntry.time,
              status: 'unmarked',
              createdAt: DateTime.now().toIso8601String(),
            ),
            'casts': casts,
            'ticket': _buildTicketFromPerfEntry(perfEntry),
          });
        }
        await db.replaceAllPerformances(show.id!, perfDataList);
        newShowId = show.id;
      }

      // 保存到知识库（如果数据来自OCR识别）
      if (_lastOcrRawResult != null && _roles.isNotEmpty && _performances.isNotEmpty) {
        final finalCastList = <CastEntry>[];
        for (final role in _roles) {
          final roleName = role.roleController.text.trim();
          final actorName = role.actorControllers[0].text.trim();
          if (roleName.isNotEmpty && actorName.isNotEmpty) {
            finalCastList.add(CastEntry(roleName, actorName));
          }
        }
        await saveToKnowledgeBase(
          showName: _nameController.text.trim(),
          theater: _theaterController.text.trim().isNotEmpty
              ? _theaterController.text.trim() : null,
          castList: finalCastList,
          originalCastList: _lastOcrRawResult,
        );
      }

      // 创建演员记录
      for (final role in _roles) {
        for (int pi = 0; pi < _performances.length; pi++) {
          final actorName = role.actorControllers[pi].text.trim();
          if (actorName.isNotEmpty) {
            try {
              await db.createActor(Actor(
                name: actorName,
                createdAt: DateTime.now().toIso8601String(),
              ));
            } catch (_) {}
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEditMode ? '剧目更新成功！' : '剧目添加成功！')));
        if (widget.isEditMode || newShowId == null) {
          Navigator.pop(context, true);
        } else {
          // 新建剧目后直接进入剧目管理页，使用统一界面继续管理
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ShowManagementScreen(showId: newShowId!),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _theaterController.dispose();
    for (final p in _performances) { p.dispose(); }
    for (final r in _roles) { r.dispose(); }
    super.dispose();
  }

  Widget _buildAiRecognitionCard() {
    return GestureDetector(
      onTap: _isRecognizing ? null : _pickImageAndRecognize,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF6B5BCD).withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B5BCD).withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF6B5BCD).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isRecognizing
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.document_scanner_outlined,
                      color: Color(0xFF6B5BCD),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecognizing ? 'AI 识别中...' : 'AI 识别排期 / 卡司',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '上传排期表或卡司表截图，自动提取剧目、场次、角色、演员',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  // 根据 perfEntry 中的价格控件生成 Ticket；没有价格数据时返回 null。
  Ticket? _buildTicketFromPerfEntry(PerformanceEntry perfEntry) {
    final price = double.tryParse(perfEntry.priceController.text.trim());
    final actualPrice = double.tryParse(perfEntry.actualPriceController.text.trim());
    if (price == null && actualPrice == null) return null;
    return Ticket(
      performanceId: 0, // 会在 replaceAllPerformances 中被替换
      price: price,
      actualPrice: actualPrice,
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditMode ? '编辑剧目' : '添加剧目',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  // 1. 剧目信息卡片
                  _buildShowInfoCard(),
                  const SizedBox(height: 16),

                  // 2. AI 识别入口（核心入口）
                  _buildAiRecognitionCard(),
                  const SizedBox(height: 16),

                  // 3. 手动录入区域
                  _buildManualSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // 底部保存按钮
            _buildBottomSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveShow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B5BCD),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF6B5BCD).withValues(alpha: 0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ShowHeaderEditor(
        nameController: _nameController,
        theaterController: _theaterController,
        coverPath: _coverPath,
        show: widget.initialShow,
        onCoverChanged: (path) => setState(() => _coverPath = path),
      ),
    );
  }

  Widget _buildManualSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分区标题
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B5BCD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '手动录入',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addPerformance,
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF6B5BCD)),
              label: const Text('添加场次', style: TextStyle(color: Color(0xFF6B5BCD))),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 表格（自带空状态）
        ShowTableEditor(
          performances: _performances,
          roles: _roles,
          actorNames: _actorNames,
          onAddPerformance: _addPerformance,
          onRemovePerformance: _removePerformance,
          onAddRole: _addRole,
          onRemoveRole: _removeRole,
          onLoadActorNames: _loadActorNames,
        ),
      ],
    );
  }
}
