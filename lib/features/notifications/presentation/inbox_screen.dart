import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../domain/notification_model.dart';
import '../domain/notifications_repository.dart';

/// Full-screen personal inbox (`GET /notifications`).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<AppNotification> _items = const [];
  var _loading = true;
  var _markingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<NotificationsRepository>().getInbox(
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _unreadCount == 0) return;
    setState(() => _markingAll = true);
    try {
      await context.read<NotificationsRepository>().markAllRead();
      if (!mounted) return;
      setState(() {
        _items = [for (final n in _items) n.copyWith(isRead: true)];
        _markingAll = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _markingAll = false);
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

  Future<void> _openItem(AppNotification item) async {
    if (!item.isRead) {
      try {
        await context.read<NotificationsRepository>().markAsRead(item.id);
        if (!mounted) return;
        setState(() {
          _items = [
            for (final n in _items)
              n.id == item.id ? n.copyWith(isRead: true) : n,
          ];
        });
      } catch (_) {}
    }
    final link = item.link;
    if (link != null && link.startsWith('/') && mounted) {
      context.push(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final unread = _unreadCount;

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: language.translate('inbox_title'),
              pinned: true,
              floating: true,
              snap: true,
              actions: [
                if (unread > 0)
                  TextButton(
                    onPressed: _markingAll ? null : _markAllRead,
                    child: _markingAll
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.brand,
                            ),
                          )
                        : Text(language.translate('inbox_mark_all')),
                  ),
              ],
            ),
          ];
        },
        body: _loading
            ? const InboxOverviewShimmer()
            : RefreshIndicator(
                onRefresh: _load,
                child: _error != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 48),
                          Icon(
                            TablerIcons.alert_triangle,
                            color: colors.accentRed,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            language.resolveMessage(_error!),
                            textAlign: TextAlign.center,
                            style: textStyles.bodySans,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: _load,
                              child: Text(language.translate('common_retry')),
                            ),
                          ),
                        ],
                      )
                    : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 64),
                          Icon(
                            TablerIcons.bell_off,
                            color: colors.textTooltip,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            language.translate('inbox_empty'),
                            textAlign: TextAlign.center,
                            style: textStyles.bodySans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _items.length + 1,
                        separatorBuilder: (_, index) =>
                            SizedBox(height: index == 0 ? 12 : 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Text(
                              unread > 0
                                  ? language.translate(
                                      'inbox_unread_count',
                                      params: {'count': '$unread'},
                                    )
                                  : language.translate('inbox_all_read'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            );
                          }
                          final item = _items[index - 1];
                          return LedgerCard(
                            onTap: () => _openItem(item),
                            padding: const EdgeInsets.all(14),
                            backgroundColor: item.isRead
                                ? null
                                : colors.brand.withValues(alpha: 0.06),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.isRead
                                        ? colors.border
                                        : colors.brand,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: textStyles.bodySans.copyWith(
                                          fontWeight: item.isRead
                                              ? FontWeight.w400
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (item.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description,
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.textSecondary,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        formatLocalizedDateTime(
                                          context,
                                          item.dateTime,
                                          style:
                                              LocalizedDateTimeStyle.dateTime,
                                        ),
                                        style: textStyles.smallSans.copyWith(
                                          color: colors.textTooltip,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
