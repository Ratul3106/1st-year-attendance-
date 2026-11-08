import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndDownloadFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final tempDir = await getTemporaryDirectory();
  final filePath = '${tempDir.path}/$filename';
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(filePath, mimeType: mimeType, name: filename)],
    text: 'Attendance Report: $filename',
    subject: filename,
  );
}
