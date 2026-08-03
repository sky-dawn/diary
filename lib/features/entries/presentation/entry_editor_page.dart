import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuple/tuple.dart';

import '../../../core/utils/date_formats.dart';
import '../data/sqlite_diary_repository.dart';
import '../models/diary_entry.dart';
import '../models/diary_photo.dart';
import 'providers.dart';

class EntryEditorPage extends ConsumerStatefulWidget {
  const EntryEditorPage({
    super.key,
    this.entryId,
    this.initialDate,
  });

  final int? entryId;
  final DateTime? initialDate;

  @override
  ConsumerState<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends ConsumerState<EntryEditorPage> {
  QuillController _quillController = QuillController.basic();
  late final TextEditingController _titleController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  DateTime _selectedDate = DateTime.now();
  int? _entryId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _selectedDate = normalizeDate(widget.initialDate ?? DateTime.now());
    _bootstrap();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.entryId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final DiaryEntry? entry =
        await ref.read(diaryRepositoryProvider).getEntryById(widget.entryId!);

    if (!mounted) {
      return;
    }

    if (entry != null) {
      _entryId = entry.id;
      _selectedDate = normalizeDate(entry.entryDate);
      _titleController.text = entry.title;

      if (entry.content.isNotEmpty) {
        try {
          final List<dynamic> deltaJson =
              jsonDecode(entry.content) as List<dynamic>;
          _quillController = QuillController(
            document: Document.fromJson(deltaJson),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } catch (_) {
          // 旧格式纯文本或非法 JSON，当作普通文本处理
          _quillController = QuillController(
            document: Document.fromJson(<Map<String, dynamic>>[
              <String, dynamic>{'insert': '${entry.content}\n'},
            ]),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _insertImage() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return;
    }

    try {
      final String importedPath = await ref
          .read(mediaStoreProvider)
          .importPhoto(result.files.first.path!);

      final int index = _quillController.selection.baseOffset;
      final int length =
          _quillController.selection.extentOffset - index;
      _quillController.replaceText(
        index,
        length,
        BlockEmbed.image(importedPath),
        TextSelection.collapsed(offset: index + 1),
      );
      _editorScrollController.animateTo(
        _editorScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _editorFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片插入失败：$e')),
      );
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = normalizeDate(picked);
    });
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();

    final List<dynamic> deltaList =
        _quillController.document.toDelta().toJson();
    final List<Map<String, dynamic>> delta =
        deltaList.cast<Map<String, dynamic>>();
    final String contentJson = jsonEncode(delta);

    final String plainText = DiaryEntry.deltaToPlainText(contentJson);
    if (title.isEmpty && plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少写一点内容。')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final DateTime now = DateTime.now();
    final List<DiaryPhoto> inlinePhotos = _extractPhotosFromDelta(delta);

    final DiaryEntry entry = DiaryEntry(
      id: _entryId,
      entryDate: _selectedDate,
      title: title,
      content: contentJson,
      photos: inlinePhotos,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final int savedId =
          await ref.read(diaryRepositoryProvider).saveEntry(entry);
      ref.invalidate(recentEntriesProvider);
      ref.invalidate(calendarEntriesProvider);
      ref.invalidate(searchResultsProvider);
      ref.invalidate(entryByIdProvider(savedId));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  List<DiaryPhoto> _extractPhotosFromDelta(List<Map<String, dynamic>> delta) {
    final List<DiaryPhoto> photos = <DiaryPhoto>[];
    int sortOrder = 0;
    for (final Map<String, dynamic> op in delta) {
      final dynamic insert = op['insert'];
      if (insert is Map<String, dynamic>) {
        final Map<String, dynamic> embed = insert;
        final String? imagePath = embed['image'] as String?;
        if (imagePath != null) {
          photos.add(DiaryPhoto(
            localPath: imagePath,
            sortOrder: sortOrder,
            createdAt: DateTime.now(),
          ));
          sortOrder++;
        }
      }
    }
    return photos;
  }

  Future<void> _delete() async {
    if (_entryId == null) {
      Navigator.of(context).pop();
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除这篇日记？'),
          content: const Text('这会同时移除关联图片，当前实现没有回收站。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(diaryRepositoryProvider).deleteEntry(_entryId!);
    ref.invalidate(recentEntriesProvider);
    ref.invalidate(calendarEntriesProvider);
    ref.invalidate(searchResultsProvider);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget toolbar = QuillToolbar.basic(
      controller: _quillController,
      multiRowsDisplay: false,
      showImageButton: false,
      showCameraButton: false,
      showVideoButton: false,
      showInlineCode: false,
      showCodeBlock: false,
      showListCheck: false,
      showIndent: false,
      showLink: false,
      showStrikeThrough: false,
      showSmallButton: false,
      showColorButton: false,
      showBackgroundColorButton: false,
      showAlignmentButtons: false,
      showHorizontalRule: false,
      showHistory: true,
      showBoldButton: true,
      showItalicButton: true,
      showUnderLineButton: true,
      showClearFormat: true,
      showHeaderStyle: true,
      showQuote: true,
      showListNumbers: true,
      showListBullets: true,
      toolbarIconSize: 20,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _entryId == null ? '新建日记' : '编辑日记',
        ),
        actions: <Widget>[
          if (_entryId != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: Text(
                _isSaving ? '保存中...' : '保存',
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: <Widget>[
                  Card(
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(formatEntryDate(_selectedDate)),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText: '标题，可留空',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: toolbar),
                        const SizedBox(width: 4),
                        QuillIconButton(
                          icon: const Icon(Icons.image_outlined),
                          size: 40,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          onPressed: _insertImage,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: QuillEditor(
                          controller: _quillController,
                          focusNode: _editorFocusNode,
                          scrollController: _editorScrollController,
                          scrollable: true,
                          padding: const EdgeInsets.all(18),
                          autoFocus: false,
                          readOnly: false,
                          expands: false,
                          placeholder: '今天发生了什么？',
                          customStyles: DefaultStyles(
                            paragraph: DefaultTextBlockStyle(
                              theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.6,
                                  ) ??
                                  const TextStyle(),
                              const Tuple2(0, 0),
                              const Tuple2(8, 8),
                              null,
                            ),
                            h1: DefaultTextBlockStyle(
                              theme.textTheme.headlineLarge ??
                                  const TextStyle(),
                              const Tuple2(8, 8),
                              const Tuple2(12, 6),
                              null,
                            ),
                            h2: DefaultTextBlockStyle(
                              theme.textTheme.headlineMedium ??
                                  const TextStyle(),
                              const Tuple2(6, 6),
                              const Tuple2(10, 4),
                              null,
                            ),
                            h3: DefaultTextBlockStyle(
                              theme.textTheme.headlineSmall ??
                                  const TextStyle(),
                              const Tuple2(4, 6),
                              const Tuple2(8, 4),
                              null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
