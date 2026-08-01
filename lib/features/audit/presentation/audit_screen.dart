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
        onPressed: () {
          context.read<AuditBloc>().add(const RunAnomalyDetectorsRequested());
        },
        backgroundColor: colors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(TablerIcons.shield_check),
        label: Text(
          locale.translate('audit_run_check'),
          style: textStyles.bodySans.copyWith(
            color: Colors.white,
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
              floating: true,
              snap: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: colors.brand,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
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
              return const Center(child: CircularProgressIndicator());
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
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final log = logs[index];
          final language = context.read<LanguageCubit>();
          return LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        language.translateMessage(log.action),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${language.translateMessage(log.userName)} • ${log.entityType}',
                  style: textStyles.captionSans.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (log.details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    language.translateMessage(log.details),
                    style: textStyles.bodySans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
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
        Color badgeBg = colors.accentGreen.withValues(alpha: 0.1);
        Color badgeColor = colors.accentGreen;

        if (alt.severity == 'high') {
          badgeBg = colors.accentRed.withValues(alpha: 0.1);
          badgeColor = colors.accentRed;
        } else if (alt.severity == 'medium') {
          badgeBg = colors.accentAmber.withValues(alpha: 0.1);
          badgeColor = colors.accentAmber;
        }

        return LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      language.translateMessage(alt.type),
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w500,
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
              const SizedBox(height: 8),
              Text(
                language.translateMessage(alt.message),
                style: textStyles.bodySans,
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
