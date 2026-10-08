import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/meta_models.dart';

class MetaAttachments extends StatelessWidget {
  const MetaAttachments({
    super.key,
    required this.items,
    required this.outgoing,
  });

  final List<MetaAttachment> items;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttachmentTile(
                key: ValueKey('${items[i].kind}-$i-${items[i].path}'),
                item: items[i],
                outgoing: outgoing,
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    super.key,
    required this.item,
    required this.outgoing,
  });

  final MetaAttachment item;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final style = context.textStyles.captionSans.copyWith(
      color: colors.textSecondary,
    );
    if (item.status == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              language.translate('meta_attach_loading'),
              style: style,
            ),
          ),
        ],
      );
    }
    if (item.status == 'failed') {
      final error = item.error;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(TablerIcons.alert_triangle, size: 16, color: colors.accentRed),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              error == null || error.isEmpty
                  ? language.translate('meta_attach_failed')
                  : '${language.translate('meta_attach_failed')}: $error',
              style: style.copyWith(color: colors.accentRed),
            ),
          ),
        ],
      );
    }
    if (item.kind == 'location' && item.lat != null && item.lng != null) {
      final label = item.label;
      return InkWell(
        onTap: () {
          final uri = Uri.parse(
            'https://www.google.com/maps?q=${item.lat},${item.lng}',
          );
          launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.map_pin, size: 16, color: colors.brand),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label == null || label.isEmpty
                    ? language.translate('meta_attach_open_map')
                    : label,
                style: style.copyWith(
                  color: colors.brand,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final path = item.path;
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    final url = ApiClient().mediaUrl(path);
    if (item.kind == 'image' || item.kind == 'sticker') {
      final side = item.kind == 'sticker' ? 112.0 : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openImage(context, url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: side,
                height: side,
                fit: BoxFit.contain,
                semanticLabel:
                    item.caption ?? language.translate('meta_attach_photo'),
                errorBuilder: (_, _, _) => Text(
                  language.translate('meta_attach_failed'),
                  style: style,
                ),
              ),
            ),
          ),
          if (item.caption != null && item.caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.caption!, style: context.textStyles.captionSans),
          ],
        ],
      );
    }
    if (item.kind == 'video') {
      return _MetaVideo(url: url, caption: item.caption);
    }
    if (item.kind == 'audio') {
      return _MetaAudio(url: url);
    }
    return _MetaFile(path: path, name: item.name, size: item.size);
  }

  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _MetaVideo extends StatefulWidget {
  const _MetaVideo({required this.url, this.caption});

  final String url;
  final String? caption;

  @override
  State<_MetaVideo> createState() => _MetaVideoState();
}

class _MetaVideoState extends State<_MetaVideo> {
  VideoPlayerController? _controller;
  var _failed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_controller != null) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      if (mounted) setState(() {});
      return;
    }
    final token = await ApiClient().getAccessToken();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    try {
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final ready = _controller?.value.isInitialized == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_failed)
          Text(
            language.translate('meta_attach_failed'),
            style: context.textStyles.captionSans.copyWith(
              color: colors.accentRed,
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: ready ? _controller!.value.aspectRatio : 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (ready)
                    VideoPlayer(_controller!)
                  else
                    ColoredBox(color: colors.surfaceNested),
                  IconButton(
                    tooltip: language.translate('meta_attach_play'),
                    onPressed: _play,
                    icon: Icon(
                      ready && _controller!.value.isPlaying
                          ? TablerIcons.player_pause
                          : TablerIcons.player_play,
                      color: colors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.caption != null && widget.caption!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(widget.caption!, style: context.textStyles.captionSans),
        ],
      ],
    );
  }
}

class _MetaAudio extends StatefulWidget {
  const _MetaAudio({required this.url});

  final String url;

  @override
  State<_MetaAudio> createState() => _MetaAudioState();
}

class _MetaAudioState extends State<_MetaAudio> {
  final _player = AudioPlayer();
  var _ready = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      if (mounted) setState(() {});
      return;
    }
    try {
      if (!_ready) {
        final token = await ApiClient().getAccessToken();
        await _player.setUrl(
          widget.url,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        );
        _ready = true;
      }
      await _player.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    if (_failed) {
      return Text(
        language.translate('meta_attach_failed'),
        style: context.textStyles.captionSans.copyWith(color: colors.accentRed),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: language.translate('meta_attach_play'),
          onPressed: _toggle,
          icon: Icon(
            _player.playing ? TablerIcons.player_pause : TablerIcons.microphone,
            color: colors.brand,
          ),
        ),
        Flexible(
          child: Text(
            language.translate('meta_attach_play'),
            style: context.textStyles.captionSans,
          ),
        ),
      ],
    );
  }
}

class _MetaFile extends StatelessWidget {
  const _MetaFile({required this.path, this.name, this.size});

  final String path;
  final String? name;
  final int? size;

  @override
  Widget build(BuildContext context) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final label = name == null || name!.isEmpty
        ? language.translate('meta_attach_file')
        : name!;
    return InkWell(
      onTap: () => _share(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(TablerIcons.file_text, size: 18, color: colors.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (size != null && size! > 0)
              Text(_fmtSize(size!), style: textStyles.captionSans),
            const SizedBox(width: 6),
            Icon(TablerIcons.download, size: 16, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    try {
      final requestPath = path.startsWith('/') ? path : '/$path';
      final response = await ApiClient().dio.get<List<int>>(
        requestPath,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('meta_attach_failed');
      }
      final dir = await getTemporaryDirectory();
      final fileName = name == null || name!.isEmpty
          ? 'attachment'
          : name!.replaceAll(RegExp(r'[\\/]'), '_');
      final file = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.resolveMessage(
              userFacingError(error, fallback: 'meta_attach_failed'),
            ),
          ),
        ),
      );
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} КБ';
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
    return '$mb МБ';
  }
}
