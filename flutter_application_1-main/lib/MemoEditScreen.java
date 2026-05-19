import 'package:flutter/material.dart';

class MemoEditScreen extends StatefulWidget {
  final String? initialText;

  const MemoEditScreen({super.key, this.initialText});

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveMemo() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialText == null ? '新增備忘錄' : '編輯備忘錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveMemo,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          maxLines: null, // Allows for multi-line input
          expands: true, // Expands to fill the available space
          decoration: const InputDecoration(
            hintText: '在這裡輸入您的備忘錄...',
            border: InputBorder.none,
          ),
          autofocus: true,
        ),
      ),
    );
  }
}
