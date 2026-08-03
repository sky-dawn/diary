# 富文本编辑器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 flutter_quill 替换纯文本编辑器，实现完整富文本编辑（加粗/斜体/标题/列表/引用/内嵌图片）

**Architecture:** 内容以 Quill Delta JSON 存储在 `content` 字段；图片通过现有 MediaStore 复制到应用目录，Delta 中存文件路径引用；preview/搜索等消费方从 Delta 提取纯文本

**Tech Stack:** flutter_quill ^10.8.5, 现有 sqflite + MediaStore 不变

---

### Task 1: 添加 flutter_quill 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加依赖**

```
flutter pub add flutter_quill
```

- [ ] **Step 2: 验证依赖解析**

```
flutter pub get
```

预期: Got dependencies!

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: 添加 flutter_quill 依赖"
```

---

### Task 2: DiaryEntry 添加 Delta 纯文本提取方法

**Files:**
- Modify: `lib/features/entries/models/diary_entry.dart`

- [ ] **Step 1: 添加 deltaToPlainText 静态方法和更新 preview**

在 `diary_entry.dart` 文件顶部添加 import，在类中添加静态方法和修改 preview getter：

```dart
import 'dart:convert';

class DiaryEntry {
  // ... 现有字段保持不变 ...

  String get preview {
    final String text = deltaToPlainText(content);
    if (text.isEmpty) {
      if (photos.isNotEmpty) {
        return '这一天主要靠照片来记录。';
      }
      return '空内容';
    }
    return text.length > 72 ? '${text.substring(0, 72)}...' : text;
  }

