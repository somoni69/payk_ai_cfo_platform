import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/audit/bloc/audit_bloc.dart';
import '../../../features/audit/bloc/audit_event.dart';
import '../../../features/audit/bloc/audit_state.dart';
import '../../../features/audit/domain/audit_models.dart';
import '../../../features/audit/domain/audit_repository.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

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

class _AuditViewState extends State<AuditView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () {
          context.read<AuditBloc>().add(const RunAnomalyDetectorsRequested());
        },
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.brand),
        ),
        icon: const Icon(TablerIcons.shield_check),
        label: Text(
          locale.translate('audit_run_check'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: locale.translate('audit_title'),
              pinned: true,
              floating: false,
              snap: false,
              bottom: LedgerTabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: locale.translate('audit_tab_logs')),
                  Tab(text: locale.translate('audit_tab_alerts')),
                  Tab(text: locale.translate('audit_tab_report')),
                ],
              ),
            ),
          ];
        },
        body: BlocConsumer<AuditBloc, AuditState>(
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
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildLogsTab(context, state.logs),
                  _buildAlertsTab(context, state.alerts),
                  _buildReportTab(context, state),
                ],
              );
            }
            return const SizedBox();
          },
        ),
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
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final log = logs[index];
          final language = context.read<LanguageCubit>();
          return LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.08),
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
                          LedgerPill(
                            text:
                                '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                            backgroundColor: colors.surfaceNested,
                            textColor: colors.textSecondary,
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
      padding: const EdgeInsets.all(16),
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

        return LedgerCard(
          padding: const EdgeInsets.all(14),
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
                            ),
                          ),
                        ),
                        LedgerPill(
                          text: alt.severity.toUpperCase(),
                          backgroundColor: badgeBg,
                          textColor: badgeColor,
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
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LedgerCard(
            child: Column(
              children: [
                Icon(
                  TablerIcons.shield_check_filled,
                  size: 48,
                  color: colors.accentGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  context.read<LanguageCubit>().translate(
                    'audit_security_status',
                  ),
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.read<LanguageCubit>().translate(
                    'audit_security_desc',
                  ),
                  textAlign: TextAlign.center,
                  style: textStyles.bodySans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${state.logs.length}',
                          style: textStyles.h1Sans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          context.read<LanguageCubit>().translate(
                            'audit_total_events',
                          ),
                          style: textStyles.captionSans,
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${state.alerts.length}',
                          style: textStyles.h1Sans.copyWith(
                            color: colors.accentAmber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          context.read<LanguageCubit>().translate(
                            'audit_anomalies',
                          ),
                          style: textStyles.captionSans,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
