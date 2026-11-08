import 'dart:typed_data';
import 'package:student_attendance_system/utils/file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_mobile.dart';

abstract class FileDownloadHelper {
  static Future<void> downloadFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    await saveAndDownloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }
}
