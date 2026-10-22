import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'appColor.dart';
import 'profile_camera_stub.dart'
    if (dart.library.js_interop) 'profile_camera_web.dart' as web_camera;

/// Lets the signed-in user upload and manage their own profile picture.
class ProfilePictureEditor extends StatefulWidget {
  const ProfilePictureEditor({super.key, this.size = 80, this.compact = false});

  final double size;
  final bool compact;

  @override
  State<ProfilePictureEditor> createState() => _ProfilePictureEditorState();
}

class _ProfilePictureEditorState extends State<ProfilePictureEditor> {
  static const _bucket = 'profilePictures';
  final _client = Supabase.instance.client;
  String? _imageUrl;
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadPicture();
  }

  Future<void> _loadPicture() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await _client
          .from('users')
          .select('profile_picture_url')
          .eq('userId', user.id)
          .maybeSingle();
      if (mounted)
        setState(() => _imageUrl = row?['profile_picture_url'] as String?);
    } catch (_) {
      // The profile image migration may not have been applied yet.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choosePicture() async {
    if (_uploading) return;
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) return;
      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw StateError('Could not read the selected image.');
      if (file.size > 5 * 1024 * 1024) {
        throw StateError('Choose an image smaller than 5 MB.');
      }

      final extension = (file.extension ?? '').toLowerCase();
      await _uploadPicture(bytes, extension);
    } catch (error) {
      if (mounted) _showMessage('Could not update profile picture: $error');
    }
  }

  Future<void> _takePicture() async {
    if (_uploading) return;
    if (kIsWeb) {
      try {
        final capture = await web_camera.captureSelfie();
        if (capture == null) return;
        if (capture.bytes.length > 5 * 1024 * 1024) {
          throw StateError('The photo is larger than 5 MB. Please take another photo.');
        }
        await _uploadPicture(capture.bytes, capture.extension);
      } catch (error) {
        if (mounted) _showMessage('Could not take or update profile picture: $error');
      }
      return;
    }
    try {
      final picture = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picture == null) return;
      final bytes = await picture.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError(
          'The photo is larger than 5 MB. Please take another photo.',
        );
      }
      var extension = picture.name.split('.').last.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(extension)) {
        extension = switch (picture.mimeType) {
          'image/jpeg' => 'jpg',
          'image/png' => 'png',
          'image/webp' => 'webp',
          'image/gif' => 'gif',
          _ => extension,
        };
      }
      await _uploadPicture(bytes, extension);
    } catch (error) {
      if (mounted)
        _showMessage('Could not take or update profile picture: $error');
    }
  }

  Future<void> _uploadPicture(Uint8List bytes, String extension) async {
    if (!mounted) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    const mimeByExtension = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    final contentType = mimeByExtension[extension];
    if (contentType == null) {
      throw StateError('Choose a JPG, PNG, WEBP, or GIF image.');
    }

    setState(() => _uploading = true);
    try {
      final path = '${user.id}/profile.$extension';
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final url =
          '${_client.storage.from(_bucket).getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await _client
          .from('users')
          .update({'profile_picture_url': url})
          .eq('userId', user.id);
      if (mounted) {
        setState(() => _imageUrl = url);
        _showMessage('Profile picture updated.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePicture() async {
    final user = _client.auth.currentUser;
    if (user == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final files = await _client.storage.from(_bucket).list(path: user.id);
      final profileFiles = files
          .where((file) => file.name.startsWith('profile.'))
          .map((file) => '${user.id}/${file.name}')
          .toList();
      if (profileFiles.isNotEmpty) {
        await _client.storage.from(_bucket).remove(profileFiles);
      }
      await _client
          .from('users')
          .update({'profile_picture_url': null})
          .eq('userId', user.id);
      if (mounted) {
        setState(() => _imageUrl = null);
        _showMessage('Profile picture removed.');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not remove profile picture: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasPicture = _imageUrl != null && _imageUrl!.isNotEmpty;
    final avatar = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 2),
        color: context.bgColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
            )
          : hasPicture
          ? Image.network(
              _imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person, color: kGold),
            )
          : Icon(Icons.person, color: kGold, size: widget.size * 0.55),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 8),
        if (_uploading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              if (widget.compact) ...[
                IconButton(
                  onPressed: _loading ? null : _takePicture,
                  tooltip: 'Take profile photo',
                  icon: const Icon(Icons.camera_alt_outlined),
                  color: kGold,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: _loading ? null : _choosePicture,
                  tooltip: 'Choose a profile photo',
                  icon: const Icon(Icons.photo_library_outlined),
                  color: kGold,
                  visualDensity: VisualDensity.compact,
                ),
              ] else
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _loading ? null : _takePicture,
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Take photo'),
                      style: TextButton.styleFrom(foregroundColor: kGold),
                    ),
                    TextButton.icon(
                      onPressed: _loading ? null : _choosePicture,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Choose photo'),
                      style: TextButton.styleFrom(foregroundColor: kGold),
                    ),
                  ],
                ),
              if (hasPicture)
                if (widget.compact)
                  IconButton(
                    onPressed: _removePicture,
                    tooltip: 'Remove profile picture',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: context.mutedTextColor,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  TextButton(
                    onPressed: _removePicture,
                    style: TextButton.styleFrom(
                      foregroundColor: context.mutedTextColor,
                    ),
                    child: const Text('Remove'),
                  ),
            ],
          ),
      ],
    );
  }
}
