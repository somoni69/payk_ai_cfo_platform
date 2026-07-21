import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/locale_number_format.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/localization/language_cubit.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../../features/crm/bloc/crm_bloc.dart';
import '../../features/crm/bloc/crm_event.dart';
import '../../features/crm/bloc/crm_state.dart';
import '../../features/crm/domain/crm_models.dart';
import '../../features/crm/domain/crm_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_collapsing_header.dart';

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

class _CrmViewState extends State<CrmView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshCrm(BuildContext context) {
    final completion = Completer<void>();
    context.read<CrmBloc>().add(
      LoadCrmData(forceRefresh: true, completion: completion),
    );
    return completion.future;
  }

  Widget? _buildFab(
    BuildContext context,
    LanguageCubit localeCubit,
    dynamic colors,
    dynamic textStyles,
  ) {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddClientBottomSheet(context),
        backgroundColor: colors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(TablerIcons.user_plus),
        label: Text(
          localeCubit.translate('crm_new_client'),
          style: textStyles.bodySans.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (_tabController.index == 1) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddDealBottomSheet(context),
        backgroundColor: colors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(TablerIcons.plus),
        label: Text(
          localeCubit.translate('crm_new_deal'),
          style: textStyles.bodySans.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.crm);

    return Scaffold(
      floatingActionButton:
          canManage ? _buildFab(context, localeCubit, colors, textStyles) : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: localeCubit.translate('crm_title'),
              pinned: true,
              floating: true,
              snap: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: colors.brand,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: localeCubit.translate('crm_tab_clients')),
                  Tab(text: localeCubit.translate('crm_tab_deals')),
                  Tab(text: localeCubit.translate('crm_tab_stats')),
                ],
              ),
            ),
          ];
        },
        body: BlocListener<CrmBloc, CrmState>(
        listener: (context, state) {
          if (state is CrmLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(state.errorMessage!),
                  ),
                  backgroundColor: colors.accentRed,
                ),
              );
            } else if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(state.successMessage!),
                  ),
                  backgroundColor: colors.accentGreen,
                ),
              );
            }
          }
        },
        child: BlocBuilder<CrmBloc, CrmState>(
          builder: (context, state) {
            if (state is CrmLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is CrmError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        TablerIcons.alert_circle,
                        size: 48,
                        color: colors.accentRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localeCubit.translateMessage(state.message),
                        style: textStyles.bodySans,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<CrmBloc>().add(LoadCrmData()),
                        child: Text(localeCubit.translate('crm_retry')),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is CrmLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildClientsTab(context, state),
                  _buildDealsTab(context, state),
                  _buildStatsTab(context, state),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    ),
  );
  }

  Widget _buildClientsTab(BuildContext context, CrmLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.clients.isEmpty) {
      return Center(
        child: Text(
          localeCubit.translate('crm_no_clients'),
          style: textStyles.bodySans.copyWith(color: colors.textTooltip),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshCrm(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.clients.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final client = state.clients[index];

          Color loyaltyBg = colors.border;
          Color loyaltyText = colors.textPrimary;
          if (client.loyaltyLevel == 'gold') {
            loyaltyBg = colors.accentAmber.withValues(alpha: 0.1);
            loyaltyText = colors.accentAmber;
          } else if (client.loyaltyLevel == 'silver') {
            loyaltyBg = colors.brand.withValues(alpha: 0.08);
            loyaltyText = colors.brand;
          } else if (client.loyaltyLevel == 'platinum') {
            loyaltyBg = colors.accentGreen.withValues(alpha: 0.1);
            loyaltyText = colors.accentGreen;
          }

          return LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            client.fullName,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          LedgerPill(
                            text: _loyaltyLabel(
                              localeCubit,
                              client.loyaltyLevel,
                            ),
                            backgroundColor: loyaltyBg,
                            textColor: loyaltyText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (client.phone != null)
                        Text(
                          client.phone!,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        localeCubit.translate(
                          'crm_ltv_orders',
                          params: {
                            'amount': oCcy.format(client.totalSpent),
                            'count': client.purchasesCount,
                          },
                        ),
                        style: textStyles.smallMono.copyWith(
                          color: colors.textTooltip,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (client.churnRisk)
                      LedgerPill(
                        text: localeCubit.translate('crm_churn_risk'),
                        backgroundColor: colors.accentRed.withValues(
                          alpha: 0.08,
                        ),
                        textColor: colors.accentRed,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'CAC: ${oCcy.format(client.acquisitionCost)} TJS',
                      style: textStyles.smallMono.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDealsTab(BuildContext context, CrmLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.deals.isEmpty) {
      return Center(
        child: Text(
          localeCubit.translate('crm_no_deals'),
          style: textStyles.bodySans.copyWith(color: colors.textTooltip),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshCrm(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.deals.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final deal = state.deals[index];

          Color stageBg = colors.border;
          Color stageText = colors.textPrimary;
          String stageLabel = _dealStatusLabel(localeCubit, deal.stage);

          if (deal.stage == 'won') {
            stageBg = colors.accentGreen.withValues(alpha: 0.1);
            stageText = colors.accentGreen;
            stageLabel = localeCubit.translate('crm_stage_won');
          } else if (deal.stage == 'lost') {
            stageBg = colors.accentRed.withValues(alpha: 0.1);
            stageText = colors.accentRed;
            stageLabel = localeCubit.translate('crm_stage_lost');
          } else if (deal.stage == 'negotiation') {
            stageBg = colors.accentAmber.withValues(alpha: 0.1);
            stageText = colors.accentAmber;
            stageLabel = localeCubit.translate('crm_stage_negotiation');
          }

          return LedgerCard(
            padding: const EdgeInsets.all(14),
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localeCubit.translate(
                          'crm_client_value',
                          params: {
                            'client':
                                deal.clientName ??
                                localeCubit.translate('common_unknown'),
                          },
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LedgerPill(
                      text: stageLabel,
                      backgroundColor: stageBg,
                      textColor: stageText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${oCcy.format(deal.amount)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsTab(BuildContext context, CrmLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: () => _refreshCrm(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeCubit.translate('crm_stat_total_clients'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.stats.clientsTotal}',
                        style: textStyles.h1Mono.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeCubit.translate('crm_stat_active_clients'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.stats.activeClients}',
                        style: textStyles.h1Mono.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeCubit.translate('crm_stat_total_ltv'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${oCcy.format(state.stats.ltvTotal)} TJS',
                        style: textStyles.h1Mono.copyWith(
                          color: colors.accentGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeCubit.translate('crm_stat_total_cac'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${oCcy.format(state.stats.cacTotal)} TJS',
                        style: textStyles.h1Mono.copyWith(
                          color: colors.accentRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localeCubit.translate('crm_churn_title'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localeCubit.translate('crm_churn_at_risk'),
                          style: textStyles.bodySans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          '${state.stats.churnCount}',
                          style: textStyles.h1Mono.copyWith(
                            color: colors.accentRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localeCubit.translate('crm_reactivated'),
                          style: textStyles.bodySans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          '${state.stats.reactivationCount}',
                          style: textStyles.h1Mono.copyWith(
                            color: colors.accentGreen,
                            fontWeight: FontWeight.w500,
                          ),
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

  String _loyaltyLabel(LanguageCubit language, String loyaltyLevel) {
    final key = switch (loyaltyLevel) {
      'gold' => 'crm_loyalty_gold',
      'silver' => 'crm_loyalty_silver',
      'platinum' => 'crm_loyalty_platinum',
      'bronze' => 'crm_loyalty_bronze',
      _ => null,
    };
    return key == null
        ? loyaltyLevel.toUpperCase()
        : language.translate(key).toUpperCase();
  }

  String _dealStatusLabel(LanguageCubit language, String stage) {
    final key = switch (stage) {
      'lead' => 'crm_stage_lead',
      'proposal' => 'crm_stage_proposal_status',
      'negotiation' => 'crm_stage_negotiation',
      'won' => 'crm_stage_won',
      'lost' => 'crm_stage_lost',
      _ => null,
    };
    return key == null ? stage.toUpperCase() : language.translate(key);
  }

  String _dealStageTranslationKey(String stage) {
    return switch (stage) {
      'lead' => 'crm_stage_lead_label',
      'proposal' => 'crm_stage_proposal',
      'negotiation' => 'crm_stage_negotiation_label',
      _ => 'crm_stage_won_label',
    };
  }

  Future<void> _showAddClientBottomSheet(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final textStyles = context.textStyles;
    final crmBloc = context.read<CrmBloc>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final cacController = TextEditingController(text: '0');
    final noteController = TextEditingController();

    bool isShowingDiscardDialog = false;
    bool allowPop = false;

    bool isDirty() {
      return nameController.text.trim().isNotEmpty ||
          phoneController.text.trim().isNotEmpty ||
          emailController.text.trim().isNotEmpty ||
          cacController.text.trim() != '0' ||
          noteController.text.trim().isNotEmpty;
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('crm_new_client'),
        builder: (context, setSheetState) {
          return PopScope(
            canPop: !isDirty() || allowPop,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              if (isShowingDiscardDialog) return;

              isShowingDiscardDialog = true;
              final shouldClose = await LedgerBottomSheet.confirmDiscard(
                context,
              );
              isShowingDiscardDialog = false;

              if (shouldClose == true) {
                allowPop = true;
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    labelText: language.translate('crm_full_name_company'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  style: textStyles.bodySans,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: language.translate('crm_phone'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: textStyles.bodySans,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: language.translate('crm_email'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cacController,
                  style: textStyles.bodySans,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: language.translate('crm_acquisition_cost'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    labelText: language.translate('crm_note'),
                  ),
                ),
              ],
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final cac =
                  parseLocalizedNumber(context, cacController.text) ?? 0.0;

              if (name.isEmpty) return;

              crmBloc.add(
                CreateClientRequested(
                  CrmClient(
                    id: '',
                    fullName: name,
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    loyaltyLevel: 'bronze',
                    bonusPoints: 0,
                    totalSpent: 0,
                    acquisitionCost: cac,
                    purchasesCount: 0,
                    note: noteController.text.trim(),
                    createdAt: DateTime.now(),
                    churnRisk: false,
                  ),
                ),
              );
              Navigator.pop(context);
            },
            child: Text(language.translate('common_add')),
          );
        },
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      cacController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _showAddDealBottomSheet(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final crmBloc = context.read<CrmBloc>();
    final state = crmBloc.state;
    if (state is! CrmLoaded) return;

    CrmClient? selectedClient = state.clients.isNotEmpty
        ? state.clients.first
        : null;
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String stage = 'lead';

    bool isShowingDiscardDialog = false;
    bool allowPop = false;

    bool isDirty() {
      return titleController.text.trim().isNotEmpty ||
          amountController.text.trim().isNotEmpty ||
          selectedClient !=
              (state.clients.isNotEmpty ? state.clients.first : null);
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('crm_new_deal'),
        builder: (context, setSheetState) {
          return PopScope(
            canPop: !isDirty() || allowPop,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              if (isShowingDiscardDialog) return;

              isShowingDiscardDialog = true;
              final shouldClose = await LedgerBottomSheet.confirmDiscard(
                context,
              );
              isShowingDiscardDialog = false;

              if (shouldClose == true) {
                allowPop = true;
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  language.translate('crm_client_label'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<CrmClient?>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    selectedClient?.fullName ??
                        language.translate('crm_select_client'),
                    style: textStyles.bodySans.copyWith(
                      color: selectedClient == null
                          ? colors.textTooltip
                          : colors.textPrimary,
                    ),
                  ),
                  items: state.clients,
                  selectedValue: selectedClient,
                  itemLabelBuilder: (c) =>
                      c?.fullName ?? language.translate('crm_no_client'),
                  onSelected: (c) {
                    setSheetState(() {
                      selectedClient = c;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    labelText: language.translate('crm_deal_title'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  style: textStyles.bodySans,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: language.translate('crm_deal_amount'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('crm_funnel_stage'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ExpansibleWidget<String>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    language.translate(_dealStageTranslationKey(stage)),
                    style: textStyles.bodySans,
                  ),
                  items: const ['lead', 'proposal', 'negotiation', 'won'],
                  selectedValue: stage,
                  itemLabelBuilder: (stageCode) =>
                      language.translate(_dealStageTranslationKey(stageCode)),
                  onSelected: (val) {
                    setSheetState(() {
                      stage = val;
                    });
                  },
                ),
              ],
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final amount =
                  parseLocalizedNumber(context, amountController.text) ?? 0.0;
              final cliId = selectedClient?.id;

              if (title.isEmpty || cliId == null) return;

              crmBloc.add(
                CreateDealRequested(
                  clientId: cliId,
                  title: title,
                  amount: amount,
                  stage: stage,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(language.translate('common_open')),
          );
        },
      );
    } finally {
      titleController.dispose();
      amountController.dispose();
    }
  }
}
