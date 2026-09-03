import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/ledger_layout.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/audit/bloc/audit_bloc.dart';
import '../../../features/audit/bloc/audit_event.dart';
import '../../../features/audit/bloc/audit_state.dart';
import '../../../features/audit/domain/audit_models.dart';
import '../../../features/audit/domain/audit_repository.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_fab.dart';
import '../../../presentation/widgets/ledger_segmented_control.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

enum AuditSection { logs, alerts, report }

String _auditSectionTitle(LanguageCubit language, AuditSection section) {
  return language.translate(switch (section) {
    AuditSection.logs => 'audit_tab_logs',
    AuditSection.alerts => 'audit_tab_alerts',
    AuditSection.report => 'audit_tab_report',
  });
}

void _openAuditSection(BuildContext context, AuditSection section) {
  final bloc = context.read<AuditBloc>();
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: AuditSectionScreen(section: section),
      ),
    ),
  );
}

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuditBloc>(
      create: (context) =>
          AuditBloc(context.read<AuditRepository>())
            ..add(const LoadAuditData()),
      child: const AuditView(),
    );
  }
}

class AuditView extends StatefulWidget {
  const AuditView({super.key});

  @override
  State<AuditView> createState() => _AuditViewState();
}

class _AuditViewState extends State<AuditView> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          locale.translate('audit_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: BlocConsumer<AuditBloc, AuditState>(
        listenWhen: (previous, current) =>
            current is AuditLoaded &&
            current.message != null &&
            (previous is! AuditLoaded || previous.message != current.message),
        buildWhen: (previous, current) {
          if (previous.runtimeType != current.runtimeType) return true;
          if (previous is AuditLoaded && current is AuditLoaded) {
            return previous.logs != current.logs ||
                previous.alerts != current.alerts ||
                previous.weekly != current.weekly ||
                previous.isRunningDetectors != current.isRunningDetectors;
          }
          return true;
        },
        listener: (context, state) {
          if (state is AuditLoaded && state.message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) {
          if (state is AuditLoading) {
            return const AuditOverviewShimmer();
          }
          if (state is AuditError) {
            return Center(child: Text(state.message));
          }
          if (state is AuditLoaded) {
            return _buildAuditOverviewHub(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAuditOverviewHub(BuildContext context, AuditLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    final totalLogs = state.logs.length;
    final totalAlerts = state.alerts.length;
    final highSeverityAlerts = state.alerts
        .where((a) => a.severity == 'high')
        .length;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AuditBloc>().add(const LoadAuditData(forceRefresh: true));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: Security Status & Events Count
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        locale.translate('audit_hero_title'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: totalAlerts == 0
                            ? colors.accentGreen.withValues(alpha: 0.1)
                            : colors.accentAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            totalAlerts == 0
                                ? TablerIcons.shield_check
                                : TablerIcons.alert_triangle,
                            size: 13,
                            color: totalAlerts == 0
                                ? colors.accentGreen
                                : colors.accentAmber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            totalAlerts == 0
                                ? 'Защищено'
                                : '$totalAlerts аномалий',
                            style: textStyles.captionSans.copyWith(
                              color: totalAlerts == 0
                                  ? colors.accentGreen
                                  : colors.accentAmber,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalLogs событий безопасности',
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(TablerIcons.activity, size: 16, color: colors.brand),
                    const SizedBox(width: 6),
                    Text(
                      '$totalLogs записей в журнале',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• $highSeverityAlerts крит. угроз',
                      style: textStyles.captionSans.copyWith(
                        color: highSeverityAlerts > 0
                            ? colors.accentRed
                            : colors.textSecondary,
                        fontWeight: highSeverityAlerts > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Actionable Attention Card
          InkWell(
            onTap: () => _openAuditSection(
              context,
              totalAlerts > 0 ? AuditSection.alerts : AuditSection.logs,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: totalAlerts > 0
                      ? colors.accentAmber.withValues(alpha: 0.5)
                      : colors.accentGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: totalAlerts > 0
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      totalAlerts > 0
                          ? TablerIcons.alert_triangle
                          : TablerIcons.circle_check,
                      color: totalAlerts > 0
                          ? colors.accentAmber
                          : colors.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.translate('audit_attention_title'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalAlerts > 0
                              ? locale.translate(
                                  'audit_attention_active',
                                  params: {'count': '$totalAlerts'},
                                )
                              : locale.translate('audit_attention_ok'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    TablerIcons.chevron_right,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Quick Action Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<AuditBloc>().add(
                      const RunAnomalyDetectorsRequested(),
                    );
                  },
                  icon: const Icon(TablerIcons.shield_check),
                  label: Text(
                    locale.translate('audit_action_check'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openAuditSection(context, AuditSection.logs),
                  icon: const Icon(TablerIcons.list_details),
                  label: Text(
                    locale.translate('audit_action_logs'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Main 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('audit_tab_logs'),
                  subtitle: locale.translate(
                    'audit_logs_count',
                    params: {'count': '${state.logs.length}'},
                  ),
                  icon: TablerIcons.history,
                  onTap: () => _openAuditSection(context, AuditSection.logs),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('audit_tab_alerts'),
                  subtitle: locale.translate(
                    'audit_alerts_count',
                    params: {'count': '${state.alerts.length}'},
                  ),
                  icon: TablerIcons.alert_triangle,
                  onTap: () => _openAuditSection(context, AuditSection.alerts),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('audit_tab_report'),
                  subtitle: locale.translate('audit_tab_report_hint'),
                  icon: TablerIcons.shield_check,
                  onTap: () => _openAuditSection(context, AuditSection.report),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Recent Logs Feed
          Row(
            children: [
              Expanded(
                child: Text(
                  locale.translate('audit_recent_logs'),
                  style: textStyles.h2Sans.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _openAuditSection(context, AuditSection.logs),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      locale.translate('audit_all_logs'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 14,
                      color: colors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.logs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                locale.translate('audit_logs_empty'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            ...state.logs.take(4).map((log) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.surfaceNested,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          TablerIcons.shield,
                          size: 18,
                          color: colors.brand,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    locale.translateMessage(log.action),
                                    style: textStyles.bodySans.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                                    '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: textStyles.smallMono.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${locale.translateMessage(log.userName)}${log.entityType.isNotEmpty ? ' • ${log.entityType}' : ''}',
                              style: textStyles.captionSans.copyWith(
                                color: colors.brand,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (log.details.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                locale.translateMessage(log.details),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 19, color: colors.brand),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuditSectionScreen extends StatelessWidget {
  final AuditSection section;

  const AuditSectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _auditSectionTitle(locale, section),
          style: textStyles.h2Sans.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      floatingActionButton: section == AuditSection.alerts
          ? LedgerFab(
              heroTag: null,
              onPressed: () {
                context.read<AuditBloc>().add(
                  const RunAnomalyDetectorsRequested(),
                );
              },
              icon: TablerIcons.shield_check,
              label: locale.translate('audit_run_check'),
            )
          : null,
      body: BlocBuilder<AuditBloc, AuditState>(
        buildWhen: (previous, current) {
          if (previous.runtimeType != current.runtimeType) return true;
          if (previous is AuditLoaded && current is AuditLoaded) {
            return switch (section) {
              AuditSection.logs => previous.logs != current.logs,
              AuditSection.alerts => previous.alerts != current.alerts,
              AuditSection.report =>
                previous.weekly != current.weekly ||
                    previous.weeksAgo != current.weeksAgo,
            };
          }
          return true;
        },
        builder: (context, state) {
          if (state is AuditLoading) {
            return section == AuditSection.report
                ? const AuditReportShimmer()
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: LedgerListShimmer(itemCount: 4),
                  );
          }
          if (state is! AuditLoaded) {
            return const SizedBox.shrink();
          }

          return switch (section) {
            AuditSection.logs => _buildLogsTab(context, state.logs),
            AuditSection.alerts => _buildAlertsTab(context, state.alerts),
            AuditSection.report => _buildReportTab(context, state),
          };
        },
      ),
    );
  }

  Widget _buildLogsTab(BuildContext context, List<AuditLog> logs) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (logs.isEmpty) {
      return Center(
        child: Text(
          context.read<LanguageCubit>().translate('audit_logs_empty'),
          style: textStyles.bodySans.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AuditBloc>().add(const LoadAuditData(forceRefresh: true));
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        itemCount: logs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final log = logs[index];
          final language = context.read<LanguageCubit>();
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    TablerIcons.shield,
                    size: 18,
                    color: colors.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              language.translateMessage(log.action),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
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
                              '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                              style: textStyles.smallMono.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            TablerIcons.user,
                            size: 13,
                            color: colors.textTooltip,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            language.translateMessage(log.userName),
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (log.entityType.isNotEmpty) ...[
                            Text(
                              ' • ${log.entityType}',
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (log.details.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          language.translateMessage(log.details),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertsTab(BuildContext context, List<AuditAlert> alerts) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    if (alerts.isEmpty) {
      return Center(
        child: Text(
          language.translate('mock_msg_no_anomalies'),
          style: textStyles.bodySans.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      itemCount: alerts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final alt = alerts[index];
        Color badgeBg = colors.accentGreen.withValues(alpha: 0.12);
        Color badgeColor = colors.accentGreen;

        if (alt.severity == 'high') {
          badgeBg = colors.accentRed.withValues(alpha: 0.12);
          badgeColor = colors.accentRed;
        } else if (alt.severity == 'medium') {
          badgeBg = colors.accentAmber.withValues(alpha: 0.12);
          badgeColor = colors.accentAmber;
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  alt.severity == 'high'
                      ? TablerIcons.alert_triangle
                      : TablerIcons.alert_circle,
                  size: 18,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            language.translateMessage(alt.type),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              decoration: alt.isResolved
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alt.severity.toUpperCase(),
                            style: textStyles.captionSans.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      language.translateMessage(alt.message),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          context.read<AuditBloc>().add(
                            ResolveAlertRequested(
                              alt.id,
                              isResolved: !alt.isResolved,
                            ),
                          );
                        },
                        child: Text(
                          language.translate(
                            alt.isResolved ? 'audit_reopen' : 'audit_resolve',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportTab(BuildContext context, AuditLoaded state) {
    return _AuditWeeklyReportTab(state: state);
  }
}

class _AuditWeeklyReportTab extends StatefulWidget {
  const _AuditWeeklyReportTab({required this.state});

  final AuditLoaded state;

  @override
  State<_AuditWeeklyReportTab> createState() => _AuditWeeklyReportTabState();
}

class _AuditWeeklyReportTabState extends State<_AuditWeeklyReportTab> {
  var _exporting = false;

  Future<void> _export(String format) async {
    if (_exporting) return;
    final language = context.read<LanguageCubit>();
    final repo = context.read<AuditRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final bytes = await repo.exportWeeklyReport(
        format: format,
        weeksAgo: widget.state.weeksAgo,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audit_weekly.$format');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translate('audit_report_export_ok'))),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translateMessage(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _statCard({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return LedgerCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textStyles.bodyMono.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final weekly = widget.state.weekly;
    final weeksAgo = widget.state.weeksAgo;
    const weekKeys = [
      'audit_report_week_current_short',
      'audit_report_week_last_short',
      'audit_report_week_2_short',
      'audit_report_week_3_short',
    ];

    Color severityColor(String sev) {
      return switch (sev) {
        'urgent' => colors.accentRed,
        'important' => colors.accentAmber,
        _ => colors.textSecondary,
      };
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        LedgerSegmentedControl<int>(
          height: 36,
          selectedValue: weeksAgo.clamp(0, 3),
          onValueChanged: (value) {
            if (value == weeksAgo) return;
            context.read<AuditBloc>().add(LoadWeeklyReport(weeksAgo: value));
          },
          segments: [
            for (var i = 0; i < weekKeys.length; i++)
              LedgerSegmentItem(value: i, label: locale.translate(weekKeys[i])),
          ],
        ),
        const SizedBox(height: 12),
        LedgerPairRow(
          left: OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export('xlsx'),
            icon: const Icon(TablerIcons.file_spreadsheet),
            label: Text(locale.translate('audit_report_export_excel')),
          ),
          right: OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export('pdf'),
            icon: const Icon(TablerIcons.file_type_pdf),
            label: Text(locale.translate('audit_report_export_pdf')),
          ),
        ),
        const SizedBox(height: 16),
        if (weekly == null)
          Text(
            locale.translate('audit_report_empty'),
            style: textStyles.bodySans.copyWith(color: colors.textSecondary),
          )
        else ...[
          Text(
            '${locale.translate('audit_report_period')}: ${formatLocalizedDateTime(context, weekly.periodFrom, style: LocalizedDateTimeStyle.date)} — ${formatLocalizedDateTime(context, weekly.periodTo, style: LocalizedDateTimeStyle.date)}',
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          LedgerPairRow(
            left: _statCard(
              label: locale.translate('audit_report_operations'),
              value: '${weekly.operationsCount}',
            ),
            right: _statCard(
              label: locale.translate('audit_report_income'),
              value: formatLocalizedNumber(context, weekly.incomeTotal),
              valueColor: colors.accentGreen,
            ),
          ),
          const SizedBox(height: 10),
          LedgerPairRow(
            left: _statCard(
              label: locale.translate('audit_report_expense'),
              value: formatLocalizedNumber(context, weekly.expenseTotal),
              valueColor: colors.accentRed,
            ),
            right: _statCard(
              label: locale.translate('audit_report_net'),
              value: formatLocalizedNumber(context, weekly.netTotal),
              valueColor: weekly.netTotal >= 0
                  ? colors.accentGreen
                  : colors.accentRed,
            ),
          ),
          const SizedBox(height: 16),
          LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${locale.translate('audit_report_violations')}: ${weekly.alertsCount}',
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final sev in const [
                      'urgent',
                      'important',
                      'info',
                    ]) ...[
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${weekly.alertsBySeverity[sev] ?? 0}',
                              style: textStyles.h2Sans.copyWith(
                                fontWeight: FontWeight.w700,
                                color: severityColor(sev),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locale.translate('audit_severity_$sev'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
