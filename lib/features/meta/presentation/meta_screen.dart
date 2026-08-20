import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../crm/domain/crm_models.dart';
import '../../crm/domain/crm_repository.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';

/// Meta chats (Facebook / Instagram / WhatsApp) — Ledger-styled mobile list.
class MetaScreen extends StatefulWidget {
  const MetaScreen({super.key});

  @override
  State<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends State<MetaScreen> {
  static const _metaChannels = ['', 'facebook', 'instagram', 'whatsapp'];

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      final statusFuture = _status == null
          ? repo.getStatus()
          : Future<MetaStatus>.value(_status!);
      final results = await Future.wait<Object>([
        statusFuture,
        repo.getThreads(channel: _channel.isEmpty ? null : _channel),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as MetaStatus;
        _threads = results[1] as List<MetaThread>;
        _loading = false;
        _error = null;
      });
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
            language.resolveMessage(
              e.toString().replaceAll('Exception: ', ''),
            ),
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
    }
  }

  Future<void> _showLinkClientSheet(BuildContext context) async {
    final thread = _selected;
    if (thread == null) return;
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final searchCtrl = TextEditingController(
      text: thread.peerPhone ?? '',
    );
    List<CrmClient> results = const [];
    var searching = true;
    int? pickedId = thread.clientId;
    var linking = false;

    Future<void> runSearch(StateSetter setSheet) async {
      setSheet(() => searching = true);
      try {
        final page = await context.read<CrmRepository>().getClients(
          filters: ClientListFilters(
            query: searchCtrl.text.trim().isEmpty
                ? null
                : searchCtrl.text.trim(),
            page: 1,
            size: 20,
          ),
          forceRefresh: true,
        );
        setSheet(() {
          results = page.items;
          searching = false;
        });
      } catch (_) {
        setSheet(() {
          results = const [];
          searching = false;
        });
      }
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('meta_link_title'),
        builder: (sheetContext, setSheet) {
          // First frame search.
          if (searching && results.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (sheetContext.mounted) unawaited(runSearch(setSheet));
            });
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                language.translate(
                  'meta_link_hint',
                  params: {
                    'peer': thread.peerName ??
                        thread.peerPhone ??
                        thread.peerId,
                  },
                ),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (thread.clientName != null &&
                  thread.clientName!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                LedgerPill(
                  text: language.translate(
                    'meta_link_current',
                    params: {'name': thread.clientName},
                  ),
                  backgroundColor: colors.brand.withValues(alpha: 0.1),
                  textColor: colors.brand,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  labelText: language.translate('meta_link_search'),
                  prefixIcon: const Icon(TablerIcons.search, size: 20),
                ),
                onSubmitted: (_) => runSearch(setSheet),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: searching ? null : () => runSearch(setSheet),
                child: Text(language.translate('common_retry')),
              ),
              const SizedBox(height: 12),
              if (searching)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (results.isEmpty)
                Text(
                  language.translate('meta_link_empty'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textTooltip,
                  ),
                )
              else
                ...results.map((c) {
                  final id = int.tryParse(c.id);
                  final selected = id != null && id == pickedId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LedgerCard(
                      onTap: id == null
                          ? null
                          : () => setSheet(() => pickedId = id),
                      borderColor: selected ? colors.brand : null,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.fullName,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (c.phone != null && c.phone!.isNotEmpty)
                            Text(
                              c.phone!,
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: pickedId == null || linking
                    ? null
                    : () async {
                        setSheet(() => linking = true);
                        try {
                          final updated = await context
                              .read<MetaRepository>()
                              .linkClient(thread.id, pickedId!);
                          if (!context.mounted) return;
                          setState(() {
                            _selected = updated;
                            _threads = _threads
                                .map((t) => t.id == updated.id ? updated : t)
                                .toList();
                          });
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                language.translate('meta_link_success'),
                              ),
                              backgroundColor: colors.accentGreen,
                            ),
                          );
                        } catch (e) {
                          setSheet(() => linking = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                language.resolveMessage(
                                  e.toString().replaceAll('Exception: ', ''),
                                ),
                              ),
                              backgroundColor: colors.accentRed,
                            ),
                          );
                        }
                      },
                child: linking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          LedgerCollapsingHeader(
            title: _selected == null
                ? language.translate('meta_title')
                : _selected!.displayName,
            pinned: true,
            floating: true,
            snap: true,
            actions: _selected != null
                ? [
                    IconButton(
                      tooltip: language.translate('meta_link_client'),
                      onPressed: () => _showLinkClientSheet(context),
                      icon: const Icon(TablerIcons.link, size: 20),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _selected = null;
                        _messages = const [];
                      }),
                      icon: const Icon(TablerIcons.arrow_left),
                    ),
                  ]
                : null,
          ),
        ],
        body: _selected == null
            ? _buildThreadList(context, language, colors, textStyles)
            : _buildChat(context, language, colors, textStyles),
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

    final showBanner = _status != null && !_status!.connected;
    final headerCount = showBanner ? 2 : 1;
    final itemCount = headerCount + (_threads.isEmpty ? 1 : _threads.length);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          var cursor = index;
          if (showBanner) {
            if (cursor == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                  borderColor: colors.accentAmber,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        TablerIcons.info_circle,
                        color: colors.accentAmber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _status!.note?.isNotEmpty == true
                              ? _status!.note!
                              : language.translate('meta_not_connected'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.accentAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            cursor -= 1;
          }
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
                        labelStyle: textStyles.captionSans.copyWith(
                          color: isSel ? Colors.white : colors.textPrimary,
                          fontWeight: isSel
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        checkmarkColor: Colors.white,
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
            child: LedgerCard(
              onTap: () => _openThread(t),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.displayName,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.lastText ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LedgerPill(
                        text: language.translate('meta_channel_${t.channel}'),
                        backgroundColor: colors.surfaceNested,
                        textColor: colors.textSecondary,
                      ),
                      if (t.unread > 0) ...[
                        const SizedBox(height: 6),
                        LedgerPill(
                          text: '${t.unread}',
                          backgroundColor: colors.brand.withValues(
                            alpha: 0.12,
                          ),
                          textColor: colors.brand,
                        ),
                      ],
                    ],
                  ),
                ],
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
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                icon: Icon(TablerIcons.sparkles, color: colors.accentAmber),
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
