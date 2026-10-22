import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class SelfieCapture {
  const SelfieCapture({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

Future<SelfieCapture?> captureSelfie() async {
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    throw StateError('Camera access is not available in this browser.');
  }

  final stream = await mediaDevices.getUserMedia({
    'audio': false,
    'video': {
      'facingMode': {'ideal': 'user'},
    },
  });
  final overlay = html.DivElement()
    ..style.position = 'fixed'
    ..style.left = '0'
    ..style.top = '0'
    ..style.width = '100vw'
    ..style.height = '100vh'
    ..style.zIndex = '2147483647'
    ..style.backgroundColor = 'rgba(0, 0, 0, 0.88)'
    ..style.display = 'flex'
    ..style.flexDirection = 'column'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.gap = '16px';
  final video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true')
    ..style.maxWidth = 'min(92vw, 720px)'
    ..style.maxHeight = '75vh'
    ..style.objectFit = 'contain'
    ..style.borderRadius = '12px'
    ..srcObject = stream;
  final controls = html.DivElement()
    ..style.display = 'flex'
    ..style.alignItems = 'center'
    ..style.gap = '16px';
  final captureButton = html.ButtonElement()
    ..text = 'Capture photo'
    ..style.padding = '14px 24px'
    ..style.border = '0'
    ..style.borderRadius = '24px'
    ..style.backgroundColor = '#d4a83f'
    ..style.color = '#17130a'
    ..style.fontSize = '16px'
    ..style.fontWeight = '700'
    ..style.cursor = 'pointer';
  final cancelButton = html.ButtonElement()
    ..text = 'Cancel'
    ..style.padding = '12px 20px'
    ..style.border = '1px solid white'
    ..style.borderRadius = '24px'
    ..style.backgroundColor = 'transparent'
    ..style.color = 'white'
    ..style.fontSize = '15px'
    ..style.cursor = 'pointer';
  controls.children.addAll([cancelButton, captureButton]);
  overlay.children.addAll([video, controls]);
  html.document.body?.append(overlay);

  final result = Completer<SelfieCapture?>();
  captureButton.onClick.listen((_) async {
    if (result.isCompleted) return;
    try {
      final width = video.videoWidth;
      final height = video.videoHeight;
      if (width == 0 || height == 0) {
        throw StateError('The camera is still starting. Please try again.');
      }
      final canvas = html.CanvasElement(width: width, height: height);
      canvas.context2D.drawImage(video, 0, 0);
      final imageData = canvas.toDataUrl('image/jpeg', 0.9);
      final encodedImage = imageData.split(',').last;
      result.complete(
        SelfieCapture(bytes: Uint8List.fromList(base64Decode(encodedImage)), extension: 'jpg'),
      );
    } catch (error) {
      result.completeError(error);
    }
  });
  cancelButton.onClick.listen((_) {
    if (!result.isCompleted) result.complete(null);
  });

  try {
    await video.play();
    return await result.future;
  } finally {
    for (final track in stream.getTracks()) {
      track.stop();
    }
    overlay.remove();
  }
}
