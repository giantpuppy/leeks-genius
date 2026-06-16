import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/ticket.dart';
import '../utils/status_colors.dart';
import '../widgets/status_badge.dart';
import '../widgets/ticket_clipper.dart';
import '../widgets/warm_spotlight.dart';
import '../widgets/breathing_icon.dart';

class UnifiedShowDetailScreen extends StatefulWidget {
  final int performanceId;

  const UnifiedShowDetailScreen({super.key, required this.performanceId});

  @override
  State<UnifiedShowDetailScreen> createState() =>
      _UnifiedShowDetailScreenState();
}

class _UnifiedShowDetailScreenState extends State<UnifiedShowDetailScreen> {
  // 数据
  Show? _show;
  Performance? _currentPerf;
  List<CastMember> _castMembers = [];
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  // 编辑控制器
  late TextEditingController _seatController;
  late TextEditingController _priceController;
  late TextEditingController _actualPriceController;
  String _selectedDate = '';
  String _selectedTime = '';

  @override
  void initState() {
    super.initState();
    _seatController = TextEditingController();
    _priceController = TextEditingController();
    _actualPriceController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _seatController.dispose();
    _priceController.dispose();
    _actualPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final detail = await db.getPerformanceDetail(widget.performanceId);
    if (detail == null) {
      setState(() => _isLoading = false);
      return;
    }

    final showId = detail['show_id'] as int;
    final show = await db.getShowById(showId);
    final perfs = await db.getPerformancesByShowId(showId);
    final cast = await db.getCastMembersByPerformanceId(widget.performanceId);
    final tickets = await db.getTicketsByPerformanceId(widget.performanceId);

    final currentPerf =
        perfs.firstWhere((p) => p.id == widget.performanceId);

    // 自动检测：bought + 日期已过 → watched
    String status = currentPerf.status ?? 'unmarked';
    if (status == 'bought' && _isPastDate(currentPerf.date)) {
      status = 'watched';
    }

    setState(() {
      _show = show;
      _currentPerf = currentPerf.copyWith(status: status);
      _castMembers = cast;
      _tickets = tickets;
      _selectedDate = currentPerf.date;
      _selectedTime = currentPerf.time ?? '19:30';
      _seatController.text = currentPerf.seat ?? '';
      _priceController.text =
          currentPerf.price != null ? currentPerf.price!.toStringAsFixed(0) : '';
      _actualPriceController.text = currentPerf.actualPrice != null
          ? currentPerf.actualPrice!.toStringAsFixed(0)
          : '';
      _isLoading = false;
    });
  }