  static String deltaToPlainText(String deltaJson) {
    if (deltaJson.isEmpty) {
      return '';
    }

    try {
      final List<dynamic> ops = jsonDecode(deltaJson) as List<dynamic>;
      final StringBuffer buffer = StringBuffer();
      for (final dynamic op in ops) {
        if (op is Map<String, dynamic>) {
          final dynamic insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
          // 跳过 image embed 等非文本 insert
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      // 不是合法 JSON，按纯文本处理（兼容旧数据或手动输入）
      return deltaJson.trim();
    }
  }

  // ... 其余方法保持不变 ...
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/entries/models/diary_entry.dart
git commit -m "feat: DiaryEntry 添加 Delta JSON 纯文本提取方法"
```

---

### Task 3: 创建 Quill 图片嵌入工具

**Files:**
- Create: `lib/features/entries/presentation/quill_image_embed.dart`

- [ ] **Step 1: 创建图片嵌入处理文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(
    BuildContext context,
    QuillController controller,
    Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    final String imagePath = node.value.data as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width - 64,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: MediaQuery.of(context).size.width - 64,
              height: 160,
              color: const Color(0xFFF0E7D6),
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, size: 48),
                  SizedBox(height: 8),
                  Text('图片加载失败'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/entries/presentation/quill_image_embed.dart
git commit -m "feat: 添加 Quill 图片嵌入渲染器"
```

---

### Task 4: 重构 EntryEditorPage 使用 QuillEditor

**Files:**
- Modify: `lib/features/entries/presentation/entry_editor_page.dart`

- [ ] **Step 1: 重写 EntryEditorPage**

用 QuillEditor + QuillSimpleToolbar 替换现有的 TextField 文本编辑器。完整文件如下：

```dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formats.dart';
import '../data/sqlite_diary_repository.dart';
import '../models/diary_entry.dart';
import '../models/diary_photo.dart';
import 'providers.dart';
import 'quill_image_embed.dart';

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
  late final QuillController _quillController;
  late final TextEditingController _titleController;
  final FocusNode _editorFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  int? _entryId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _quillController = QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _selectedDate = normalizeDate(widget.initialDate ?? DateTime.now());
    _bootstrap();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
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

      // 从 Delta JSON 恢复文档
      if (entry.content.isNotEmpty) {
        try {
          final List<dynamic> deltaJson =
              jsonDecode(entry.content) as List<dynamic>;
          _quillController.document = Document.fromJson(deltaJson);
        } catch (_) {
          _quillController.document =
              Document.fromJson(<Map<String, dynamic>>[
            <String, dynamic>{'insert': '${entry.content}\n'},
          ]);
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _insertImage() async {
    final FilePickerResult? result = await FilePicker.pluginsPickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return;
    }

    try {
      final String importedPath =
          await ref.read(mediaStoreProvider).importPhoto(result.files.first.path!);

      final int index = _quillController.selection.baseOffset;
      _quillController.replaceText(
        index,
        _quillController.selection.extentOffset - index,
        BlockEmbed.image(importedPath),
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

    // 将文档转为 Delta JSON 字符串
    final List<Map<String, dynamic>> delta = _quillController.document.toDelta().toJson();
    final String contentJson = jsonEncode(delta);

    // 从 Delta 提取纯文本判断是否为空
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

    // 从 Delta 中提取图片路径，构建 photos 列表
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
        final String? imagePath = insert['image'] as String?;
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
    final QuillToolbar toolbar = QuillToolbar(
      controller: _quillController,
      configurations: QuillToolbarConfigurations(
        multiRowsDisplay: false,
        showInlineCode: false,
        showCodeBlock: false,
        showSearchButton: false,
        showIndent: false,
        showListCheck: false,
        showUndo: true,
        showRedo: true,
        showFontFamily: false,
        showFontSize: false,
        showStrikeThrough: false,
        showSubscript: false,
        showSuperscript: false,
        showColorButton: false,
        showBackgroundColorButton: false,
        showClearFormat: true,
        showLink: false,
        showQuote: true,
        showHeaderStyle: true,
        showListBullets: true,
        showListNumbers: true,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showJustifyAlignment: false,
        customButtons: <QuillToolbarCustomButtonOptions>[
          QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.image_outlined),
            tooltip: '插入图片',
            onPressed: _insertImage,
          ),
        ],
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: toolbar,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: QuillEditor(
                        controller: _quillController,
                        focusNode: _editorFocusNode,
                        scrollController: ScrollController(),
                        configurations: QuillEditorConfigurations(
                          placeholder: '今天发生了什么？',
                          padding: const EdgeInsets.all(18),
                          embedBuilders: <EmbedBuilder>[
                            ImageEmbedBuilder(),
                          ],
                          customStyles: DefaultStyles(
                            paragraph: DefaultTextBlockStyle(
                              theme.textTheme.bodyMedium?.copyWith(
                                height: 1.6,
                              ) ?? const TextStyle(),
                              const VerticalSpacing(0, 0),
                              const VerticalSpacing(8, 8),
                              null,
                            ),
                            h1: DefaultTextBlockStyle(
                              theme.textTheme.headlineLarge ??
                                  const TextStyle(),
                              const VerticalSpacing(8, 8),
                              const VerticalSpacing(12, 6),
                              null,
                            ),
                            h2: DefaultTextBlockStyle(
                              theme.textTheme.headlineMedium ??
                                  const TextStyle(),
                              const VerticalSpacing(6, 6),
                              const VerticalSpacing(10, 4),
                              null,
                            ),
                            h3: DefaultTextBlockStyle(
                              theme.textTheme.headlineSmall ??
                                  const TextStyle(),
                              const VerticalSpacing(4, 6),
                              const VerticalSpacing(8, 4),
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
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/entries/presentation/entry_editor_page.dart
git commit -m "feat: EntryEditorPage 改为 Quill 富文本编辑器，支持内嵌图片"
```

---

### Task 5: 更新 EntryCard 适配富文本预览

**Files:**
- Modify: `lib/features/entries/presentation/widgets/entry_card.dart`

- [ ] **Step 1: 修改 EntryCard 的 preview 显示和图片展示**

EntryCard 的 preview 已经通过 `entry.preview` 取数据，而 `preview` 已改为调用 `deltaToPlainText`，所以 preview 文本天然适配。
但图片展示逻辑需要调整——`entry.photos` 现在从 Delta 中提取，已由 `_extractPhotosFromDelta` 填充。

文件本身代码不变——preview 依赖 `entry.preview` getter，照片列表也继续使用 `entry.photos`。

- [ ] **Step 2: 提交**

无需变更（EntryCard 已通过 DiaryEntry 的 preview getter 和 photos 字段间接适配）。

---

### Task 6: 验证构建通过

- [ ] **Step 1: 构建验证**

```bash
flutter pub get && flutter analyze
```

预期: No issues found!

- [ ] **Step 2: 提交（如有 lint 修复）**

```bash
git add -A && git diff --cached --stat
# 仅当有变更时提交
```

---

### Task 7: 端到端验证

- [ ] **Step 1: 启动应用**

```bash
flutter run -d windows
```

- [ ] **Step 2: 手动验证**

1. 点击 FAB → 进入编辑页面
2. 验证工具栏显示（加粗/斜体/下划线/标题/列表/引用/图片按钮）
3. 输入文本，切换格式，确认效果
4. 点击图片按钮，选择一张图片，确认图片嵌入正文
5. 保存，返回首页，确认预览文本正确显示
6. 点击卡片进入编辑，确认之前编辑的富文本内容正确恢复

- [ ] **Step 3: 提交（如有修复）**

```bash
git add -A
git commit -m "fix: 富文本编辑器端到端修复"
```
