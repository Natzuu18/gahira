import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'appColor.dart';

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
      if (mounted) setState(() => _imageUrl = row?['profile_picture_url'] as String?);
    } catch (_) {
      // The profile image migration may not have been applied yet.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choosePicture() async {
    if (_uploading) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
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
      final path = '${user.id}/profile.$extension';
      await _client.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final url = '${_client.storage.from(_bucket).getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await _client
          .from('users')
          .update({'profile_picture_url': url})
          .eq('userId', user.id);
      if (mounted) {
        setState(() => _imageUrl = url);
        _showMessage('Profile picture updated.');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not update profile picture: $error');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kGold))
          : hasPicture
          ? Image.network(
              _imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: kGold),
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
              if (widget.compact)
                IconButton(
                  onPressed: _loading ? null : _choosePicture,
                  tooltip: 'Change profile picture',
                  icon: const Icon(Icons.photo_camera_outlined),
                  color: kGold,
                  visualDensity: VisualDensity.compact,
                )
              else
                TextButton.icon(
                  onPressed: _loading ? null : _choosePicture,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: const Text('Change picture'),
                  style: TextButton.styleFrom(foregroundColor: kGold),
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
