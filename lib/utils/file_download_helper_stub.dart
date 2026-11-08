import 'dart:typed_data';

Future<void> saveAndDownloadFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  throw UnsupportedError('File download is not supported on this platform.');
}
