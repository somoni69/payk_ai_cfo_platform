import 'dart:async';

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
import '../cubit/meta_cubit.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';
import 'meta_attachments.dart';

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
        create: (ctx) => MetaCubit(ctx.read<MetaRepository>())
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
              setSheetState(() {
                clients = res.items;
                searching = false;
              });
            } catch (_) {
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
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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
            params: {'peer': thread.displayName},
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
            child: Text(language.translate('common_delete')),
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

        return Scaffold(
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
            title: Text(
              selected == null
                  ? language.translate('meta_title')
                  : selected.displayName,
              style: textStyles.h2Sans.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            actions: [
              if (selected != null) ...[
                if (_canDeleteThread(context))
                  IconButton(
                    tooltip: language.translate('meta_delete'),
                    onPressed: () => _confirmDeleteThread(context, selected),
                    icon: Icon(
                      TablerIcons.trash,
                      size: 20,
                      color: colors.accentRed,
                    ),
                  ),
                IconButton(
                  tooltip: language.translate('meta_link_client'),
                  onPressed: () => _showLinkClientSheet(context, selected),
                  icon: const Icon(TablerIcons.link, size: 20),
                ),
                const SizedBox(width: 4),
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: colors.border),
            ),
          ),
          body: selected == null
              ? _buildThreadList(context, state, language, colors, textStyles)
              : _buildChat(context, state, language, colors, textStyles),
        );
      },
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
            Text(
              channels
                  .map((ch) => language.translate('meta_channel_$ch'))
                  .join(' · '),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
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

    const headerCount = 2;
    final threads = state.threads;
    final itemCount = headerCount + (threads.isEmpty ? 1 : threads.length);

    return RefreshIndicator(
      onRefresh: () => context.read<MetaCubit>().load(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          var cursor = index;
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWebhookCard(
                state.status,
                language,
                colors,
                textStyles,
              ),
            );
          }
          cursor -= 1;
          if (cursor == 0) {
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
          final t = threads[cursor - 1];
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.displayName,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.lastText ?? '',
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceNested,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            language.translate('meta_channel_${t.channel}'),
                            style: textStyles.smallSans.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (t.unread > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.brand.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${t.unread}',
                              style: textStyles.smallSans.copyWith(
                                color: colors.brand,
                                fontWeight: FontWeight.w600,
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    return Align(
                      alignment: m.outgoing
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: m.outgoing
                              ? colors.brand.withValues(alpha: 0.08)
                              : colors.surfaceNested,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: m.outgoing
                                ? colors.brand.withValues(alpha: 0.35)
                                : colors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (metaTextWithoutLabels(m.text, m.attachments)
                                case final visibleText
                                when visibleText.isNotEmpty)
                              Text(visibleText, style: textStyles.captionSans),
                            MetaAttachments(
                              items: m.attachments,
                              outgoing: m.outgoing,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatLocalizedDateTime(
                                context,
                                m.createdAt,
                                style: LocalizedDateTimeStyle.dateTime,
                              ),
                              style: textStyles.smallSans.copyWith(
                                color: colors.textTooltip,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
            color: colors.surface,
          ),
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            8,
            8 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: language.translate('meta_suggest'),
                onPressed: sending ? null : _suggest,
                icon: Icon(TablerIcons.pencil, color: colors.brand),
              ),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: language.translate('meta_reply_hint'),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: sending ? null : _send,
                icon: sending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.brand,
                        ),
                      )
                    : Icon(TablerIcons.send, color: colors.brand),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
