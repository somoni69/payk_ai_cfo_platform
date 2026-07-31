import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/locale_date_time_format.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/notifications/bloc/notifications_bloc.dart';
import '../../features/notifications/bloc/notifications_event.dart';
import '../../features/notifications/bloc/notifications_state.dart';
import '../../features/notifications/domain/notifications_repository.dart';
import '../../features/notifications/domain/notification_model.dart';
import '../widgets/ledger_ai_card.dart';
import '../widgets/ledger_card.dart';

/// Входная точка экрана уведомлений с внедрением NotificationsBloc.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsBloc>(
      create: (context) =>
          NotificationsBloc(context.read<NotificationsRepository>())
            ..add(LoadNotifications()),
      child: const NotificationsView(),
    );
  }
}

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  static const _pageSize = 60;

  final ScrollController _scrollController = ScrollController();
  int _visibleNotifications = _pageSize;
  Completer<void>? _refreshCompleter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_revealMoreNotifications);
  }

  void _revealMoreNotifications() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    final state = context.read<NotificationsBloc>().state;
    if (state is! NotificationsLoaded) return;
    final total = state.notifications.where((item) => !item.isRead).length;
    if (_visibleNotifications >= total) return;
    final next = _visibleNotifications + _pageSize;
    setState(() => _visibleNotifications = next < total ? next : total);
  }

  Future<void> _refreshNotifications() {
    final active = _refreshCompleter;
    if (active != null && !active.isCompleted) return active.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _visibleNotifications = _pageSize;
    context.read<NotificationsBloc>().add(
      LoadNotifications(forceRefresh: true, completion: completer),
    );
    return completer.future;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_revealMoreNotifications)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.watch<LanguageCubit>();

    return BlocConsumer<NotificationsBloc, NotificationsState>(
      listener: (context, state) {
        if (state is NotificationsLoaded && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageCubit.translateMessage(state.errorMessage!),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is NotificationsLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              title: Text(
                languageCubit.translate('notifications_title'),
                style: textStyles.h1Sans.copyWith(
                  fontSize: MediaQuery.of(context).size.width >= 600
                      ? 22.0
                      : 20.0,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is NotificationsError) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.alert_triangle,
                      color: colors.accentRed,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      languageCubit.translateMessage(state.message),
                      style: textStyles.bodySans,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<NotificationsBloc>().add(
                          LoadNotifications(),
                        );
                      },
                      child: Text(
                        languageCubit.translate('notifications_retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is NotificationsLoaded) {
          final unreadNotifications = state.notifications
              .where((n) => !n.isRead)
              .toList();

          final visibleNotifications = unreadNotifications
              .take(_visibleNotifications)
              .toList(growable: false);
          final criticalAlerts = visibleNotifications
              .where((n) => n.severity == NotificationSeverity.critical)
              .toList(growable: false);
          final importantAlerts = visibleNotifications
              .where((n) => n.severity == NotificationSeverity.important)
              .toList(growable: false);
          final infoAlerts = visibleNotifications
              .where((n) => n.severity == NotificationSeverity.info)
              .toList(growable: false);

          return Scaffold(
            appBar: AppBar(
              backgroundColor: colors.surface,
              scrolledUnderElevation: 0,
              title: Text(
                languageCubit.translate('notifications_title'),
                style: textStyles.h1Sans.copyWith(
                  fontSize: MediaQuery.of(context).size.width >= 600
                      ? 22.0
                      : 20.0,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(color: colors.border, height: 1.0),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: _refreshNotifications,
              child: _buildNotificationsList(
                context,
                unreadNotifications: unreadNotifications,
                criticalAlerts: criticalAlerts,
                importantAlerts: importantAlerts,
                infoAlerts: infoAlerts,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildNotificationsList(
    BuildContext context, {
    required List<AppNotification> unreadNotifications,
    required List<AppNotification> criticalAlerts,
    required List<AppNotification> importantAlerts,
    required List<AppNotification> infoAlerts,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final entries = <WidgetBuilder>[];

    void addSection({
      required List<AppNotification> alerts,
      required IconData icon,
      required Color color,
      required String titleKey,
      required Widget Function(BuildContext, AppNotification) cardBuilder,
    }) {
      if (alerts.isEmpty) return;
      entries.add(
        (context) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                language.translate(titleKey),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
      for (final alert in alerts) {
        entries.add((context) => cardBuilder(context, alert));
      }
      entries.add((context) => const SizedBox(height: 8));
    }

    addSection(
      alerts: criticalAlerts,
      icon: TablerIcons.alert_triangle,
      color: colors.accentRed,
      titleKey: 'notifications_critical_audit',
      cardBuilder: _buildCriticalCard,
    );
    addSection(
      alerts: importantAlerts,
      icon: TablerIcons.brain,
      color: colors.accentAmber,
      titleKey: 'notifications_ai_recommendations',
      cardBuilder: _buildImportantCard,
    );
    addSection(
      alerts: infoAlerts,
      icon: TablerIcons.calendar,
      color: colors.brand,
      titleKey: 'notifications_legal_calendar',
      cardBuilder: _buildInfoCard,
    );

    if (unreadNotifications.isEmpty) {
      entries.add(
        (context) => SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  TablerIcons.circle_check,
                  color: colors.accentGreen,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  language.translate('notifications_empty'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_visibleNotifications < unreadNotifications.length) {
      entries.add((context) => const SizedBox(height: 48));
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => entries[index](context),
              childCount: entries.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalCard(BuildContext context, AppNotification alert) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: LedgerCard(
        borderColor: colors.accentRed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    language.translateMessage(alert.title),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.accentRed,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: language.translate('notifications_mark_read'),
                  onPressed: () {
                    context.read<NotificationsBloc>().add(
                      MarkNotificationAsRead(alert.id),
                    );
                  },
                  icon: Icon(
                    TablerIcons.eye,
                    color: colors.accentRed,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              language.translateMessage(alert.description),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formatLocalizedDateTime(
                    context,
                    alert.dateTime,
                    style: LocalizedDateTimeStyle.time,
                  ),
                  style: textStyles.smallMono,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportantCard(BuildContext context, AppNotification alert) {
    final colors = context.colors;
    final language = context.read<LanguageCubit>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: LedgerAICard(
        title: language.translateMessage(alert.title),
        content: language.translateMessage(alert.description),
        trailing: IconButton(
          tooltip: language.translate('notifications_mark_read'),
          onPressed: () {
            context.read<NotificationsBloc>().add(
              MarkNotificationAsRead(alert.id),
            );
          },
          icon: Icon(
            TablerIcons.circle_check,
            color: colors.accentAmber,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, AppNotification alert) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    language.translateMessage(alert.title),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: language.translate('notifications_mark_read'),
                  onPressed: () {
                    context.read<NotificationsBloc>().add(
                      MarkNotificationAsRead(alert.id),
                    );
                  },
                  icon: Icon(
                    TablerIcons.archive,
                    color: colors.textTooltip,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              language.translateMessage(alert.description),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatShortMonthDay(alert.dateTime.toLocal()),
                  style: textStyles.smallMono,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
