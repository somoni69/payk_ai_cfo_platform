import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/crm/bloc/crm_bloc.dart';
import '../../../features/crm/bloc/crm_event.dart';
import '../../../features/crm/bloc/crm_state.dart';
import '../../../features/crm/domain/crm_models.dart';
import '../../../features/crm/domain/crm_repository.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import 'crm_funnel.dart';
import 'crm_labels.dart';
import 'crm_sheets.dart';

enum CrmSection { clients, funnel, loyalty, reactivation, churn, birthdays }

String _crmSectionTitle(LanguageCubit language, CrmSection section) {
  return language.translate(switch (section) {
    CrmSection.clients => 'crm_tab_clients',
    CrmSection.funnel => 'crm_tab_funnel',
    CrmSection.loyalty => 'crm_tab_loyalty',
    CrmSection.reactivation => 'crm_tab_reactivation',
    CrmSection.churn => 'crm_tab_churn',
    CrmSection.birthdays => 'crm_tab_birthdays',
  });
}

void _openCrmSection(BuildContext context, CrmSection section) {
  final bloc = context.read<CrmBloc>();
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: CrmSectionScreen(section: section),
      ),
    ),
  );
}

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmBloc>(
      create: (context) =>
          CrmBloc(context.read<CrmRepository>())..add(const LoadCrmData()),
      child: const CrmView(),
    );
  }
}

class CrmView extends StatefulWidget {
  const CrmView({super.key});

  @override
  State<CrmView> createState() => _CrmViewState();
}

class _CrmViewState extends State<CrmView> {
  Future<void> _refresh(BuildContext context) {
    final done = Completer<void>();
    context.read<CrmBloc>().add(
      LoadCrmData(forceRefresh: true, completion: done),
    );
    return done.future;
  }

