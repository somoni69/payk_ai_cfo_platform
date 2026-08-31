import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../crm/domain/crm_models.dart';
import '../../crm/domain/crm_repository.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';

/// Meta chats (Facebook / Instagram / WhatsApp) — Grounded Enterprise design.
class MetaScreen extends StatefulWidget {
  const MetaScreen({super.key});

  @override
  State<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends State<MetaScreen> {
  static const _metaChannels = ['', 'facebook', 'instagram', 'whatsapp'];
  static const _pollEvery = Duration(seconds: 15);

  MetaStatus? _status;
  List<MetaThread> _threads = const [];
  bool _loading = true;
  String? _error;
  String _channel = '';
  MetaThread? _selected;
  List<MetaMessage> _messages = const [];
  bool _loadingMessages = false;
  bool _sending = false;
  final _replyController = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(_pollEvery, (_) {
      if (!mounted || _loading) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = context.read<MetaRepository>();
      final results = await Future.wait<Object>([
        repo.getStatus(),
        repo.getThreads(channel: _channel.isEmpty ? null : _channel),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as MetaStatus;
        _threads = results[1] as List<MetaThread>;
        _loading = false;
        _error = null;
      });
      final selected = _selected;
      if (silent && selected != null) {
        try {
          final messages = await context.read<MetaRepository>().getMessages(
            selected.id,
          );
          if (!mounted) return;
          setState(() => _messages = messages);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _openThread(MetaThread thread) async {
    setState(() {
      _selected = thread;
      _loadingMessages = true;
      _messages = const [];
    });
    try {
      final messages = await context.read<MetaRepository>().getMessages(
        thread.id,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMessages = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _send() async {
    final thread = _selected;
    final text = _replyController.text.trim();
    if (thread == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await context.read<MetaRepository>().reply(thread.id, text);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _replyController.clear();
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final language = context.read<LanguageCubit>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.resolveMessage(e.toString().replaceAll('Exception: ', '')),
          ),
        ),
      );
    }
  }

  Future<void> _suggest() async {
    final thread = _selected;
    if (thread == null || _sending) return;
    setState(() => _sending = true);
    try {
      final suggestion = await context.read<MetaRepository>().suggestReply(
        thread.id,
      );
      if (!mounted) return;
      setState(() {
        _replyController.text = suggestion;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final language = context.read<LanguageCubit>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.resolveMessage(e.toString().replaceAll('Exception: ', '')),
          ),
        ),
      );
    }
  }

  Future<void> _showLinkClientSheet(BuildContext context) async {
    final thread = _selected;
    if (thread == null) return;
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
              final updated = await context.read<MetaRepository>().linkClient(
                thread.id,
                clientIdInt,
              );
              if (mounted) {
                setState(() => _selected = updated);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              setSheetState(() => saving = false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      language.resolveMessage(
                        e.toString().replaceAll('Exception: ', ''),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _selected != null
            ? IconButton(
                icon: const Icon(TablerIcons.arrow_left),
                onPressed: () => setState(() {
                  _selected = null;
                  _messages = const [];
                }),
              )
            : null,
        title: Text(
          _selected == null
              ? language.translate('meta_title')
              : _selected!.displayName,
          style: textStyles.h2Sans.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          if (_selected != null) ...[
            IconButton(
              tooltip: language.translate('meta_link_client'),
              onPressed: () => _showLinkClientSheet(context),
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
      body: _selected == null
          ? _buildThreadList(context, language, colors, textStyles)
          : _buildChat(context, language, colors, textStyles),
    );
  }

  String get _webhookUrl {
    final base = ApiClient.configuredBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/meta/webhook';
  }

  Future<void> _copyWebhookUrl() async {
    await Clipboard.setData(ClipboardData(text: _webhookUrl));
    if (!mounted) return;
    final language = context.read<LanguageCubit>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(language.translate('meta_webhook_copied'))),
    );
  }

  Widget _buildWebhookCard(
    LanguageCubit language,
    LedgerColors colors,
    LedgerTextStyles textStyles,
  ) {
    final connected = _status?.connected == true;
    final tone = connected ? colors.accentGreen : colors.accentAmber;
    final channels = _status?.channels ?? const <String>[];
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
              _status?.note?.isNotEmpty == true
                  ? _status!.note!
                  : language.translate('meta_not_connected'),
              style: textStyles.captionSans.copyWith(color: tone),
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
    LanguageCubit language,
    LedgerColors colors,
    LedgerTextStyles textStyles,
  ) {
    if (_loading) {
      return const MetaOverviewShimmer();
    }
    if (_error != null && _threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.resolveMessage(_error!),
                textAlign: TextAlign.center,
                style: textStyles.bodySans,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: Text(language.translate('common_retry')),
              ),
            ],
          ),
        ),
      );
    }

    const headerCount = 2;
    final itemCount = headerCount + (_threads.isEmpty ? 1 : _threads.length);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          var cursor = index;
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWebhookCard(language, colors, textStyles),
            );
          }
          cursor -= 1;
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _metaChannels.length,
                  itemBuilder: (context, chipIndex) {
                    final ch = _metaChannels[chipIndex];
                    final isSel = _channel == ch;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          ch.isEmpty
                              ? language.translate('meta_channel_all')
                              : language.translate('meta_channel_$ch'),
                        ),
                        selected: isSel,
                        selectedColor: colors.brand,
                        labelStyle: textStyles.captionSans.copyWith(
                          color: isSel ? Colors.white : colors.textPrimary,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        ),
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: isSel ? colors.brand : colors.border,
                        ),
                        onSelected: (val) {
                          if (!val) return;
                          setState(() => _channel = ch);
                          _load(silent: true);
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          }
          if (_threads.isEmpty) {
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
          final t = _threads[cursor - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _openThread(t),
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
    LanguageCubit language,
    LedgerColors colors,
    LedgerTextStyles textStyles,
  ) {
    return Column(
      children: [
        Expanded(
          child: _loadingMessages
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
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index];
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
                            Text(m.text, style: textStyles.captionSans),
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
                onPressed: _sending ? null : _suggest,
                icon: Icon(TablerIcons.pencil, color: colors.brand),
              ),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  enabled: !_sending,
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
                onPressed: _sending ? null : _send,
                icon: _sending
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
