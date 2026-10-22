import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/platform/temp_file_cleanup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../presentation/widgets/image_cache_extent.dart';
import '../../../core/network/api_client.dart';
import '../../../core/observability/app_error_reporter.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/meta_models.dart';

class MetaAttachments extends StatelessWidget {
  const MetaAttachments({
    super.key,
    required this.items,
    required this.outgoing,
    this.text = '',
  });

  final List<MetaAttachment> items;
  final bool outgoing;

  /// Raw message text: Instagram voice arrives as `video` with the server
  /// marker in the text (web `VOICE_LABEL`).
  final String text;

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
              child: _withNote(
                context,
                items[i],
                _AttachmentTile(
                  key: ValueKey('${items[i].kind}-$i-${items[i].path}'),
                  item: items[i],
                  outgoing: outgoing,
                  voice: metaIsVoice(text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Instagram context line above the attachment (web `NOTE_KEYS`).
const _noteKeys = {
  'story_reply': 'meta_attach_story',
  'story_mention': 'meta_attach_story_mention',
  'story': 'meta_attach_story',
  'share': 'meta_attach_share',
  'reel': 'meta_attach_reel',
};

Widget _withNote(BuildContext context, MetaAttachment item, Widget child) {
  final key = _noteKeys[item.note];
  if (key == null) return child;
  final colors = context.colors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        context.read<LanguageCubit>().translate(key),
        style: context.textStyles.smallSans.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      child,
    ],
  );
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    super.key,
    required this.item,
    required this.outgoing,
    this.voice = false,
  });

