import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_formats.dart';
import '../data/sqlite_diary_repository.dart';
import '../models/diary_entry.dart';
import '../models/diary_photo.dart';
import 'providers.dart';

/// 预设图片尺寸及对应最大宽度
enum ImageSize { sm, md, lg, original }

/// 图片尺寸对应的像素宽度
const Map<ImageSize, double> _imageSizeWidths = <ImageSize, double>{
  ImageSize.sm: 200,
  ImageSize.md: 400,
  ImageSize.lg: 600,
  ImageSize.original: double.infinity,
};

/// 图片尺寸对应的显示标签
const Map<ImageSize, String> _imageSizeLabels = <ImageSize, String>{
  ImageSize.sm: '小',
  ImageSize.md: '中',
  ImageSize.lg: '大',
  ImageSize.original: '原始',
};

/// 编码图片嵌入数据：path + size
String encodeImageData(String path, ImageSize size) =>
    jsonEncode(<String, String>{'path': path, 'size': size.name});

/// 解码图片嵌入数据，兼容旧版纯路径格式
Map<String, dynamic> decodeImageData(String data) {
  if (data.startsWith('{')) {
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {}
  }
  return <String, dynamic>{'path': data, 'size': ImageSize.md.name};
}

/// 图片嵌入构建器，支持点击切换预设尺寸
class ImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(
    BuildContext context,
    QuillController controller,
    Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    final Map<String, dynamic> parsed = decodeImageData(node.value.data);
    final String imagePath = parsed['path'] as String;
    final ImageSize size = ImageSize.values.firstWhere(
      (ImageSize s) => s.name == parsed['size'],
      orElse: () => ImageSize.md,
    );
    final File imageFile = File(imagePath);

    if (!imageFile.existsSync()) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.broken_image_outlined, size: 48),
              SizedBox(height: 8),
              Text('图片未找到', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // 根据尺寸确定宽度
    final double maxWidth = _imageSizeWidths[size]!;
    final bool constrained = maxWidth != double.infinity;

    return GestureDetector(
      onTap: () => _cycleImageSize(controller, node),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                  width: constrained ? maxWidth : null,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.broken_image_outlined, size: 48),
                          SizedBox(height: 8),
                          Text('图片加载失败', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _imageSizeLabels[size]!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleImageSize(QuillController controller, Embed node) {
    final Map<String, dynamic> parsed = decodeImageData(node.value.data);
    final ImageSize currentSize = ImageSize.values.firstWhere(
      (ImageSize s) => s.name == parsed['size'],
      orElse: () => ImageSize.md,
    );
    final ImageSize nextSize = ImageSize.values[
        (currentSize.index + 1) % ImageSize.values.length];
    final String newData = encodeImageData(
        parsed['path'] as String, nextSize);

    final int offset = node.documentOffset;
    controller.replaceText(
      offset,
      1,
      BlockEmbed.image(newData),
      TextSelection.collapsed(offset: offset + 1),
    );
  }
}

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

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.tryParse(url) ?? Uri();
    if (uri.scheme.isEmpty) {
      return;
    }
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接')),
        );
      }
    }
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

      final String imageData = encodeImageData(importedPath, ImageSize.md);
      final int index = _quillController.selection.baseOffset;
      final int length =
          _quillController.selection.extentOffset - index;
      _quillController.replaceText(
        index,
        length,
        BlockEmbed.image(imageData),
        TextSelection.collapsed(offset: index + 1),
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
        final String? rawData = embed['image'] as String?;
        if (rawData != null) {
          final Map<String, dynamic> parsed = decodeImageData(rawData);
          final String path = parsed['path'] as String;
          photos.add(DiaryPhoto(
            localPath: path,
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
                  QuillSimpleToolbar(
                    controller: _quillController,
                    configurations: QuillSimpleToolbarConfigurations(
                      multiRowsDisplay: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showStrikeThrough: false,
                      showInlineCode: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                      showClearFormat: true,
                      showAlignmentButtons: false,
                      showLeftAlignment: false,
                      showCenterAlignment: false,
                      showRightAlignment: false,
                      showJustifyAlignment: false,
                      showHeaderStyle: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: false,
                      showCodeBlock: false,
                      showQuote: true,
                      showIndent: false,
                      showLink: true,
                      showUndo: true,
                      showRedo: true,
                      showDirection: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showClipboardCut: false,
                      showClipboardCopy: false,
                      showClipboardPaste: false,
                      showDividers: false,
                      customButtons: <QuillToolbarCustomButtonOptions>[
                        QuillToolbarCustomButtonOptions(
                          icon: const Icon(Icons.image_outlined),
                          tooltip: '插入图片',
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
                          configurations: QuillEditorConfigurations(
                            placeholder: '今天发生了什么？',
                            padding: const EdgeInsets.all(18),
                            scrollable: true,
                            autoFocus: false,
                            expands: false,
                            onLaunchUrl: _launchUrl,
                            embedBuilders: <EmbedBuilder>[
                              ImageEmbedBuilder(),
                            ],
                            customStyles: DefaultStyles(
                              paragraph: DefaultTextBlockStyle(
                                theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.6,
                                    ) ??
                                    const TextStyle(),
                                const HorizontalSpacing(0, 0),
                                const VerticalSpacing(0, 0),
                                const VerticalSpacing(8, 8),
                                null,
                              ),
                              h1: DefaultTextBlockStyle(
                                theme.textTheme.headlineLarge ??
                                    const TextStyle(),
                                const HorizontalSpacing(0, 0),
                                const VerticalSpacing(8, 8),
                                const VerticalSpacing(12, 6),
                                null,
                              ),
                              h2: DefaultTextBlockStyle(
                                theme.textTheme.headlineMedium ??
                                    const TextStyle(),
                                const HorizontalSpacing(0, 0),
                                const VerticalSpacing(6, 6),
                                const VerticalSpacing(10, 4),
                                null,
                              ),
                              h3: DefaultTextBlockStyle(
                                theme.textTheme.headlineSmall ??
                                    const TextStyle(),
                                const HorizontalSpacing(0, 0),
                                const VerticalSpacing(4, 6),
                                const VerticalSpacing(8, 4),
                                null,
                              ),
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
