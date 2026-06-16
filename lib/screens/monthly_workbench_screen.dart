import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../utils/status_colors.dart';
import '../widgets/breathing_icon.dart';
import 'add_show_screen.dart';
import 'show_management_screen.dart';

/// 月度管理工作台 — 海报网格画廊
/// 2列海报网格，年月选择器，点击进入剧目管理
class MonthlyWorkbenchScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthlyWorkbenchScreen({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<MonthlyWorkbenchScreen> createState() => _MonthlyWorkbenchScreenState();
}

class _MonthlyWorkbenchScreenState extends State<MonthlyWorkbenchScreen> {
  bool _isLoading = true;
  late int _year;
  late int _month;
  List<Show> _shows = [];
  Map<int, int> _showPerformanceCounts = {};

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final perfs = await db.getPerformancesByMonth(_year, _month);

    // 按 showId 去重，获取剧目列表
    final showIds = <int>{};
    final counts = <int, int>{};
    for (final perf in perfs) {
      final showId = perf['show_id'] as int;
      showIds.add(showId);
      counts[showId] = (counts[showId] ?? 0) + 1;
    }

    final shows = <Show>[];
    for (final showId in showIds) {
      final show = await db.getShowById(showId);
      if (show != null) shows.add(show);
    }

    if (mounted) {
      setState(() {
        _shows = shows;
        _showPerformanceCounts = counts;
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) {
        _month = 1;
        _year++;
      } else if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _loadData();
  }

  Future<void> _pickMonth() async {
    final initialDate = DateTime(_year, _month, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(2030, 12),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B5BCD),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
      });
      _loadData();
    }
  }

  Future<void> _navigateToShowManagement(Show show) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShowManagementScreen(showId: show.id!),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _addNewShow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddShowScreen()),
    );
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridSpacing = screenWidth * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left, color: Colors.white70),
              onPressed: () => _changeMonth(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 28,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickMonth,
              child: Text(
                '$_year年$_month月',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_right, color: Colors.white70),
              onPressed: () => _changeMonth(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 28,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! > 0) {
            _changeMonth(-1); // swipe right → previous month
          } else if (details.primaryVelocity! < 0) {
            _changeMonth(1); // swipe left → next month
          }
        },
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: kBrandPurple),
              )
            : _shows.isEmpty
                ? _buildEmptyState()
                : _buildPosterGrid(gridSpacing),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BreathingIcon(
            icon: Icons.event_busy_outlined,
            size: 72,
            color: Color(0xFF4D4D4D),
          ),
          const SizedBox(height: 20),
          Text(
            '这个月还没有排期',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewShow,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加剧目'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrandPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterGrid(double spacing) {
    return GridView.count(
      padding: EdgeInsets.all(spacing),
      crossAxisCount: 2,
      childAspectRatio: 3 / 4,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      children: _shows.map((show) => _buildPosterCard(show)).toList(),
    );
  }

  Widget _buildPosterCard(Show show) {
    final coverPath = show.coverPath;
    final color = coverColorForShow(show.id ?? 0);
    final count = _showPerformanceCounts[show.id] ?? 0;

    return GestureDetector(
      onTap: () => _navigateToShowManagement(show),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            // Bottom shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            // Colored glow
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image or gradient fallback
            if (coverPath != null && coverPath.isNotEmpty)
              Image.file(
                File(coverPath),
                fit: BoxFit.cover,
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.6)],
                  ),
                ),
                child: Center(
                  child: Text(
                    show.name.length >= 2
                        ? show.name.substring(0, 2)
                        : show.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Performance count badge (top-right)
            if (count > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$count场',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Show name at bottom with gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Text(
                  show.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
