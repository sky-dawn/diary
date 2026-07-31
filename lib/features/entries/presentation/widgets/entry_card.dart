import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/utils/date_formats.dart';
import '../../models/diary_entry.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final DiaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.title.trim().isEmpty
                          ? '\u65e0\u6807\u9898'
                          : entry.title.trim(),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE4D1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      formatEntryDateShort(entry.entryDate),
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.preview,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              if (entry.photos.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final photo in entry.photos.take(3))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(photo.localPath),
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                          errorBuilder: (BuildContext context, Object _, __) {
                            return Container(
                              width: 72,
                              height: 72,
                              color: const Color(0xFFF0E7D6),
                              alignment: Alignment.center,
                              child: const Icon(Icons.photo_outlined),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${entry.photos.length} \u5f20\u56fe\u7247',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