  UserRole? _role(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.role : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final role = _role(context);
    final canWrite = role?.canWrite(AppCapability.crm) ?? false;
    final canDelete = role?.canDelete(AppCapability.crm) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          language.translate('crm_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: BlocListener<CrmBloc, CrmState>(
        listenWhen: (p, c) {
          if (c is! CrmLoaded) return false;
          return c.errorMessage != null || c.successMessage != null;
        },
        listener: (context, state) {
          if (state is! CrmLoaded) return;
          final msg = state.errorMessage ?? state.successMessage;
          if (msg == null) return;
          final isError = state.errorMessage != null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(language.resolveMessage(msg)),
              backgroundColor: isError ? colors.accentRed : colors.accentGreen,
            ),
          );
          context.read<CrmBloc>().add(const ClearCrmFeedback());
        },
        child: BlocBuilder<CrmBloc, CrmState>(
          builder: (context, state) {
            if (state is CrmLoading) {
              return const _CrmSkeleton();
            }
            if (state is CrmError) {
              return _ErrorBody(
                message: language.resolveMessage(state.message),
                onRetry: () => context.read<CrmBloc>().add(const LoadCrmData()),
              );
            }
            if (state is! CrmLoaded) return const SizedBox.shrink();

            return _buildCrmOverviewHub(
              context,
              state,
              canWrite: canWrite,
              canDelete: canDelete,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCrmOverviewHub(
    BuildContext context,
    CrmLoaded state, {
    required bool canWrite,
    required bool canDelete,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final recentDeals = state.deals.take(5).toList();
    final hasRisk =
        state.stats.churnCount > 0 ||
        state.stats.reactivationCount > 0 ||
        state.birthdays.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: LTV & Base
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.translate('crm_hero_clients'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${oCcy.format(state.stats.ltvTotal)} TJS',
                    style: textStyles.h1Sans.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(TablerIcons.users, size: 16, color: colors.brand),
                      const SizedBox(width: 6),
                      Text(
                        '${state.stats.clientsTotal} клиентов (${state.stats.activeClients} активных)',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        TablerIcons.trending_up,
                        size: 16,
                        color: colors.accentGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CAC: ${oCcy.format(state.stats.cacTotal)} TJS',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Attention & Risks
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _openCrmSection(
                  context,
                  state.stats.churnCount > 0
                      ? CrmSection.churn
                      : CrmSection.reactivation,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasRisk ? colors.accentAmber : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasRisk
                            ? TablerIcons.alert_triangle
                            : TablerIcons.circle_check,
                        color: hasRisk
                            ? colors.accentAmber
                            : colors.accentGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              language.translate('crm_attention_title'),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasRisk
                                  ? language.translate(
                                      'crm_attention_risk',
                                      params: {
                                        'churn': state.stats.churnCount,
                                        'reactivation':
                                            state.stats.reactivationCount,
                                      },
                                    )
                                  : language.translate('crm_attention_ok'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        TablerIcons.chevron_right,
                        size: 18,
                        color: colors.textTooltip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Quick Action Buttons (if canWrite)
            if (canWrite) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: () => showCrmClientForm(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(TablerIcons.user_plus, size: 16),
                        label: Text(
                          language.translate('crm_new_client'),
                          style: textStyles.captionSans.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: () => showCrmDealForm(
                          context,
                          clients: state.pickClients.isNotEmpty
                              ? state.pickClients
                              : state.clients,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(TablerIcons.plus, size: 16),
                        label: Text(
                          language.translate('crm_new_deal'),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 4. Section Grid Hub (2x2)
            Row(
              children: [
                Expanded(
                  child: _buildCrmHubTile(
                    context,
                    icon: TablerIcons.users,
                    title: language.translate('crm_tab_clients'),
                    subtitle: '${state.stats.clientsTotal} контактов',
                    onTap: () => _openCrmSection(context, CrmSection.clients),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCrmHubTile(
                    context,
                    icon: TablerIcons.layout_kanban,
                    title: language.translate('crm_tab_funnel'),
                    subtitle: '${state.deals.length} сделок',
                    onTap: () => _openCrmSection(context, CrmSection.funnel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCrmHubTile(
                    context,
                    icon: TablerIcons.gift,
                    title: language.translate('crm_tab_loyalty'),
                    subtitle: 'Кэшбэк и RFM',
                    onTap: () => _openCrmSection(context, CrmSection.loyalty),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCrmHubTile(
                    context,
                    icon: TablerIcons.user_x,
                    title: language.translate('crm_tab_churn'),
                    subtitle: '${state.stats.churnCount} в зоне риска',
                    onTap: () => _openCrmSection(context, CrmSection.churn),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 5. Secondary Quick Links Row
            Row(
              children: [
                Expanded(
                  child: _buildCrmHubTile(
                    context,
                    icon: TablerIcons.refresh,
                    title: language.translate('crm_tab_reactivation'),
                    subtitle: '${state.stats.reactivationCount} клиентов',
                    onTap: () =>
                        _openCrmSection(context, CrmSection.reactivation),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCrmHubTile(
                    context,
                    icon: TablerIcons.cake,
                    title: language.translate('crm_tab_birthdays'),
                    subtitle: '${state.birthdays.length} в этом месяце',
                    onTap: () => _openCrmSection(context, CrmSection.birthdays),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 6. Recent Deals Feed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.translate('crm_recent_deals'),
                  style: textStyles.h2Sans.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => _openCrmSection(context, CrmSection.funnel),
                  child: Text(
                    language.translate('crm_all_deals'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recentDeals.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  language.translate('crm_no_deals'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...recentDeals.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRecentDealCard(context, d, oCcy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildCrmHubTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
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

Widget _buildRecentDealCard(BuildContext context, CrmDeal deal, dynamic oCcy) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.read<LanguageCubit>();
  final sc = crmStageColors(colors, deal.stage);

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.border),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deal.title,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (deal.clientName != null) ...[
                const SizedBox(height: 2),
                Text(
                  deal.clientName!,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${oCcy.format(deal.amount)} TJS',
              style: textStyles.bodyMono.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: sc.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                crmStagePill(language, deal.stage),
                style: textStyles.captionSans.copyWith(
                  color: sc.fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class CrmSectionScreen extends StatefulWidget {
  final CrmSection section;

  const CrmSectionScreen({super.key, required this.section});

  @override
  State<CrmSectionScreen> createState() => _CrmSectionScreenState();
}

class _CrmSectionScreenState extends State<CrmSectionScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) {
    final done = Completer<void>();
    context.read<CrmBloc>().add(
      LoadCrmData(forceRefresh: true, completion: done),
    );
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final auth = context.watch<AuthBloc>().state;
    final role = auth is AuthAuthenticated ? auth.role : null;
    final canWrite = role?.canWrite(AppCapability.crm) ?? false;
    final canDelete = role?.canDelete(AppCapability.crm) ?? false;

    return BlocBuilder<CrmBloc, CrmState>(
      builder: (context, state) {
        final loadedState = state is CrmLoaded ? state : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _crmSectionTitle(language, widget.section),
              style: textStyles.h2Sans.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            leading: const BackButton(),
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          floatingActionButton: canWrite && loadedState != null
              ? switch (widget.section) {
                  CrmSection.clients => FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () => showCrmClientForm(context),
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    highlightElevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    icon: const Icon(TablerIcons.user_plus, size: 18),
                    label: Text(
                      language.translate('crm_new_client'),
                      style: textStyles.bodySans.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  CrmSection.funnel => FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () => showCrmDealForm(
                      context,
                      clients: loadedState.pickClients.isNotEmpty
                          ? loadedState.pickClients
                          : loadedState.clients,
                    ),
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    highlightElevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    icon: const Icon(TablerIcons.plus, size: 18),
                    label: Text(
                      language.translate('crm_new_deal'),
                      style: textStyles.bodySans.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _ => null,
                }
              : null,
          body: loadedState != null
              ? switch (widget.section) {
                  CrmSection.clients => _ClientsTab(
                    state: loadedState,
                    canWrite: canWrite,
                    canDelete: canDelete,
                    searchCtrl: _searchCtrl,
                    onSearch: (q) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () {
                          context.read<CrmBloc>().add(
                            ClientFiltersChanged(query: q),
                          );
                        },
                      );
                    },
                    onRefresh: () => _refresh(context),
                  ),
                  CrmSection.funnel => CrmFunnelBoard(
                    state: loadedState,
                    canWrite: canWrite,
                    canDelete: canDelete,
                    onRefresh: () => _refresh(context),
                  ),
                  CrmSection.loyalty => _LoyaltyTab(
                    state: loadedState,
                    canWrite: canWrite,
                    onRefresh: () => _refresh(context),
                  ),
                  CrmSection.reactivation => _ReactivationTab(
                    state: loadedState,
                    canWrite: canWrite,
                    onRefresh: () => _refresh(context),
                  ),
                  CrmSection.churn => _ChurnTab(
                    state: loadedState,
                    canWrite: canWrite,
                    onRefresh: () => _refresh(context),
                  ),
                  CrmSection.birthdays => _BirthdaysTab(
                    state: loadedState,
                    onRefresh: () => _refresh(context),
                  ),
                }
              : const _CrmSkeleton(),
        );
      },
    );
  }
}

class _CrmSkeleton extends StatelessWidget {
  const _CrmSkeleton();

  @override
  Widget build(BuildContext context) {
    return const CrmOverviewShimmer();
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final CrmStatsData stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    Widget cell(String label, String value, {String? hint, Color? accent}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textStyles.smallSans.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textStyles.bodyMono.copyWith(
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: textStyles.smallSans.copyWith(
                    color: colors.textTooltip,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Web StatsBar: clients, LTV(+ROI), reactivation, churn.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              cell(
                language.translate('crm_stat_total_clients'),
                '${stats.clientsTotal}',
                hint: language.translate(
                  'crm_stat_active_hint',
                  params: {'n': stats.activeClients},
                ),
              ),
              const SizedBox(width: 8),
              cell(
                language.translate('crm_stat_total_ltv'),
                oCcy.format(stats.ltvTotal),
                hint: stats.roi == null
                    ? '${language.translate('crm_stat_total_cac')}: ${oCcy.format(stats.cacTotal)}'
                    : '${language.translate('crm_stats_bar_roi')}: ${oCcy.format(stats.roi!)}',
                accent: colors.accentGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell(
                language.translate('crm_stat_reactivation'),
                '${stats.reactivationCount}',
                hint: language.translate('crm_stat_reactivation_hint'),
                accent: colors.brand,
              ),
              const SizedBox(width: 8),
              cell(
                language.translate('crm_stat_churn'),
                '${stats.churnCount}',
                hint: language.translate('crm_stat_churn_hint'),
                accent: colors.accentRed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab({
    required this.state,
    required this.canWrite,
    required this.canDelete,
    required this.searchCtrl,
    required this.onSearch,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final bool canDelete;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final pages = state.clientsSize <= 0
        ? 1
        : ((state.clientsTotal + state.clientsSize - 1) ~/ state.clientsSize)
              .clamp(1, 9999);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 88),
        children: [
          _StatsBar(stats: state.stats),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchCtrl,
              style: textStyles.bodySans,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: language.translate('crm_search_placeholder'),
                prefixIcon: const Icon(TablerIcons.search, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                final options = crmLoyaltyOptions(language);
                final selectedValue = state.clientFilters.level ?? '';
                final selected = options.firstWhere(
                  (o) => o.value == selectedValue,
                  orElse: () => options.first,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      language.translate('crm_filter_all_levels'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ExpansibleWidget<({String value, String label})>.selection(
                      key: ValueKey('crm-level-$selectedValue'),
                      title: Text(
                        selected.label,
                        style: textStyles.bodySans.copyWith(
                          color: selectedValue.isEmpty
                              ? colors.textTooltip
                              : colors.textPrimary,
                        ),
                      ),
                      items: options,
                      selectedValue: selected,
                      itemLabelBuilder: (o) => o.label,
                      onSelected: (o) {
                        context.read<CrmBloc>().add(
                          ClientFiltersChanged(level: o.value),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (state.clients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        language.translate('crm_no_clients'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textTooltip,
                        ),
                      ),
                    ),
                  )
                else
                  ...state.clients.map((client) {
                    final lc = crmLoyaltyColors(colors, client.loyaltyLevel);
                    final initial = client.fullName.isNotEmpty
                        ? client.fullName[0].toUpperCase()
                        : '?';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => showCrmClientDetail(context, client),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // User avatar
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: colors.surfaceNested,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        initial,
                                        style: textStyles.bodySans.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.brand,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.fullName,
                                            style: textStyles.bodySans.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (client.phone != null ||
                                              client.email != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              client.phone ?? client.email!,
                                              style: textStyles.captionSans
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: lc.bg,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            crmLoyaltyLabel(
                                              language,
                                              client.loyaltyLevel,
                                            ),
                                            style: textStyles.captionSans
                                                .copyWith(
                                                  color: lc.fg,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11.5,
                                                ),
                                          ),
                                        ),
                                        if (client.churnRisk) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.accentRed
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              language.translate(
                                                'crm_churn_risk',
                                              ),
                                              style: textStyles.captionSans
                                                  .copyWith(
                                                    color: colors.accentRed,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11.5,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceNested,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'LTV ${oCcy.format(client.totalSpent)} TJS',
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.accentGreen,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${language.translate('crm_bonus_points')}: ${oCcy.format(client.bonusPoints)}',
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12.5,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          client.roi == null
                                              ? 'ROI —'
                                              : 'ROI ${oCcy.format(client.roi!)}×',
                                          style: textStyles.captionSans
                                              .copyWith(
                                                color: colors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12.5,
                                              ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${language.translate('crm_last_purchase')}: ${client.lastPurchaseAt == null ? '—' : formatLocalizedDateTime(context, client.lastPurchaseAt!, style: LocalizedDateTimeStyle.date)}',
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textTooltip,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                if (pages > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: state.clientsPage <= 1
                            ? null
                            : () => context.read<CrmBloc>().add(
                                ClientFiltersChanged(
                                  page: state.clientsPage - 1,
                                ),
                              ),
                        child: Text(language.translate('crm_prev_page')),
                      ),
                      Text(
                        '${state.clientsPage} / $pages',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: state.clientsPage >= pages
                            ? null
                            : () => context.read<CrmBloc>().add(
                                ClientFiltersChanged(
                                  page: state.clientsPage + 1,
                                ),
                              ),
                        child: Text(language.translate('crm_next_page')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyTab extends StatelessWidget {
  const _LoyaltyTab({
    required this.state,
    required this.canWrite,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final Future<void> Function() onRefresh;

  String _clientName(String id) {
    for (final c in state.pickClients) {
      if (c.id == id) return c.fullName;
    }
    for (final c in state.clients) {
      if (c.id == id) return c.fullName;
    }
    return '#$id';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final pick = state.pickClients.isNotEmpty
        ? state.pickClients
        : state.clients;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            language.translate('crm_loyalty_summary'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (state.loyaltySummary.isEmpty)
            Text(
              language.translate('crm_no_loyalty'),
              style: textStyles.bodySans.copyWith(color: colors.textTooltip),
            )
          else
            ...state.loyaltySummary.map((row) {
              final lc = crmLoyaltyColors(colors, row.level);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: lc.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          crmLoyaltyLabel(language, row.level),
                          style: textStyles.captionSans.copyWith(
                            color: lc.fg,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        language.translate(
                          'crm_loyalty_clients_count',
                          params: {'count': row.clients},
                        ),
                        style: textStyles.captionSans.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.translate(
                          'crm_loyalty_spent',
                          params: {'amount': oCcy.format(row.totalSpent)},
                        ),
                        style: textStyles.bodyMono.copyWith(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.translate(
                          'crm_loyalty_bonus_total',
                          params: {'amount': oCcy.format(row.bonusPoints)},
                        ),
                        style: textStyles.bodyMono.copyWith(
                          fontSize: 13,
                          color: colors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(
            language.translate('crm_loyalty_history_title'),
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final options = <({String value, String label})>[
                (
                  value: '',
                  label: language.translate('crm_loyalty_all_clients'),
                ),
                ...pick.map((c) => (value: c.id, label: c.fullName)),
              ];
              final selectedId = state.loyaltyFilterClientId ?? '';
              final selected = options.firstWhere(
                (o) => o.value == selectedId,
                orElse: () => options.first,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    language.translate('crm_loyalty_filter_client'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExpansibleWidget<({String value, String label})>.selection(
                    key: ValueKey('crm-loyalty-filter-$selectedId'),
                    title: Text(
                      selected.label,
                      style: textStyles.bodySans.copyWith(
                        color: selectedId.isEmpty
                            ? colors.textTooltip
                            : colors.textPrimary,
                      ),
                    ),
                    items: options,
                    selectedValue: selected,
                    itemLabelBuilder: (o) => o.label,
                    onSelected: (o) {
                      context.read<CrmBloc>().add(
                        LoyaltyHistoryFilterChanged(
                          o.value.isEmpty ? null : o.value,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          if (canWrite && pick.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => showCrmBonusSheet(context, clients: pick),
              icon: const Icon(TablerIcons.gift, size: 18),
              label: Text(language.translate('crm_add_bonus')),
            ),
          ],
          const SizedBox(height: 12),
          if (state.loyaltyTxnsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            )
          else if (state.loyaltyTxns.isEmpty)
            Text(
              language.translate('crm_no_history'),
              style: textStyles.captionSans.copyWith(color: colors.textTooltip),
            )
          else
            ...state.loyaltyTxns.map((t) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _clientName(t.clientId),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                            Text(
                              t.reason?.isNotEmpty == true
                                  ? t.reason!
                                  : formatLocalizedDateTime(
                                      context,
                                      t.createdAt,
                                      style: LocalizedDateTimeStyle.dateTime,
                                    ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        oCcy.format(t.points),
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: t.points >= 0
                              ? colors.accentGreen
                              : colors.accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (state.loyaltyTxnPage * 30 < state.loyaltyTxnTotal) ...[
            const SizedBox(height: 8),
            if (state.loyaltyTxnsLoadingMore)
              const Center(child: CircularProgressIndicator())
            else
              OutlinedButton(
                onPressed: () =>
                    context.read<CrmBloc>().add(const LoadMoreLoyaltyTxns()),
                child: Text(language.translate('crm_loyalty_load_more')),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReactivationTab extends StatelessWidget {
  const _ReactivationTab({
    required this.state,
    required this.canWrite,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: state.reactivation.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      language.translate('crm_no_reactivation'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textTooltip,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.reactivation.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = state.reactivation[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (c.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          c.phone!,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'LTV ${oCcy.format(c.totalSpent)} TJS',
                        style: textStyles.bodyMono.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.brand,
                        ),
                      ),
                      if (canWrite) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => showCrmSmsSheet(context, c),
                          icon: const Icon(TablerIcons.mail, size: 16),
                          label: Text(
                            language.translate('crm_send_sms'),
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
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
}

class _ChurnTab extends StatelessWidget {
  const _ChurnTab({
    required this.state,
    required this.canWrite,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.churnAdvice != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accentAmber),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.translate('crm_ai_advice'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.accentAmber,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.churnAdvice!.advice,
                    style: textStyles.bodySans.copyWith(fontSize: 13.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.churnAnalyzing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (state.churn.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  language.translate('crm_no_churn'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            )
          else
            ...state.churn.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                        children: [
                          Expanded(
                            child: Text(
                              c.fullName,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              language.translate('crm_churn_risk'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.accentRed,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LTV ${oCcy.format(c.totalSpent)} TJS',
                        style: textStyles.bodyMono.copyWith(
                          fontSize: 13,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (canWrite) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.read<CrmBloc>().add(
                            AnalyzeChurnRequested(c.id),
                          ),
                          icon: const Icon(TablerIcons.brain, size: 16),
                          label: Text(
                            language.translate('crm_ai_analyze'),
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _BirthdaysTab extends StatelessWidget {
  const _BirthdaysTab({required this.state, required this.onRefresh});

  final CrmLoaded state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: state.birthdays.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      language.translate('crm_no_birthdays'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textTooltip,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.birthdays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = state.birthdays[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.brand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          TablerIcons.cake,
                          color: colors.brand,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.fullName,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              language.translate(
                                'crm_birthday_in_days',
                                params: {'days': b.daysUntil},
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            if (b.turning != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                language.translate(
                                  'crm_turning',
                                  params: {'age': b.turning},
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.brand,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (b.phone != null)
                        Text(
                          b.phone!,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.alert_circle, size: 48, color: colors.accentRed),
            const SizedBox(height: 16),
            Text(
              message,
              style: textStyles.bodySans,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(language.translate('crm_retry')),
            ),
          ],
        ),
      ),
    );
  }
}
