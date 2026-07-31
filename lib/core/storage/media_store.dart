import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaStore {
  Future<Directory> _originalDirectory() async {
    final Directory rootDirectory = await getApplicationSupportDirectory();
    final Directory mediaDirectory =
        Directory(p.join(rootDirectory.path, 'media', 'original'));
    if (!await mediaDirectory.exists()) {
      await mediaDirectory.create(recursive: true);
    }
    return mediaDirectory;
  }

  Future<String> importPhoto(String sourcePath) async {
    final Directory targetDirectory = await _originalDirectory();
    final File sourceFile = File(sourcePath);
    final String extension = p.extension(sourceFile.path);
    final String targetPath = p.join(
      targetDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<void> deletePhoto(String? localPath) async {
    if (localPath == null) {
      return;
    }

    final File file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
