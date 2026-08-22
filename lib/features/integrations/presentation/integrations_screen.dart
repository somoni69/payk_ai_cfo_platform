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
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          localeCubit.translate('integrations_title'),
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
        child: BlocBuilder<IntegrationsBloc, IntegrationsState>(
          buildWhen: (previous, current) =>
              previous.integrations != current.integrations ||
              previous.logs != current.logs ||
              previous.isLoading != current.isLoading ||
              previous.isSyncing != current.isSyncing,
          builder: (context, state) {
            if (state.isLoading &&
                state.integrations.isEmpty &&
                state.logs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LedgerListShimmer(itemCount: 4),
              );
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
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        localeCubit.translate('integrations_connected_systems'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                    );
                  }

                  if (index <= state.integrations.length) {
                    final integration = state.integrations[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  integration.name,
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
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
                                        fontSize: 12.5,
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
                                  size: 15,
                                ),
                                label: Text(
                                  localeCubit.translate('integrations_sync'),
                                  style: textStyles.smallSans.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.brand,
                                  foregroundColor: colors.surface,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
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
                      padding: const EdgeInsets.only(top: 16, bottom: 12),
                      child: Text(
                        localeCubit.translate('integrations_sync_logs'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                    );
                  }

                  if (state.logs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        localeCubit.translate('integrations_empty_logs'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    );
                  }

                  final logIndex = index - logsHeaderIndex - 1;
                  final log = state.logs[logIndex];
                  final isSuccess = log.success;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
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
                              Text(
                                log.system.toUpperCase(),
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSuccess
                                      ? colors.accentGreen
                                          .withValues(alpha: 0.12)
                                      : colors.accentRed
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  localeCubit.translate(
                                    isSuccess
                                        ? 'integrations_success'
                                        : 'integrations_error',
                                  ),
                                  style: textStyles.captionSans.copyWith(
                                    color: isSuccess
                                        ? colors.accentGreen
                                        : colors.accentRed,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (log.message != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              localeCubit.translateMessage(log.message!),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
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
                                  fontSize: 12,
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
                                  fontSize: 12,
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
    );
  }
}