  bool _isPastDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }

  String get _status => _currentPerf?.status ?? 'unmarked';

  /// 切换想看状态（仅未买票时有效）
  void _toggleWantToSee() {
    if (_status == 'bought' || _status == 'watched') return;
    setState(() {
      final newStatus = _status == 'want_to_see' ? 'unmarked' : 'want_to_see';
      _currentPerf = _currentPerf!.copyWith(status: newStatus);
      _hasChanges = true;
    });
  }

  /// 根据票根数量自动更新状态
  void _autoUpdateStatus() {
    if (_tickets.isNotEmpty) {
      _currentPerf = _currentPerf!.copyWith(
        status: _isPastDate(_selectedDate) ? 'watched' : 'bought',
      );
    } else {
      _currentPerf = _currentPerf!.copyWith(status: 'unmarked');
    }
  }

  Future<void> _save() async {
    if (_currentPerf == null) return;
    final db = DatabaseHelper.instance;

    final updated = Performance(
      id: _currentPerf!.id,
      showId: _currentPerf!.showId,
      date: _selectedDate,
      time: _selectedTime,
      seat: _seatController.text.isNotEmpty ? _seatController.text : null,
      price: double.tryParse(_priceController.text),
      actualPrice: double.tryParse(_actualPriceController.text),
      status: _currentPerf!.status,
      createdAt: _currentPerf!.createdAt,
    );

    await db.updatePerformance(updated);

    // 更新卡司
    await db.deleteCastMembersByPerformanceId(_currentPerf!.id!);
    for (final cast in _castMembers) {
      await db.createCastMember(CastMember(
        performanceId: _currentPerf!.id!,
        role: cast.role,
        actorName: cast.actorName,
        isFeatured: cast.isFeatured,
      ));
    }

    // 更新票根
    await db.deleteTicketsByPerformanceId(_currentPerf!.id!);
    for (final ticket in _tickets) {
      await db.createTicket(Ticket(
        performanceId: _currentPerf!.id!,
        seat: ticket.seat,
        price: ticket.price,
        actualPrice: ticket.actualPrice,
      ));
    }

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  Future<void> _deletePerformance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('确认删除', style: TextStyle(color: Colors.white)),
        content: const Text('确定要删除这场演出记录吗？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      await db.deleteTicketsByPerformanceId(_currentPerf!.id!);
      await db.deleteCastMembersByPerformanceId(_currentPerf!.id!);
      await db.deletePerformance(_currentPerf!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B5BCD),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickTime() async {
    final parts = _selectedTime.split(':');
    final current = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 19,
      minute: int.tryParse(parts[1]) ?? 30,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B5BCD),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _hasChanges = true;
      });
    }
  }

  void _addTicket() {
    setState(() {
      _tickets.add(Ticket(
        performanceId: _currentPerf!.id!,
        seat: null,
        price: null,
        actualPrice: null,
      ));
      _autoUpdateStatus();
      _hasChanges = true;
    });
  }

  void _removeTicket(int index) {
    setState(() {
      _tickets.removeAt(index);
      _autoUpdateStatus();
      _hasChanges = true;
    });
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_show == null || _currentPerf == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('场次详情')),
        body: const Center(child: Text('未找到场次信息')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: _hasChanges
          ? FloatingActionButton(
              onPressed: _save,
              backgroundColor: kBrandPurple,
              shape: const StadiumBorder(),
              child: const Icon(Icons.check, color: Colors.white),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // 海报 AppBar
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 场次信息卡片（票根风格）
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // 卡司区
                  _buildCastSection(),
                  const SizedBox(height: 24),

                  // 票根区（仅已买/已看）
                  if (_status == 'bought' || _status == 'watched') ...[
                    _buildTicketSection(),
                    const SizedBox(height: 24),
                  ],

                  // 底部留白
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SliverAppBar（海报舞台光渐变） ====================

  Widget _buildSliverAppBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final expandedHeight = (screenWidth * 0.55).clamp(260.0, 360.0);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: const Color(0xFF121212),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _onBackPressed,
      ),
      actions: [
        // 状态星星入口
        _buildStatusStarEntry(),
        // 删除按钮
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white70),
          onPressed: _deletePerformance,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final t = (constraints.maxHeight - kToolbarHeight) /
                (expandedHeight - kToolbarHeight);
            final opacity = t.clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                alignment: Alignment.bottomLeft,
                child: Text(
                  _show!.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (screenWidth * 0.055).clamp(18.0, 26.0),
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 海报背景
            _buildPosterBackground(),
            // 多 stop 渐变蒙层：透明 → black26 → black78 → #121212
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black26,
                    Colors.black87,
                    Color(0xFF121212),
                  ],
                  stops: [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部右侧状态星星入口
  Widget _buildStatusStarEntry() {
    final statusColorVal = statusColor(_status);

    // unmarked: 灰色
    // want_to_see: 紫色发光
    // bought/watched: 状态色 badge
    if (_status == 'unmarked') {
      return GestureDetector(
        onTap: _toggleWantToSee,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star_border, color: Color(0xFF555555), size: 22),
        ),
      );
    }

    if (_status == 'want_to_see') {
      return GestureDetector(
        onTap: _toggleWantToSee,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kBrandPurple.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kBrandPurple.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.star_rounded, color: Color(0xFF811FE2), size: 22),
        ),
      );
    }

    // bought / watched: 状态色 badge
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: StatusBadge(
        label: _status == 'bought' ? '已买' : '已观演',
        color: statusColorVal,
        fontSize: 11,
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  void _onBackPressed() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('未保存的修改', style: TextStyle(color: Colors.white)),
          content: const Text('是否保存？', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('不保存', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _save();
                if (mounted) Navigator.pop(context, true);
              },
              child: const Text('保存', style: TextStyle(color: kBrandPurple)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildPosterBackground() {
    final hasCover =
        _show!.coverPath != null && _show!.coverPath!.isNotEmpty;

    if (hasCover) {
      return Image.file(
        File(_show!.coverPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientFallback(),
      );
    }
    return _buildGradientFallback();
  }

  Widget _buildGradientFallback() {
    final color1 = coverColorForShow(_show!.id ?? 0);
    final color2 = kCoverColors[((_show!.id ?? 0).abs() + 3) % kCoverColors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
      ),
      child: Center(
        child: Text(
          _show!.name.length >= 2 ? _show!.name.substring(0, 2) : _show!.name,
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==================== 场次信息卡片（票根风格） ====================

  Widget _buildInfoCard() {
    final dateTime = DateTime.tryParse(_selectedDate);
    final weekday =
        dateTime != null ? DateFormat('EEEE', 'zh_CN').format(dateTime) : '';
    final statusColorVal = statusColor(_status);
    final showId = _show!.id ?? 0;

    return ClipPath(
      clipper: const TicketClipper(notchRadius: 10, cornerRadius: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: coverColorForShow(showId).withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧状态色竖条
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColorVal,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // 内容区
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日期 + 星期 + 时间（大层级）
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        GestureDetector(
                          onTap: _pickDate,
                          child: Row(
                            children: [
                              Text(
                                '${dateTime?.month ?? '--'}月${dateTime?.day ?? '--'}日',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                weekday,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kBrandPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time,
                                    size: 13, color: kBrandPurple),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kBrandPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 剧场 + 座位
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _show!.theater ?? '未知剧场',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_seatController.text.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.event_seat,
                              size: 14, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            _seatController.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 状态胶囊 + 卡司头像行
                    Row(
                      children: [
                        StatusBadge(
                          label: _statusLabel(_status),
                          color: statusColorVal,
                          fontSize: 11,
                          borderRadius: 10,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                        ),
                        const SizedBox(width: 12),
                        if (_castMembers.isNotEmpty)
                          Expanded(child: _buildCastAvatars()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'unmarked' => '未标记',
      'want_to_see' => '想看',
      'bought' => '已买',
      'watched' => '已观演',
      _ => '未标记',
    };
  }

  Widget _buildCastAvatars() {
    const avatarColors = [
      Color(0xFF6B5BCD),
      Color(0xFFE06B75),
      Color(0xFF4ECDC4),
      Color(0xFFFFB347),
      Color(0xFF77DD77),
      Color(0xFF89CFF0),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: _castMembers.length.clamp(0, 6),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cast = _castMembers[index];
          final name = cast.actorName.isNotEmpty ? cast.actorName : '?';
          final initial = name.substring(0, 1);
          final color = avatarColors[index % avatarColors.length];

          return CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(
              initial,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 卡司区（只读） ====================

  Widget _buildCastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: kBrandPurple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '本场卡司',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_castMembers.length}人',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        if (_castMembers.isEmpty)
          _buildCastEmptyState()
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 表头
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '角色',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '演员',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 数据行
                ..._castMembers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cast = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      border: i > 0
                          ? const Border(
                              top: BorderSide(
                                  color: Color(0xFF222222), width: 0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cast.role.isEmpty ? '-' : cast.role,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cast.actorName.isEmpty ? '-' : cast.actorName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              if (cast.isFeatured == true) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star,
                                  size: 12,
                                  color: kWarmGold,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCastEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          BreathingIcon(
            icon: Icons.people_outline,
            size: 48,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无卡司信息',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 票根区 ====================

  Widget _buildTicketSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with purple bar and warm-glow add button
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: kBrandPurple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '票根',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_tickets.length}张',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              WarmSpotlight(
                color: kWarmGold,
                minAlpha: 0.1,
                maxAlpha: 0.25,
                minBlur: 6,
                maxBlur: 12,
                borderRadius: 10,
                child: GestureDetector(
                  onTap: _addTicket,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kWarmGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: kWarmGold.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: kWarmGold),
                        SizedBox(width: 4),
                        Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: kWarmGold,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_tickets.isEmpty)
          _buildTicketEmptyState()
        else
          ..._tickets.asMap().entries.map((entry) {
            final i = entry.key;
            final ticket = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _tickets.length - 1 ? 12 : 0),
              child: _buildTicketCard(i, ticket),
            );
          }),
      ],
    );
  }

  Widget _buildTicketEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          BreathingIcon(
            icon: Icons.confirmation_num_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无票根，点击上方按钮添加',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(int index, Ticket ticket) {
    final accentColor = index == 0 ? kBrandPurple : kWarmGold;

    return ClipPath(
      clipper: const TicketClipper(notchRadius: 8, cornerRadius: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 左侧 accent 竖条
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // 内容区
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Icon(Icons.confirmation_num_outlined,
                            size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          '票根 ${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _removeTicket(index),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 座位
                    _buildTicketField(
                      icon: Icons.event_seat,
                      value: ticket.seat ?? '',
                      placeholder: '点击输入座位',
                      onTap: () {
                        final ctrl =
                            TextEditingController(text: ticket.seat ?? '');
                        _showEditDialog('座位', ctrl, (v) {
                          setState(() {
                            _tickets[index] =
                                ticket.copyWith(seat: v.isEmpty ? null : v);
                            _hasChanges = true;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // 票价行
                    Row(
                      children: [
                        Expanded(
                          child: _buildTicketField(
                            icon: Icons.confirmation_number_outlined,
                            value: ticket.price != null
                                ? '¥${ticket.price!.toStringAsFixed(0)}'
                                : '',
                            placeholder: '¥票面',
                            onTap: () {
                              final ctrl = TextEditingController(
                                  text: ticket.price?.toStringAsFixed(0) ?? '');
                              _showEditDialog('票面价格', ctrl, (v) {
                                setState(() {
                                  _tickets[index] = ticket.copyWith(
                                      price: double.tryParse(v));
                                  _hasChanges = true;
                                });
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTicketField(
                            icon: Icons.payments_outlined,
                            value: ticket.actualPrice != null
                                ? '¥${ticket.actualPrice!.toStringAsFixed(0)}'
                                : '',
                            placeholder: '¥实付',
                            onTap: () {
                              final ctrl = TextEditingController(
                                  text: ticket.actualPrice?.toStringAsFixed(0) ??
                                      '');
                              _showEditDialog('实付价格', ctrl, (v) {
                                setState(() {
                                  _tickets[index] = ticket.copyWith(
                                      actualPrice: double.tryParse(v));
                                  _hasChanges = true;
                                });
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketField({
    required IconData icon,
    required String value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF6B5BCD)),
          const SizedBox(width: 6),
          Text(
            value.isNotEmpty ? value : placeholder,
            style: TextStyle(
              fontSize: 13,
              color: value.isNotEmpty
                  ? Colors.white.withValues(alpha: 0.85)
                  : const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      String label, TextEditingController controller, ValueChanged<String> onChanged) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogController = TextEditingController(text: controller.text);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text('输入$label', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: TextField(
            controller: dialogController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            keyboardType: label.contains('价格') || label.contains('票面') || label.contains('实付')
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF181818),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBrandPurple, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () {
                controller.text = dialogController.text;
                onChanged(dialogController.text);
                Navigator.pop(ctx);
              },
              child: const Text('确定', style: TextStyle(color: kBrandPurple, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }
}
