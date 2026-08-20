import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/integrations/bloc/integrations_bloc.dart';
import '../../../features/integrations/bloc/integrations_event.dart';
import '../../../features/integrations/bloc/integrations_state.dart';
import '../../../features/integrations/domain/integrations_repository.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    return BlocProvider<IntegrationsBloc>(
      create: (context) =>
          IntegrationsBloc(context.read<IntegrationsRepository>())
            ..add(LoadIntegrationsData()),
      child: const IntegrationsView(),
    );
  }
}

class IntegrationsView extends StatefulWidget {
  const IntegrationsView({super.key});

  @override
  State<IntegrationsView> createState() => _IntegrationsViewState();
}

class _IntegrationsViewState extends State<IntegrationsView> {
  static const _logPageSize = 50;

  final ScrollController _scrollController = ScrollController();
  int _visibleLogs = _logPageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_revealMoreLogs);
  }

  void _revealMoreLogs() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    final total = context.read<IntegrationsBloc>().state.logs.length;
    if (_visibleLogs >= total) return;
    final next = _visibleLogs + _logPageSize;
    setState(() => _visibleLogs = next < total ? next : total);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_revealMoreLogs)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocListener<IntegrationsBloc, IntegrationsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localeCubit.translateMessage(state.errorMessage!),
                ),
                backgroundColor: colors.accentRed,
              ),
            );
          }
          if (state.syncMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localeCubit.translateMessage(state.syncMessage!)),
                backgroundColor: colors.accentGreen,
              ),
            );
          }
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            LedgerCollapsingHeader(
              title: localeCubit.translate('integrations_title'),
              pinned: true,
              floating: false,
              snap: false,
            ),
          ],
          body: BlocBuilder<IntegrationsBloc, IntegrationsState>(
            buildWhen: (previous, current) =>
                previous.integrations != current.integrations ||
                previous.logs != current.logs ||
                previous.isLoading != current.isLoading ||
                previous.isSyncing != current.isSyncing,
            builder: (context, state) {
              if (state.isLoading &&
                  state.integrations.isEmpty &&
                  state.logs.isEmpty) {
                return const IntegrationsOverviewShimmer();
              }

              final visibleLogCount = _visibleLogs < state.logs.length
                  ? _visibleLogs
                  : state.logs.length;
              final logsHeaderIndex = state.integrations.length + 1;
              final logItemCount = state.logs.isEmpty ? 1 : visibleLogCount;

              return RefreshIndicator(
                onRefresh: context.read<IntegrationsBloc>().reload,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: state.integrations.length + logItemCount + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          localeCubit.translate(
                            'integrations_connected_systems',
                          ),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    if (index <= state.integrations.length) {
                      final integration = state.integrations[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: LedgerCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    integration.name,
                                    style: textStyles.bodySans.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: integration.available
                                              ? colors.accentGreen
                                              : colors.textSecondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        localeCubit.translate(
                                          integration.available
                                              ? 'integrations_status_active'
                                              : 'integrations_status_inactive',
                                        ),
                                        style: textStyles.captionSans.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (integration.canSync)
                                ElevatedButton.icon(
                                  onPressed: state.isSyncing
                                      ? null
                                      : () {
                                          context.read<IntegrationsBloc>().add(
                                            TriggerSyncRequested(
                                              integration.system,
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    TablerIcons.refresh,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    localeCubit.translate('integrations_sync'),
                                    style: textStyles.smallSans.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.brand,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (index == logsHeaderIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 10),
                        child: Text(
                          localeCubit.translate('integrations_sync_logs'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    if (state.logs.isEmpty) {
                      return Center(
                        child: Text(
                          localeCubit.translate('integrations_empty_logs'),
                        ),
                      );
                    }

                    final logIndex = index - logsHeaderIndex - 1;
                    final log = state.logs[logIndex];
                    final isSuccess = log.success;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: LedgerCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log.system.toUpperCase(),
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                LedgerPill(
                                  text: localeCubit.translate(
                                    isSuccess
                                        ? 'integrations_success'
                                        : 'integrations_error',
                                  ),
                                  backgroundColor: isSuccess
                                      ? colors.accentGreen.withValues(
                                          alpha: 0.1,
                                        )
                                      : colors.accentRed.withValues(alpha: 0.1),
                                  textColor: isSuccess
                                      ? colors.accentGreen
                                      : colors.accentRed,
                                ),
                              ],
                            ),
                            if (log.message != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                localeCubit.translateMessage(log.message!),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  localeCubit.translatePlural(
                                    'integrations_records_imported',
                                    log.records,
                                  ),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  formatLocalizedDateTime(
                                    context,
                                    log.createdAt,
                                    style: LocalizedDateTimeStyle.dayMonthTime,
                                  ),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
