import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_segmented_control.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../crm/domain/crm_models.dart';
import '../../crm/domain/crm_repository.dart';
import '../cubit/chat_live_cubit.dart';
import '../data/chat_live_client.dart';
import '../cubit/meta_cubit.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';
import 'meta_analytics_view.dart';
import 'meta_chat_widgets.dart';
import 'meta_client_card.dart';
import 'meta_comments_screen.dart';
import 'meta_funnel_view.dart';

/// Meta chats (Facebook / Instagram / WhatsApp) — Grounded Enterprise design.
class MetaScreen extends StatelessWidget {
  const MetaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<MetaCubit>();
      return const _MetaScreenView();
    } catch (_) {
      return BlocProvider<MetaCubit>(
        create: (ctx) =>
            MetaCubit(
                ctx.read<MetaRepository>(),
                live: ctx.read<ChatLiveCubit>(),
              )
              ..load()
              ..startPolling(),
        child: const _MetaScreenView(),
      );
    }
  }
}

class _MetaScreenView extends StatefulWidget {
  const _MetaScreenView();

  @override
  State<_MetaScreenView> createState() => _MetaScreenViewState();
}

class _MetaScreenViewState extends State<_MetaScreenView> {
  static const _metaChannels = ['', 'facebook', 'instagram', 'whatsapp'];
  final _replyController = TextEditingController();
  String? _pane;
  List<MetaStage> _stages = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStages());
  }

  Future<void> _loadStages() async {
    try {
      final stages = await context.read<MetaRepository>().getStages();
      if (!mounted) return;
      setState(() => _stages = stages);
    } catch (_) {
      // Stage dots are optional; the list still works without them.
    }
  }

  String _title(MetaThread thread, LanguageCubit language) =>
      thread.titleOr(language.translate('meta_unnamed'));

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final cubit = context.read<MetaCubit>();
    _replyController.clear();
    await cubit.sendMessage(text);
  }

  /// Same formats the server accepts (`_OUT_KINDS` in routes/meta.py).
  static const _attachExtensions = [
    'jpg', 'jpeg', 'png', 'mp4', 'pdf', 'doc', 'docx', //
    'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'zip',
  ];

  Future<void> _attach() async {
    final cubit = context.read<MetaCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final language = context.read<LanguageCubit>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _attachExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(language.translate('meta_attach_empty'))),
      );
      return;
    }
    // The typed text goes as the file caption, like the web composer.
    final caption = _replyController.text.trim();
    _replyController.clear();
    cubit.composerStopped();
    await cubit.sendAttachment(
      filename: file.name,
      bytes: bytes,
      caption: caption,
    );
  }

  Future<void> _suggest() async {
    final cubit = context.read<MetaCubit>();
    final suggestion = await cubit.suggestReply();
    if (suggestion != null && mounted) {
      _replyController.text = suggestion;
    }
  }

  Future<void> _showLinkClientSheet(
    BuildContext context,
    MetaThread thread,
  ) async {
    final language = context.read<LanguageCubit>();
    final crmRepo = context.read<CrmRepository>();
    final colors = context.colors;
    final searchCtrl = TextEditingController();
    List<CrmClient> clients = const [];
    CrmClient? chosen;
    bool searching = false;
    bool saving = false;

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('meta_link_client_title'),
        builder: (ctx, setSheetState) {
          Future<void> doSearch() async {
            final q = searchCtrl.text.trim();
            if (q.isEmpty) return;
            setSheetState(() => searching = true);
            try {
              final res = await crmRepo.getClients(
                filters: ClientListFilters(query: q),
              );
              if (!ctx.mounted) return;
              setSheetState(() {
                clients = res.items;
                searching = false;
              });
            } catch (_) {
              if (!ctx.mounted) return;
              setSheetState(() => searching = false);
            }
          }

          Future<void> submit() async {
            if (chosen == null) return;
            setSheetState(() => saving = true);
            try {
              final clientIdInt = int.tryParse(chosen!.id) ?? 0;
              await context.read<MetaCubit>().linkClient(clientIdInt);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (!ctx.mounted) return;
              setSheetState(() => saving = false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      language.resolveMessage(
                        userFacingError(e, fallback: ErrorKeys.saveFailed),
                      ),
                    ),
                  ),
                );
              }
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: language.translate('meta_link_search_hint'),
                        isDense: true,
                      ),
                      onSubmitted: (_) => doSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: searching ? null : doSearch,
                    icon: searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(TablerIcons.search),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (clients.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: clients.length,
                    itemBuilder: (_, i) {
                      final c = clients[i];
                      final isSelected = chosen?.id == c.id;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        title: Text(c.fullName),
                        subtitle: Text(c.phone ?? ''),
                        trailing: isSelected
                            ? Icon(TablerIcons.check, color: colors.brand)
                            : null,
                        onTap: () => setSheetState(() => chosen = c),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: chosen == null || saving ? null : submit,
                child: saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onBrand,
                        ),
                      )
                    : Text(language.translate('meta_link_submit')),
              ),
            ],
          );
        },
      );
    } finally {
      searchCtrl.dispose();
    }
  }

  String get _webhookUrl {
    final base = ApiClient.configuredBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/meta/webhook';
  }

  bool _canDeleteThread(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated &&
        (auth.role == UserRole.owner || auth.role == UserRole.director);
  }

  Future<void> _confirmDeleteThread(
    BuildContext context,
    MetaThread thread,
  ) async {
    final language = context.read<LanguageCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          language.translate(
            'meta_delete_title',
            params: {'peer': _title(thread, language)},
          ),
        ),
        content: Text(language.translate('meta_delete_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              language.translate('common_delete'),
              style: TextStyle(color: context.colors.accentRed),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final deleted = await context.read<MetaCubit>().deleteThread();
    if (!context.mounted || !deleted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(language.translate('meta_deleted'))));
  }

  Future<void> _copyWebhookUrl() async {
    await Clipboard.setData(ClipboardData(text: _webhookUrl));
    if (!mounted) return;
    final language = context.read<LanguageCubit>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(language.translate('meta_webhook_copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return BlocConsumer<MetaCubit, MetaState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(language.resolveMessage(state.error!)),
              backgroundColor: colors.accentRed,
            ),
          );
        }
      },
      builder: (context, state) {
        final selected = state.selectedThread;

        return PopScope(
          canPop: selected == null,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            context.read<MetaCubit>().selectThread(null);
          },
          child: Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: selected != null
                  ? IconButton(
                      icon: const Icon(TablerIcons.arrow_left),
                      onPressed: () =>
                          context.read<MetaCubit>().selectThread(null),
                    )
                  : null,
              titleSpacing: selected == null ? null : 0,
              title: selected == null
                  ? Text(
                      language.translate('meta_title'),
                      style: textStyles.h2Sans.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    )
                  : BlocSelector<ChatLiveCubit, ChatLiveState, bool>(
                      selector: (live) => live.status == ChatLiveStatus.offline,
                      builder: (context, offline) => MetaChatTitle(
                        name: _title(selected, language),
                        channel: selected.channel,
                        offline: offline,
                        channelMark: _channelMark(selected.channel, language),
                      ),
                    ),
              actions: [
                if (selected == null)
                  IconButton(
                    tooltip: language.translate('settings_title'),
                    onPressed: () => _showWebhookSheet(state.status),
                    icon: const Icon(TablerIcons.settings),
                  ),
                if (selected != null) ...[
                  IconButton(
                    tooltip: language.translate('meta_tab_funnel'),
                    onPressed: () async {
                      final next = await showMetaFunnelSheet(context, selected);
                      if (next != null && context.mounted) {
                        await context.read<MetaCubit>().load(silent: true);
                      }
                    },
                    icon: const Icon(TablerIcons.layout_kanban, size: 20),
                  ),
                  IconButton(
                    tooltip: language.translate('meta_link_client'),
                    onPressed: () => _showLinkClientSheet(context, selected),
                    icon: const Icon(TablerIcons.user_plus, size: 20),
                  ),
                  if (_canDeleteThread(context))
                    PopupMenuButton<String>(
                      tooltip: language.translate('meta_more_actions'),
                      icon: const Icon(TablerIcons.dots_vertical, size: 20),
                      color: colors.surface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors.border),
                      ),
                      onSelected: (_) =>
                          _confirmDeleteThread(context, selected),
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                TablerIcons.trash,
                                size: 18,
                                color: colors.accentRed,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                language.translate('meta_delete'),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.accentRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 4),
                ],
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(selected == null ? 45 : 1),
                child: Column(
                  children: [
                    if (selected == null)
                      _MetaModeBar(
                        pane: _pane,
                        onChanged: (pane) => setState(() => _pane = pane),
                      ),
                    Container(height: 1, color: colors.border),
                  ],
                ),
              ),
            ),
            body: selected != null
                ? _buildChat(context, state, language, colors, textStyles)
                : _pane == 'comments'
                ? MetaCommentsScreen(
                    onOpenThread: (id) {
                      MetaThread? found;
                      for (final thread in state.threads) {
                        if (thread.id == id) found = thread;
                      }
                      context.read<MetaCubit>().selectThread(
                        found ??
                            MetaThread(
                              id: id,
                              channel: 'instagram',
                              peerId: '$id',
                            ),
                      );
                    },
                  )
                : _pane == 'funnel'
                ? MetaFunnelView(
                    threads: state.threads,
                    onOpen: (thread) {
                      context.read<MetaCubit>().selectThread(thread);
                    },
                    onCard: (thread, tab) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MetaClientCardScreen(
                            thread: thread,
                            initialTab: tab,
                            onOpenChat: () {
                              Navigator.of(context).pop();
                              context.read<MetaCubit>().selectThread(thread);
                            },
                          ),
                        ),
                      );
                    },
                    onMoved: () async {
                      await context.read<MetaCubit>().load(silent: true);
                      await _loadStages();
                    },
                  )
                : _pane == 'analytics'
                ? const MetaAnalyticsView()
                : _buildThreadList(
                    context,
                    state,
                    language,
                    colors,
                    textStyles,
                  ),
          ),
        );
      },
    );
  }

  void _showWebhookSheet(MetaStatus? status) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    LedgerBottomSheet.show(
      context: context,
      title: language.translate('settings_title'),
      builder: (context, _) =>
          _buildWebhookCard(status, language, colors, textStyles),
    );
  }

  Widget _channelMark(String channel, LanguageCubit language) {
    final (icon, color) = switch (channel) {
      'facebook' => (TablerIcons.brand_facebook, const Color(0xFF1877F2)),
      'instagram' => (TablerIcons.brand_instagram, const Color(0xFFE4405F)),
      'whatsapp' => (TablerIcons.brand_whatsapp, const Color(0xFF25D366)),
      _ => (TablerIcons.brand_meta, context.colors.textSecondary),
    };
    final label = language.translate('meta_channel_$channel');
    return Tooltip(
      message: label,
      child: Icon(icon, size: 22, color: color, semanticLabel: label),
    );
  }

  Widget _buildWebhookCard(
    MetaStatus? status,
    LanguageCubit language,
    LedgerColors colors,
    LedgerTextStyles textStyles,
  ) {
    final connected = status?.connected == true;
    final tone = connected ? colors.accentGreen : colors.accentAmber;
    final channels = status?.channels ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? TablerIcons.circle_check : TablerIcons.webhook,
                color: tone,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  language.translate('meta_webhook_title'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  language.translate(
                    connected
                        ? 'meta_status_connected'
                        : 'meta_status_disconnected',
                  ),
                  style: textStyles.captionSans.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          if (channels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final channel in channels) _channelMark(channel, language),
              ],
            ),
          ],
          if (!connected) ...[
            const SizedBox(height: 8),
            Text(
              status?.note?.isNotEmpty == true
                  ? status!.note!
                  : language.translate('meta_not_connected'),
              style: textStyles.captionSans.copyWith(color: tone),
            ),
          ],
          for (final account in status?.accounts ?? const <MetaAccount>[])
            if (account.error != null && account.error!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                language.translate(
                  'meta_broken',
                  params: {
                    'channel': language.translate(
                      'meta_channel_${account.channel}',
                    ),
                    'error': account.error!,
                  },
                ),
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
          const SizedBox(height: 10),
          Text(
            language.translate('meta_webhook_url'),
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _webhookUrl,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: language.translate('meta_webhook_copy'),
                onPressed: _copyWebhookUrl,
                icon: Icon(TablerIcons.copy, size: 18, color: colors.brand),
              ),
            ],
          ),
          Text(
            language.translate('meta_webhook_hint'),
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    MetaState state,
    LanguageCubit language,
    LedgerColors colors,
    LedgerTextStyles textStyles,
  ) {
    if (state.isLoading && state.threads.isEmpty) {
      return const MetaOverviewShimmer();
    }
    if (state.error != null && state.threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.resolveMessage(state.error!),
                textAlign: TextAlign.center,
                style: textStyles.bodySans,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.read<MetaCubit>().load(),
                child: Text(language.translate('common_retry')),
              ),
            ],
          ),
        ),
      );
    }

    final threads = state.threads;
    final itemCount = 1 + (threads.isEmpty ? 1 : threads.length);

    return RefreshIndicator(
      onRefresh: () => context.read<MetaCubit>().load(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerSegmentedControl<String>(
                height: 36,
                selectedValue: state.selectedChannel,
                onValueChanged: (ch) {
                  context.read<MetaCubit>().setChannel(ch);
                },
                segments: [
                  for (final ch in _metaChannels)
                    LedgerSegmentItem(
                      value: ch,
                      label: ch.isEmpty
                          ? language.translate('meta_channel_all')
                          : language.translate('meta_channel_$ch'),
                    ),
                ],
              ),
            );
          }
          if (threads.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  language.translate('meta_empty_threads'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            );
          }
          final t = threads[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => context.read<MetaCubit>().selectThread(t),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    _channelMark(t.channel, language),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(t, language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (t.lastText ?? '').trim().isEmpty
                                ? language.translate('meta_empty_preview')
                                : t.lastText!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_stageDot(t) case final dot?) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _threadWhen(context, t.lastMessageAt),
                              style: textStyles.smallSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (t.unread > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.brand,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              '${t.unread}',
                              textAlign: TextAlign.center,
                              style: textStyles.smallSans.copyWith(
                                color: colors.onBrand,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChat(
    BuildContext context,
    MetaState state,
    LanguageCubit language,
    LedgerColors colors,
    LedgerTextStyles textStyles,
  ) {
    final messages = state.messages;
    final sending = state.isSending;
    final peerReadAt = state.selectedThread?.peerReadAt;

    return Column(
      children: [
        Expanded(
          child: state.isLoadingMessages
              ? const LedgerShimmer(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 240, height: 52, borderRadius: 12),
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ShimmerBox(
                            width: 180,
                            height: 40,
                            borderRadius: 12,
                          ),
                        ),
                        SizedBox(height: 10),
                        ShimmerBox(width: 200, height: 44, borderRadius: 12),
                      ],
                    ),
                  ),
                )
              : MetaMessageList(messages: messages, peerReadAt: peerReadAt),
        ),
        BlocSelector<ChatLiveCubit, ChatLiveState, bool>(
          selector: (live) => live.status == ChatLiveStatus.offline,
          builder: (context, offline) => offline
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    border: Border(top: BorderSide(color: colors.border)),
                  ),
                  child: Text(
                    language.translate('meta_live_offline'),
                    style: textStyles.smallSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        MetaComposer(
          controller: _replyController,
          sending: sending,
          canSendAddress: context.select<MetaCubit, bool>(
            (cubit) => cubit.state.status?.place != null,
          ),
          onSend: _send,
          onAttach: _attach,
          onSendAddress: () => context.read<MetaCubit>().sendOurAddress(),
          onSuggest: _suggest,
          onChanged: context.read<MetaCubit>().composerChanged,
        ),
      ],
    );
  }

  Color? _stageDot(MetaThread thread) {
    if (_stages.isEmpty) return null;
    final index = _stages.indexWhere((stage) => stage.id == thread.stageId);
    final stage = index < 0 ? _stages.first : _stages[index];
    return metaStageColor(stage.color, context.colors.brand);
  }

  String _threadWhen(BuildContext context, DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return formatLocalizedDateTime(
      context,
      at,
      style: sameDay
          ? LocalizedDateTimeStyle.time
          : LocalizedDateTimeStyle.dayMonthTime,
    );
  }
}

class _MetaModeBar extends StatelessWidget {
  const _MetaModeBar({required this.pane, required this.onChanged});

  final String? pane;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final items = <(String?, String)>[
      (null, language.translate('meta_tab_dialogs')),
      ('comments', language.translate('meta_tab_comments')),
      ('funnel', language.translate('meta_tab_funnel')),
      ('analytics', language.translate('meta_tab_analytics')),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          for (final item in items)
            InkWell(
              onTap: () => onChanged(item.$1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: pane == item.$1 ? colors.brand : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      item.$2,
                      softWrap: false,
                      style: context.textStyles.captionSans.copyWith(
                        color: pane == item.$1
                            ? colors.brand
                            : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
