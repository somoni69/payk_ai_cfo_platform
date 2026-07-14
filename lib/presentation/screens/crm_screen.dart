import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/localization/language_cubit.dart';
import '../../features/crm/bloc/crm_bloc.dart';
import '../../features/crm/bloc/crm_event.dart';
import '../../features/crm/bloc/crm_state.dart';
import '../../features/crm/domain/crm_models.dart';
import '../../features/crm/domain/crm_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmBloc>(
      create: (context) => CrmBloc(context.read<CrmRepository>())..add(LoadCrmData()),
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
    final localeCubit = context.read<LanguageCubit>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          localeCubit.translate('crm_title'),
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(TablerIcons.user_plus),
            color: colors.brand,
            onPressed: () => _showAddClientDialog(context),
          ),
          IconButton(
            icon: const Icon(TablerIcons.plus),
            color: colors.brand,
            onPressed: () => _showAddDealDialog(context),
          ),
        ],
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
      body: BlocListener<CrmBloc, CrmState>(
        listener: (context, state) {
          if (state is CrmLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: colors.accentRed,
                ),
              );
            } else if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
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
                      Icon(TablerIcons.alert_circle, size: 48, color: colors.accentRed),
                      const SizedBox(height: 16),
                      Text(state.message, style: textStyles.bodySans, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<CrmBloc>().add(LoadCrmData()),
                        child: const Text('Повторить попытку'),
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
    );
  }

  Widget _buildClientsTab(BuildContext context, CrmLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    if (state.clients.isEmpty) {
      return Center(
        child: Text(
          localeCubit.translate('crm_no_clients'),
          style: textStyles.bodySans.copyWith(color: colors.textTooltip),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CrmBloc>().add(LoadCrmData());
      },
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
                            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          LedgerPill(
                            text: client.loyaltyLevel.toUpperCase(),
                            backgroundColor: loyaltyBg,
                            textColor: loyaltyText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (client.phone != null)
                        Text(
                          client.phone!,
                          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'LTV: ${oCcy.format(client.totalSpent)} TJS (заказы: ${client.purchasesCount})',
                        style: textStyles.smallMono.copyWith(color: colors.textTooltip),
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
                        backgroundColor: colors.accentRed.withValues(alpha: 0.08),
                        textColor: colors.accentRed,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'CAC: ${oCcy.format(client.acquisitionCost)} TJS',
                      style: textStyles.smallMono.copyWith(color: colors.textSecondary),
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
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    if (state.deals.isEmpty) {
      return Center(
        child: Text(
          localeCubit.translate('crm_no_deals'),
          style: textStyles.bodySans.copyWith(color: colors.textTooltip),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CrmBloc>().add(LoadCrmData());
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.deals.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final deal = state.deals[index];

          Color stageBg = colors.border;
          Color stageText = colors.textPrimary;
          String stageLabel = deal.stage.toUpperCase();

          if (deal.stage == 'won') {
            stageBg = colors.accentGreen.withValues(alpha: 0.1);
            stageText = colors.accentGreen;
            stageLabel = 'УСПЕШНО';
          } else if (deal.stage == 'lost') {
            stageBg = colors.accentRed.withValues(alpha: 0.1);
            stageText = colors.accentRed;
            stageLabel = 'ПРОИГРАНО';
          } else if (deal.stage == 'negotiation') {
            stageBg = colors.accentAmber.withValues(alpha: 0.1);
            stageText = colors.accentAmber;
            stageLabel = 'ПЕРЕГОВОРЫ';
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
                        style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${localeCubit.translate('crm_client')}: ${deal.clientName ?? "Неизвестный"}',
                        style: textStyles.captionSans.copyWith(color: colors.textSecondary),
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
                      style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.w500),
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
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CrmBloc>().add(LoadCrmData());
      },
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
                        style: textStyles.smallSans.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.stats.clientsTotal}',
                        style: textStyles.h1Mono.copyWith(fontWeight: FontWeight.w500),
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
                        style: textStyles.smallSans.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.stats.activeClients}',
                        style: textStyles.h1Mono.copyWith(fontWeight: FontWeight.w500),
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
                        style: textStyles.smallSans.copyWith(color: colors.textSecondary),
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
                        style: textStyles.smallSans.copyWith(color: colors.textSecondary),
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
                  'ОТТОК КЛИЕНТОВ (CHURN)',
                  style: textStyles.captionSans.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Клиентов под риском оттока', style: textStyles.smallSans.copyWith(color: colors.textTooltip)),
                        const SizedBox(height: 2),
                        Text(
                          '${state.stats.churnCount}',
                          style: textStyles.h1Mono.copyWith(color: colors.accentRed, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Реактивировано клиентов', style: textStyles.smallSans.copyWith(color: colors.textTooltip)),
                        const SizedBox(height: 2),
                        Text(
                          '${state.stats.reactivationCount}',
                          style: textStyles.h1Mono.copyWith(color: colors.accentGreen, fontWeight: FontWeight.w500),
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

  void _showAddClientDialog(BuildContext context) {
    final colors = context.colors;
    final crmBloc = context.read<CrmBloc>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final cacController = TextEditingController(text: '0');
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Новый контрагент'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'ФИО / Компания'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cacController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Стоимость привлечения (CAC)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Примечание'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final cac = double.tryParse(cacController.text) ?? 0.0;

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
                Navigator.pop(dialogContext);
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  void _showAddDealDialog(BuildContext context) {
    final colors = context.colors;
    final crmBloc = context.read<CrmBloc>();
    final state = crmBloc.state;
    if (state is! CrmLoaded) return;

    CrmClient? selectedClient = state.clients.isNotEmpty ? state.clients.first : null;
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String stage = 'lead';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Новая сделка'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<CrmClient>(
                      initialValue: selectedClient,
                      decoration: const InputDecoration(labelText: 'Клиент'),
                      items: state.clients.map((c) {
                        return DropdownMenuItem<CrmClient>(
                          value: c,
                          child: Text(c.fullName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedClient = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Название сделки'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Сумма сделки (TJS)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(labelText: 'Этап воронки'),
                      items: const [
                        DropdownMenuItem(value: 'lead', child: Text('Лид / Заявка')),
                        DropdownMenuItem(value: 'proposal', child: Text('Коммерческое предл.')),
                        DropdownMenuItem(value: 'negotiation', child: Text('Согласование / Договор')),
                        DropdownMenuItem(value: 'won', child: Text('Сделка выиграна')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            stage = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text) ?? 0.0;
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
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Открыть'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
