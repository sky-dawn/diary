import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/empty_state.dart';
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
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  DateTime _selectedDate = DateTime.now();
  List<DiaryPhoto> _photos = <DiaryPhoto>[];
  int? _entryId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _selectedDate = normalizeDate(widget.initialDate ?? DateTime.now());
    _bootstrap();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
      _contentController.text = entry.content;
      _photos = List<DiaryPhoto>.from(entry.photos);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickPhotos() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final List<DiaryPhoto> importedPhotos = <DiaryPhoto>[];
    for (final PlatformFile file in result.files) {
      if (file.path == null) {
        continue;
      }

      final String importedPath =
          await ref.read(mediaStoreProvider).importPhoto(file.path!);
      importedPhotos.add(
        DiaryPhoto(
          localPath: importedPath,
          sortOrder: _photos.length + importedPhotos.length,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (!mounted || importedPhotos.isEmpty) {
      return;
    }

    setState(() {
      _photos = <DiaryPhoto>[..._photos, ...importedPhotos];
    });
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
    final String content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u81f3\u5c11\u5199\u4e00\u70b9\u5185\u5bb9\uff0c\u6216\u8005\u52a0\u4e00\u5f20\u56fe\u7247\u3002',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final DateTime now = DateTime.now();
    final DiaryEntry entry = DiaryEntry(
      id: _entryId,
      entryDate: _selectedDate,
      title: title,
      content: content,
      photos: _photos
          .asMap()
          .entries
          .map(
            (MapEntry<int, DiaryPhoto> item) =>
                item.value.copyWith(sortOrder: item.key),
          )
          .toList(growable: false),
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

  Future<void> _delete() async {
    if (_entryId == null) {
      Navigator.of(context).pop();
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('\u5220\u9664\u8fd9\u7bc7\u65e5\u8bb0\uff1f'),
          content: const Text(
            '\u8fd9\u4f1a\u540c\u65f6\u79fb\u9664\u5173\u8054\u56fe\u7247\uff0c\u5f53\u524d\u5b9e\u73b0\u6ca1\u6709\u56de\u6536\u7ad9\u3002',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('\u53d6\u6d88'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('\u5220\u9664'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _entryId == null
              ? '\u65b0\u5efa\u65e5\u8bb0'
              : '\u7f16\u8f91\u65e5\u8bb0',
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
                _isSaving ? '\u4fdd\u5b58\u4e2d...' : '\u4fdd\u5b58',
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: <Widget>[
                  Card(
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
                              hintText: '\u6807\u9898\uff0c\u53ef\u7559\u7a7a',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _contentController,
                            minLines: 10,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText:
                                  '\u4eca\u5929\u53d1\u751f\u4e86\u4ec0\u4e48\uff1f',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '\u56fe\u7247',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _pickPhotos,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('\u6dfb\u52a0\u56fe\u7247'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_photos.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: EmptyState(
                          icon: Icons.photo_library_outlined,
                          title: '\u8fd8\u6ca1\u52a0\u56fe\u7247',
                          message:
                              '\u7b2c\u4e00\u7248\u4f1a\u628a\u9009\u4e2d\u7684\u56fe\u7247\u590d\u5236\u5230\u5e94\u7528\u76ee\u5f55\uff0c\u907f\u514d\u539f\u59cb\u8def\u5f84\u53d8\u52a8\u5bfc\u81f4\u4e22\u56fe\u3002',
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _photos
                          .asMap()
                          .entries
                          .map(
                            (MapEntry<int, DiaryPhoto> item) => _PhotoTile(
                              photo: item.value,
                              onRemove: () {
                                setState(() {
                                  _photos = List<DiaryPhoto>.from(_photos)
                                    ..removeAt(item.key);
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onRemove,
  });

  final DiaryPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final File file = File(photo.localPath);

    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            file,
            width: 112,
            height: 112,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
              return Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E7D6),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            },
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton.filledTonal(
            onPressed: onRemove,
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              minimumSize: const Size(30, 30),
              maximumSize: const Size(30, 30),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