  final MetaAttachment item;
  final bool outgoing;
  final bool voice;

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
              item.errorCode == 'expired'
                  ? language.translate('meta_attach_story_expired')
                  : error == null || error.isEmpty
                  ? language.translate('meta_attach_failed')
                  : '${language.translate('meta_attach_failed')}: $error',
              style: style.copyWith(color: colors.accentRed),
            ),
          ),
        ],
      );
    }
    final link = item.url == null ? null : Uri.tryParse(item.url!);
    if (item.kind == 'link' &&
        link != null &&
        (link.scheme == 'https' || link.scheme == 'http')) {
      final label = item.label;
      final instagram = metaIsInstagramPost(link.toString());
      final text = instagram
          ? [
              if (label != null && label.isNotEmpty) label,
              language.translate('meta_attach_open_instagram'),
            ].join(' · ')
          : (label == null || label.isEmpty
                ? language.translate('meta_attach_open_link')
                : label);
      return InkWell(
        onTap: () => launchUrl(link, mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                instagram
                    ? TablerIcons.brand_instagram
                    : TablerIcons.external_link,
                size: 16,
                color: colors.brand,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: colors.brand),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (item.kind == 'location' && item.lat != null && item.lng != null) {
      final label = item.label;
      final title = label == null || label.isEmpty
          ? language.translate('meta_attach_location')
          : label;
      return InkWell(
        onTap: () {
          final uri = Uri.parse(
            'https://www.google.com/maps?q=${item.lat},${item.lng}',
          );
          launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surfaceNested,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(TablerIcons.map_pin, size: 20, color: colors.brand),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.translate('meta_attach_open_map'),
                      style: context.textStyles.smallSans.copyWith(
                        fontSize: 12,
                        color: colors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                // Never wider than the bubble: decode at that size.
                cacheWidth: imageCacheWidth(
                  MediaQuery.devicePixelRatioOf(context),
                  side ?? MediaQuery.sizeOf(context).width * 0.78,
                ),
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
    if (item.kind == 'audio' || (item.kind == 'video' && voice)) {
      return _MetaAudio(path: path, url: url);
    }
    if (item.kind == 'video') {
      return _MetaVideo(url: url, caption: item.caption);
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
    final token = ApiClient().isSameOrigin(widget.url)
        ? await ApiClient().getAccessToken()
        : null;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    try {
      await controller.initialize();
      var playing = controller.value.isPlaying;
      var initialized = controller.value.isInitialized;
      controller.addListener(() {
        if (!mounted) return;
        final value = controller.value;
        final nextPlaying = value.isPlaying;
        final nextInitialized = value.isInitialized;
        if (nextPlaying == playing &&
            nextInitialized == initialized &&
            !value.hasError) {
          return;
        }
        playing = nextPlaying;
        initialized = nextInitialized;
        setState(() {});
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
  const _MetaAudio({required this.path, required this.url});

  final String path;
  final String url;

  @override
  State<_MetaAudio> createState() => _MetaAudioState();
}

class _MetaAudioState extends State<_MetaAudio> {
  final _player = AudioPlayer();
  File? _tempFile;
  var _ready = false;
  var _loading = false;
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
    final temp = _tempFile;
    if (temp != null) {
      unawaited(
        temp.delete().then<void>(
          (_) {},
          onError: (Object e, StackTrace st) =>
              AppErrorReporter.reportOptional(e, st, context: 'meta_audio'),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final completed = _player.processingState == ProcessingState.completed;
    if (_player.playing && !completed) {
      await _player.pause();
      if (mounted) setState(() {});
      return;
    }
    try {
      if (!_ready) {
        final file = await _download();
        if (file != null) {
          await _player.setFilePath(file.path);
        } else {
          // External CDN link: no PAYK token, no localhost header proxy.
          await _player.setUrl(widget.url);
        }
        _ready = true;
      } else if (completed) {
        await _player.seek(Duration.zero);
      }
      // play() resolves only when playback stops; do not hold the spinner.
      unawaited(_player.play());
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      AppErrorReporter.reportOptional(error, stackTrace, context: 'meta_audio');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Own files go through the API client (Bearer token + SSL pinning) into a
  /// temp file. `setUrl(headers:)` would start just_audio's proxy on
  /// http://127.0.0.1, which Android blocks (`usesCleartextTraffic=false`).
  Future<File?> _download() async {
    final requestPath = metaMediaRequestPath(widget.path);
    if (requestPath == null) return null;
    final response = await ApiClient().dio.get<List<int>>(
      requestPath,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) throw Exception('meta_attach_failed');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${metaAudioCacheName(widget.path)}');
    await file.writeAsBytes(bytes, flush: true);
    _tempFile = file;
    return file;
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
    final playing = _player.playing;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Material(
            color: colors.brand,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _loading ? null : _toggleWithLoading,
              child: Semantics(
                button: true,
                label: language.translate(
                  playing ? 'meta_attach_pause' : 'meta_attach_play',
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: _loading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onBrand,
                            ),
                          )
                        : Icon(
                            playing
                                ? TablerIcons.player_pause_filled
                                : TablerIcons.player_play_filled,
                            size: 18,
                            color: colors.onBrand,
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = _player.duration;
                final progress = total == null || total.inMilliseconds == 0
                    ? 0.0
                    : (position.inMilliseconds / total.inMilliseconds).clamp(
                        0.0,
                        1.0,
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: colors.brand,
                        backgroundColor: colors.border,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      metaAudioClock(
                        playing || position > Duration.zero ? position : total,
                      ),
                      style: context.textStyles.smallSans.copyWith(
                        fontSize: 12,
                        color: colors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWithLoading() async {
    final firstLoad = !_ready;
    if (firstLoad) setState(() => _loading = true);
    await _toggle();
    if (firstLoad && mounted) setState(() => _loading = false);
  }
}

/// Server marker for a voice message (`label_of` in integrations/meta.py).
/// A protocol value, not UI text: it is matched, never shown.
const _voiceMarker = '[Голосовое сообщение]';

bool metaIsVoice(String text) => text.contains(_voiceMarker);

/// Forwarded Reels / Instagram post link (web `IG_EMBED`). Mobile has no
/// embedded player (no WebView package), so it opens the app or browser.
bool metaIsInstagramPost(String url) => RegExp(
  r'^https?://(?:www\.)?instagram\.com/(reel|reels|p)/[A-Za-z0-9_-]+',
).hasMatch(url);

/// API path for a stored attachment, or null for an external `http(s)` link
/// (Meta CDN) that must not receive the PAYK token.
String? metaMediaRequestPath(String path) {
  final value = path.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return null;
  return value.startsWith('/') ? value : '/$value';
}

/// Temp file name that keeps the extension, so the player picks the codec
/// (`.ogg` voice from WhatsApp, `.m4a`, `.mp3`…).
String metaAudioCacheName(String path) {
  final name = path.split('?').first.split('/').last;
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return 'meta_audio_${safe.isEmpty ? 'voice' : safe}';
}

/// `m:ss` for a voice message; `0:00` until the length is known.
String metaAudioClock(Duration? value) {
  final d = value ?? Duration.zero;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
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
      scheduleTempFileDeletion(file);
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
