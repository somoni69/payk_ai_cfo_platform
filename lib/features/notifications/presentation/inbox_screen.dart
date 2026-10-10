import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/observability/app_error_reporter.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
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
        _error = userFacingError(e);
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
        SnackBar(content: Text(language.resolveMessage(userFacingError(e)))),
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
      } catch (e, st) {
        // Opening the link matters more; the item simply stays unread.
        AppErrorReporter.reportOptional(e, st, context: 'inbox_mark_read');
      }
    }

    String destination = '/dashboard';
    final link = item.link;
    if (link != null && link.startsWith('/')) {
      destination = link;
    } else {
      final id = item.id.toLowerCase();
      final title = item.title.toLowerCase();
      final desc = item.description.toLowerCase();

      if (id.startsWith('anomaly_task') ||
          title.contains('задач') ||
          desc.contains('задач') ||
          title.contains('task')) {
        destination = '/tasks';
      } else if (id.startsWith('anomaly_night') ||
          id.startsWith('cash_') ||
          title.contains('касс') ||
          desc.contains('касс') ||
          title.contains('aud-05')) {
        destination = '/cash';
      } else if (id.startsWith('audit_') ||
          title.contains('аудит') ||
          item.type == NotificationType.audit) {
        destination = '/audit';
      } else if (item.type == NotificationType.legalCalendar ||
          title.contains('налог') ||
          title.contains('закон')) {
        destination = '/legal';
      } else if (item.type == NotificationType.aiForecast ||
          item.type == NotificationType.aiAdvice ||
          title.contains('стратег')) {
        destination = '/strategy';
      } else if (title.contains('склад') || desc.contains('товар')) {
        destination = '/warehouse';
      } else if (title.contains('отчет') || desc.contains('выручк')) {
        destination = '/reports';
      } else if (title.contains('клиент') || title.contains('crm')) {
        destination = '/crm';
      } else if (title.contains('сотрудник') || title.contains('кадр')) {
        destination = '/hr';
      }
    }

    if (mounted) {
      if (destination == '/tasks' ||
          destination == '/cash' ||
          destination == '/warehouse' ||
          destination == '/dashboard' ||
          destination == '/more') {
        context.go(destination);
      } else {
        context.push(destination);
      }
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
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          language.translate('inbox_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
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
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
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
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        final item = _items[index - 1];
                        return InkWell(
                          onTap: () => _openItem(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: item.isRead
                                  ? colors.surface
                                  : colors.brand.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: item.isRead
                                    ? colors.border
                                    : colors.brand.withValues(alpha: 0.3),
                              ),
                            ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: textStyles.bodySans.copyWith(
                                          fontWeight: item.isRead
                                              ? FontWeight.w500
                                              : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (item.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description,
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 13,
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
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
