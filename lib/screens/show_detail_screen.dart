import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';

class ShowDetailScreen extends StatefulWidget {
  final int performanceId;

  const ShowDetailScreen({super.key, required this.performanceId});

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  Map<String, dynamic>? _detail;
  List<CastMember> _castMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final detail = await db.getPerformanceDetail(widget.performanceId);
    final cast = await db.getCastMembersByPerformanceId(widget.performanceId);

    setState(() {
      _detail = detail;
      _castMembers = cast;
      _isLoading = false;
    });
  }

  Future<void> _deletePerformance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这场演出记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      await db.deleteCastMembersByPerformanceId(widget.performanceId);
      await db.deletePerformance(widget.performanceId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('场次详情')),
        body: const Center(child: Text('未找到场次信息')),
      );
    }

    final date = _detail!['date'] as String;
    final dateTime = DateTime.parse(date);
    final weekday = DateFormat('EEEE', 'zh_CN').format(dateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('场次详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deletePerformance,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date section
            _buildSection(
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$date $weekday',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Show info section
            _buildSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _detail!['show_name'] ?? '未知剧目',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 22, color: const Color(0xFFB3B3B3)),
                      const SizedBox(width: 4),
                      Text(
                        _detail!['theater'] ?? '未知剧场',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFFB3B3B3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Time, seat, price section
            _buildSection(
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.access_time,
                    label: '开场时间',
                    value: _detail!['time'] ?? '未设置',
                  ),
                  if (_detail!['seat'] != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.event_seat,
                      label: '座位',
                      value: _detail!['seat'] as String,
                    ),
                  ],
                  if (_detail!['price'] != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.attach_money,
                      label: '票价',
                      value: '¥${_detail!['price']}',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Cast section
            if (_castMembers.isNotEmpty) ...[
              Text(
                '本场演员',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildSection(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              '角色',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '演员',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._castMembers.map((cast) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: const Color(0xFF2A2A2A)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                cast.role,
                                style: const TextStyle(color: Color(0xFFB3B3B3)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                cast.actorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB3B3B3)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFFB3B3B3)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
