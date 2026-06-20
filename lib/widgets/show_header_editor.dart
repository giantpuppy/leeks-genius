import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/show.dart';
import '../utils/cover_helper.dart';
import '../utils/status_colors.dart';

/// 共享的剧目头部编辑器
///
/// 用于 AddShowScreen 和 ShowManagementScreen 的海报 + 剧名 + 剧场区域。
class ShowHeaderEditor extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController theaterController;
  final String? coverPath;
  final ValueChanged<String?>? onCoverChanged;
  final Show? show;
  final bool editable;

  const ShowHeaderEditor({
    super.key,
    required this.nameController,
    required this.theaterController,
    this.coverPath,
    this.onCoverChanged,
    this.show,
    this.editable = true,
  });

  @override
  State<ShowHeaderEditor> createState() => _ShowHeaderEditorState();
}

class _ShowHeaderEditorState extends State<ShowHeaderEditor> {
  Future<void> _pickCoverImage() async {
    if (!widget.editable) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final showName = widget.nameController.text.trim().isNotEmpty
        ? widget.nameController.text.trim()
        : '未命名剧目';

    final savedPath = await CoverHelper.saveCoverImage(showName, bytes);
    widget.onCoverChanged?.call(savedPath);
  }

  Color _getCoverColor() {
    if (widget.coverPath != null && widget.coverPath!.isNotEmpty) {
      return Colors.transparent;
    }
    final id = widget.show?.id ?? 0;
    return kCoverColors[id.abs() % kCoverColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final posterWidth = screenWidth * 0.28;
    final posterHeight = posterWidth * 4 / 3;
    final color = _getCoverColor();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：3:4 海报位
        GestureDetector(
          onTap: widget.editable ? _pickCoverImage : null,
          child: Container(
            width: posterWidth,
            height: posterHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color,
              gradient: widget.coverPath == null || widget.coverPath!.isEmpty
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.6)],
                    )
                  : null,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
              image: widget.coverPath != null && widget.coverPath!.isNotEmpty
                  ? DecorationImage(
                      image: FileImage(File(widget.coverPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.coverPath == null || widget.coverPath!.isEmpty
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // 剧名首字
                      if (widget.nameController.text.trim().isNotEmpty)
                        Text(
                          widget.nameController.text.trim().substring(0,
                              widget.nameController.text.trim().length > 2
                                  ? 2
                                  : widget.nameController.text.trim().length),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.18),
                            fontSize: posterWidth * 0.35,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      // 相机图标
                      if (widget.editable)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.camera_alt,
                                  size: posterWidth * 0.16, color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '上传海报',
                              style: TextStyle(
                                fontSize: posterWidth * 0.08,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(width: 14),
        // 右侧：剧目名称 + 演出地点
        Expanded(
          child: Column(
            children: [
              TextFormField(
                controller: widget.nameController,
                decoration: _inputDecoration('剧目名称'),
                style: const TextStyle(fontSize: 15),
                validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                onChanged: widget.editable ? (_) => setState(() {}) : null,
                readOnly: !widget.editable,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: widget.theaterController,
                decoration: _inputDecoration('演出剧场'),
                style: const TextStyle(fontSize: 15),
                readOnly: !widget.editable,
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6B5BCD), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
