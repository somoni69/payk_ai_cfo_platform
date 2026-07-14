import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
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
      create: (context) => NotificationsBloc(context.read<NotificationsRepository>())..add(LoadNotifications()),
      child: const NotificationsView(),
    );
  }
}

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        if (state is NotificationsLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              title: Text('Инфо и предупреждения', style: textStyles.h1Sans),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
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
                    Icon(TablerIcons.alert_triangle, color: colors.accentRed, size: 40),
                    const SizedBox(height: 12),
                    Text(state.message, style: textStyles.bodySans, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<NotificationsBloc>().add(LoadNotifications());
                      },
                      child: const Text('Повторить попытку'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is NotificationsLoaded) {
          final unreadNotifications = state.notifications.where((n) => !n.isRead).toList();

          final criticalAlerts = unreadNotifications.where((n) => n.severity == NotificationSeverity.critical).toList();
          final importantAlerts = unreadNotifications.where((n) => n.severity == NotificationSeverity.important).toList();
          final infoAlerts = unreadNotifications.where((n) => n.severity == NotificationSeverity.info).toList();

          return Scaffold(
            appBar: AppBar(
              backgroundColor: colors.surface,
              scrolledUnderElevation: 0,
              title: Text('Инфо и предупреждения', style: textStyles.h1Sans),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: colors.border,
                  height: 1.0,
                ),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<NotificationsBloc>().add(LoadNotifications());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Раздел 1: Срочные нарушения (AUD-06)
                      if (criticalAlerts.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(TablerIcons.alert_triangle, color: colors.accentRed, size: 18),
                            const SizedBox(width: 8),
                            Text('КРИТИЧЕСКИЙ АУДИТ (СРОЧНО)', style: textStyles.smallSans.copyWith(color: colors.accentRed)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...criticalAlerts.map((alert) => _buildCriticalCard(context, alert)),
                        const SizedBox(height: 20),
                      ],

                      // Раздел 2: ИИ-Советы и прогнозы (MOB-04)
                      if (importantAlerts.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(TablerIcons.brain, color: colors.accentAmber, size: 18),
                            const SizedBox(width: 8),
                            Text('AI РЕКОМЕНДАЦИИ И ПРОГНОЗЫ (ВАЖНО)', style: textStyles.smallSans.copyWith(color: colors.accentAmber)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...importantAlerts.map((alert) => _buildImportantCard(context, alert)),
                        const SizedBox(height: 20),
                      ],

                      // Раздел 3: Налоговый календарь и документы (LEG-05 / LEG-04)
                      if (infoAlerts.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(TablerIcons.calendar, color: colors.brand, size: 18),
                            const SizedBox(width: 8),
                            Text('НАЛОГОВЫЙ И ЮР. КАЛЕНДАРЬ (К СВЕДЕНИЮ)', style: textStyles.smallSans.copyWith(color: colors.brand)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...infoAlerts.map((alert) => _buildInfoCard(context, alert)),
                        const SizedBox(height: 20),
                      ],

                      if (unreadNotifications.isEmpty)
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(TablerIcons.circle_check, color: colors.accentGreen, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  'Нарушений и нерассмотренных AI-советов нет',
                                  style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCriticalCard(BuildContext context, AppNotification alert) {
    final colors = context.colors;
    final textStyles = context.textStyles;

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
                    alert.title,
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.accentRed,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    context.read<NotificationsBloc>().add(MarkNotificationAsRead(alert.id));
                  },
                  child: Icon(TablerIcons.eye, color: colors.accentRed, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.description,
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormat('HH:mm').format(alert.dateTime),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: LedgerAICard(
        title: alert.title,
        content: alert.description,
        trailing: GestureDetector(
          onTap: () {
            context.read<NotificationsBloc>().add(MarkNotificationAsRead(alert.id));
          },
          child: Icon(TablerIcons.circle_check, color: colors.accentAmber, size: 18),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, AppNotification alert) {
    final colors = context.colors;
    final textStyles = context.textStyles;

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
                    alert.title,
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    context.read<NotificationsBloc>().add(MarkNotificationAsRead(alert.id));
                  },
                  child: Icon(TablerIcons.archive, color: colors.textTooltip, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.description,
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormat('dd MMM').format(alert.dateTime),
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
