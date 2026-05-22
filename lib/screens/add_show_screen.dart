import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';

class AddShowScreen extends StatefulWidget {
  const AddShowScreen({super.key});

  @override
  State<AddShowScreen> createState() => _AddShowScreenState();
}

class _PerformanceEntry {
  TextEditingController dateController;
  TextEditingController timeController;
  TextEditingController seatController;
  TextEditingController priceController;
  List<_CastEntry> casts;

  _PerformanceEntry()
      : dateController = TextEditingController(),
        timeController = TextEditingController(text: '19:30'),
        seatController = TextEditingController(),
        priceController = TextEditingController(),
        casts = [];
}

class _CastEntry {
  TextEditingController roleController;
  TextEditingController actorController;

  _CastEntry()
      : roleController = TextEditingController(),
        actorController = TextEditingController();
}

class _AddShowScreenState extends State<AddShowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _theaterController = TextEditingController();
  final List<_PerformanceEntry> _performances = [];
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  bool _isSaving = false;
  bool _isOcrProcessing = false;

  @override
  void initState() {
    super.initState();
    _addPerformance();
  }

  void _addPerformance() {
    setState(() {
      _performances.add(_PerformanceEntry()..casts.add(_CastEntry()));
    });
  }

  void _removePerformance(int index) {
    setState(() {
      _performances.removeAt(index);
    });
  }

  void _addCast(int perfIndex) {
    setState(() {
      _performances[perfIndex].casts.add(_CastEntry());
    });
  }

  void _removeCast(int perfIndex, int castIndex) {
    setState(() {
      _performances[perfIndex].casts.removeAt(castIndex);
    });
  }

  Future<void> _pickDate(_PerformanceEntry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      entry.dateController.text = _dateFormat.format(picked);
    }
  }

  Future<void> _pickTime(_PerformanceEntry entry) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 30),
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      entry.timeController.text = _timeFormat.format(dt);
    }
  }

  Future<void> _saveShow() async {
    if (!_formKey.currentState!.validate()) return;

    if (_performances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一场演出')),
      );
      return;
    }

    // Validate performances
    for (int i = 0; i < _performances.length; i++) {
      final p = _performances[i];
      if (p.dateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请填写第${i + 1}场的日期')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final db = DatabaseHelper.instance;

      // Create show
      final show = await db.createShow(Show(
        name: _nameController.text.trim(),
        theater: _theaterController.text.trim().isNotEmpty
            ? _theaterController.text.trim()
            : null,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // Create performances
      for (final perfEntry in _performances) {
        final performance = await db.createPerformance(Performance(
          showId: show.id!,
          date: perfEntry.dateController.text,
          time: perfEntry.timeController.text.isNotEmpty
              ? perfEntry.timeController.text
              : null,
          seat: perfEntry.seatController.text.isNotEmpty
              ? perfEntry.seatController.text
              : null,
          price: perfEntry.priceController.text.isNotEmpty
              ? double.tryParse(perfEntry.priceController.text)
              : null,
          createdAt: DateTime.now().toIso8601String(),
        ));

        // Create cast members
        for (final castEntry in perfEntry.casts) {
          if (castEntry.roleController.text.isNotEmpty &&
              castEntry.actorController.text.isNotEmpty) {
            await db.createCastMember(CastMember(
              performanceId: performance.id!,
              role: castEntry.roleController.text.trim(),
              actorName: castEntry.actorController.text.trim(),
              createdAt: DateTime.now().toIso8601String(),
            ));

            // Also add to actors table
            await db.createActor(Actor(
              name: castEntry.actorController.text.trim(),
              createdAt: DateTime.now().toIso8601String(),
            ));
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剧目添加成功！')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // OCR Text Recognition
  Future<void> _processOcr() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isOcrProcessing = true);

    try {
      final inputImage = InputImage.fromFile(File(picked.path));
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      _parseOcrText(recognizedText.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别完成，已提取 ${recognizedText.blocks.length} 个文本块')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOcrProcessing = false);
    }
  }

  void _parseOcrText(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Simple heuristic parsing
    final dateRegex = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日');
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final fullDateRegex = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})');

    final parsedPerformances = <_PerformanceEntry>[];
    _PerformanceEntry? currentPerf;
    bool parsingCasts = false;

    for (final line in lines) {
      final trimmed = line.trim();

      // Try to find show name (first non-date, non-time, non-empty line)
      if (_nameController.text.isEmpty &&
          !dateRegex.hasMatch(trimmed) &&
          !timeRegex.hasMatch(trimmed) &&
          trimmed.length > 2 &&
          trimmed.length < 30) {
        _nameController.text = trimmed;
        continue;
      }

      // Try to find theater
      if (_theaterController.text.isEmpty &&
          (trimmed.contains('剧院') ||
              trimmed.contains('剧场') ||
              trimmed.contains('大剧院') ||
              trimmed.contains('艺术中心'))) {
        _theaterController.text = trimmed;
        continue;
      }

      // Date line starts new performance
      final dateMatch = fullDateRegex.firstMatch(trimmed);
      final shortDateMatch = dateRegex.firstMatch(trimmed);

      if (dateMatch != null || shortDateMatch != null) {
        currentPerf = _PerformanceEntry();
        parsingCasts = false;

        if (dateMatch != null) {
          currentPerf.dateController.text =
              '${dateMatch.group(1)!}-${dateMatch.group(2)!.padLeft(2, '0')}-${dateMatch.group(3)!.padLeft(2, '0')}';
        } else if (shortDateMatch != null) {
          final now = DateTime.now();
          currentPerf.dateController.text =
              '${now.year}-${shortDateMatch.group(1)!.padLeft(2, '0')}-${shortDateMatch.group(2)!.padLeft(2, '0')}';
        }

        final timeMatch = timeRegex.firstMatch(trimmed);
        if (timeMatch != null) {
          currentPerf.timeController.text =
              '${timeMatch.group(1)!.padLeft(2, '0')}:${timeMatch.group(2)!}';
        }

        parsedPerformances.add(currentPerf);
        continue;
      }

      // Time only
      if (currentPerf != null &&
          timeRegex.hasMatch(trimmed) &&
          !dateRegex.hasMatch(trimmed)) {
        final timeMatch = timeRegex.firstMatch(trimmed);
        if (timeMatch != null) {
          currentPerf.timeController.text =
              '${timeMatch.group(1)!.padLeft(2, '0')}:${timeMatch.group(2)!}';
        }
        continue;
      }

      // Cast members - try to parse "角色: 演员" or "角色 演员" patterns
      if (currentPerf != null) {
        // Check for "角色" or "演员" keywords
        if (trimmed.contains('角色') || trimmed.contains('演员') || trimmed.contains('卡司')) {
          parsingCasts = true;
          continue;
        }

        if (parsingCasts) {
          final parts = trimmed.split(RegExp(r'[\s:]+'));
          if (parts.length >= 2) {
            final cast = _CastEntry()
              ..roleController.text = parts[0].trim()
              ..actorController.text = parts.sublist(1).join(' ').trim();
            currentPerf.casts.add(cast);
          }
        }
      }
    }

    setState(() {
      if (parsedPerformances.isNotEmpty) {
        _performances.clear();
        _performances.addAll(parsedPerformances);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _theaterController.dispose();
    for (final p in _performances) {
      p.dateController.dispose();
      p.timeController.dispose();
      p.seatController.dispose();
      p.priceController.dispose();
      for (final c in p.casts) {
        c.roleController.dispose();
        c.actorController.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('添加剧目'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveShow,
              child: const Text('保存'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Show name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '* 剧目名称',
                hintText: '请输入剧目名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.theaters),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入剧目名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Theater
            TextFormField(
              controller: _theaterController,
              decoration: const InputDecoration(
                labelText: '剧场',
                hintText: '请输入演出剧场',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Performances section
            Row(
              children: [
                Text(
                  '场次排期',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addPerformance,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加场次'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Performance list
            ..._performances.asMap().entries.map((entry) {
              final index = entry.key;
              final perf = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Performance header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '第 ${index + 1} 场',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_performances.length > 1)
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              onPressed: () => _removePerformance(index),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Date and time
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: perf.dateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: '* 演出日期',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              onTap: () => _pickDate(perf),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请选择日期';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: perf.timeController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: '开场时间',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              onTap: () => _pickTime(perf),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Seat and price
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: perf.seatController,
                              decoration: const InputDecoration(
                                labelText: '座位',
                                hintText: '如: 1排1座',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.event_seat_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: perf.priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '票价',
                                hintText: '如: 180',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Cast members
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            '本场演员',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _addCast(index),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('添加演员'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Cast header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
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
                            SizedBox(width: 40),
                          ],
                        ),
                      ),

                      // Cast entries
                      ...perf.casts.asMap().entries.map((castEntry) {
                        final castIndex = castEntry.key;
                        final cast = castEntry.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: cast.roleController,
                                  decoration: const InputDecoration(
                                    hintText: '角色名',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: cast.actorController,
                                  decoration: const InputDecoration(
                                    hintText: '演员名',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _removeCast(index, castIndex),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isOcrProcessing ? null : _processOcr,
        icon: _isOcrProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.document_scanner),
        label: Text(_isOcrProcessing ? '识别中...' : '识图'),
      ),
    );
  }
}
