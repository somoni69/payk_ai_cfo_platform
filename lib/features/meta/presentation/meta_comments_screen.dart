import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/image_cache_extent.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';

/// Instagram comments under posts and Reels. A public reply is visible to
/// everyone; «В Директ» continues in a normal dialog.
class MetaCommentsScreen extends StatefulWidget {
  const MetaCommentsScreen({super.key, required this.onOpenThread});

  final ValueChanged<int> onOpenThread;

  @override
  State<MetaCommentsScreen> createState() => _MetaCommentsScreenState();
}

class _MetaCommentsScreenState extends State<MetaCommentsScreen> {
  var _onlyNew = false;
  var _loading = true;
  String? _error;
  List<MetaComment> _comments = const [];
  CommentSettings? _settings;
  final _reply = TextEditingController();
  int? _replyingId;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  MetaRepository get _repo => context.read<MetaRepository>();

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final comments = await _repo.getComments(onlyNew: _onlyNew);
      final settings = await _repo.getCommentSettings();
      if (comments.any((c) => c.seenAt == null)) {
        await _repo.markCommentsSeen();
      }
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _send({required bool direct}) async {
    final id = _replyingId;
    final text = _reply.text.trim();
    if (id == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (direct) {
        final result = await _repo.dmComment(id, text);
        if (!mounted) return;
        _reply.clear();
        setState(() => _replyingId = null);
        widget.onOpenThread(result.threadId);
      } else {
        await _repo.replyComment(id, text);
        if (!mounted) return;
        _reply.clear();
        setState(() => _replyingId = null);
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    if (_loading && _comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language.translate('meta_comments_hint'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FilterChip(
                    label: language.translate('meta_comments_all'),
                    selected: !_onlyNew,
                    onTap: () {
                      setState(() => _onlyNew = false);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: language.translate('meta_comments_new'),
                    selected: _onlyNew,
                    onTap: () {
                      setState(() => _onlyNew = true);
                      _load();
                    },
                  ),
                ],
              ),
              if (_settings != null && !_settings!.connected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    language.translate('meta_comments_not_connected'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.accentAmber,
                    ),
                  ),
                ),
              if (_settings != null &&
                  _settings!.connected &&
                  _settings!.aiAvailable)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    language.translate('meta_comments_ai'),
                    style: textStyles.captionSans,
                  ),
                  value: _settings!.aiEnabled,
                  onChanged: (value) async {
                    try {
                      final next = await _repo.setCommentAi(value);
                      if (mounted) setState(() => _settings = next);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(userFacingError(e))),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(language.resolveMessage(_error!)),
          )
        else if (_comments.isEmpty)
          Expanded(
            child: Center(
              child: Text(language.translate('meta_comments_empty')),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return _CommentCard(
                    comment: comment,
                    replying: _replyingId == comment.id,
                    sending: _sending && _replyingId == comment.id,
                    controller: _reply,
                    onReply: () => setState(() => _replyingId = comment.id),
                    onCancel: () => setState(() => _replyingId = null),
                    onPublic: () => _send(direct: false),
                    onDirect: () => _send(direct: true),
                    onOpenThread: comment.dmThreadId == null
                        ? null
                        : () => widget.onOpenThread(comment.dmThreadId!),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.brand.withValues(alpha: 0.12) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? colors.brand : colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: context.textStyles.captionSans.copyWith(
              color: selected ? colors.brand : colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.replying,
    required this.sending,
    required this.controller,
    required this.onReply,
    required this.onCancel,
    required this.onPublic,
    required this.onDirect,
    this.onOpenThread,
  });

  final MetaComment comment;
  final bool replying;
  final bool sending;
  final TextEditingController controller;
  final VoidCallback onReply;
  final VoidCallback onCancel;
  final VoidCallback onPublic;
  final VoidCallback onDirect;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final kind = switch (comment.mediaType) {
      'REELS' => language.translate('meta_comments_reel'),
      'STORY' => language.translate('meta_comments_story'),
      _ => language.translate('meta_comments_post'),
    };
    final when = formatLocalizedDateTime(
      context,
      comment.createdAt,
      style: LocalizedDateTimeStyle.dayMonthTime,
    );
    final thumb = comment.mediaThumb;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumb != null && thumb.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumb,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    cacheWidth: thumbCacheExtent(context, 44),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (comment.authorUsername ?? '').isEmpty
                          ? kind
                          : '@${comment.authorUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$kind · $when',
                      style: textStyles.smallSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (comment.seenAt == null && comment.unanswered)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    language.translate('meta_comments_unseen'),
                    style: textStyles.smallSans.copyWith(
                      color: colors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.text, style: textStyles.bodySans),
          if ((comment.mediaCaption ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment.mediaCaption!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (comment.repliedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              comment.replyBy == null
                  ? language.translate('meta_comments_replied_ai')
                  : language.translate('meta_comments_replied'),
              style: textStyles.captionSans.copyWith(color: colors.brand),
            ),
            if ((comment.replyText ?? '').isNotEmpty)
              Text(comment.replyText!, style: textStyles.captionSans),
          ] else if (comment.aiStatus == 'skipped')
            Text(
              language.translate('meta_comments_ai_skipped'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            )
          else if (comment.aiStatus == 'failed')
            Text(
              language.translate('meta_comments_ai_failed'),
              style: textStyles.captionSans.copyWith(color: colors.accentAmber),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (comment.mediaPermalink != null)
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(comment.mediaPermalink!),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(language.translate('meta_comments_open_post')),
                ),
              if (onOpenThread != null)
                TextButton(
                  onPressed: onOpenThread,
                  child: Text(language.translate('meta_comments_open_dialog')),
                ),
            ],
          ),
          if (!replying && comment.unanswered)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onReply,
                child: Text(language.translate('meta_comments_reply')),
              ),
            ),
          if (replying) ...[
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: language.translate('meta_comments_reply_ph'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: sending ? null : onPublic,
                child: Text(language.translate('meta_comments_public')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: sending || !comment.dmAllowed ? null : onDirect,
                child: Text(language.translate('meta_comments_dm')),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: sending ? null : onCancel,
                child: Text(language.translate('meta_comments_cancel')),
              ),
            ),
            if (!comment.dmAllowed)
              Text(
                language.translate('meta_comments_dm_expired'),
                style: textStyles.smallSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
