import 'dart:typed_data';

class SelfieCapture {
  const SelfieCapture({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

Future<SelfieCapture?> captureSelfie() async => null;
