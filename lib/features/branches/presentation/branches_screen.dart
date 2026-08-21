import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/branches/bloc/branches_bloc.dart';
import '../../../features/branches/bloc/branches_event.dart';
import '../../../features/branches/bloc/branches_state.dart';
import '../../../features/branches/domain/branch_models.dart';
import '../../../features/branches/domain/branches_repository.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BranchesBloc>(
      create: (context) =>
          BranchesBloc(context.read<BranchesRepository>())
            ..add(const LoadBranches()),
      child: const BranchesView(),
    );
  }
}

class BranchesView extends StatelessWidget {
  const BranchesView({super.key});

  void _showBranchModal(BuildContext context, {Branch? editing}) {
    final branchesBloc = context.read<BranchesBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final codeCtrl = TextEditingController(text: editing?.code ?? '');
    final addressCtrl = TextEditingController(text: editing?.address ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    bool isActive = editing?.isActive ?? true;

    LedgerBottomSheet.show(
      context: context,
      title: editing == null ? locale.translate('branches_new') : editing.name,
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('branches_name'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: codeCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('branches_code'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('branches_address'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('branches_phone'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('branches_status'),
                style: textStyles.bodySans,
              ),
              Switch(
                value: isActive,
                activeThumbColor: colors.brand,
                onChanged: (val) => setSheetState(() => isActive = val),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                if (editing == null) {
                  branchesBloc.add(
                    CreateBranchRequested(
                      name: nameCtrl.text.trim(),
                      code: codeCtrl.text.trim().isNotEmpty
                          ? codeCtrl.text.trim()
                          : null,
                      address: addressCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    ),
                  );
                } else {
                  branchesBloc.add(
                    UpdateBranchRequested(
                      id: editing.id,
                      name: nameCtrl.text.trim(),
                      code: codeCtrl.text.trim().isNotEmpty
                          ? codeCtrl.text.trim()
                          : null,
                      address: addressCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      isActive: isActive,
                    ),
                  );
                }
                Navigator.pop(context);
              },
              child: Text(locale.translate('save_to_ledger')),
            ),
          ),
          if (editing != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  branchesBloc.add(DeleteBranchRequested(editing.id));
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accentRed,
                  side: BorderSide(
                    color: colors.accentRed.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(TablerIcons.trash, size: 18),
                label: Text(locale.translate('common_delete')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.branches);

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _showBranchModal(context),
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
              icon: const Icon(TablerIcons.plus),
              label: Text(
                locale.translate('branches_new'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: locale.translate('branches_title'),
              pinned: true,
              floating: false,
              snap: false,
            ),
          ];
        },
        body: BlocConsumer<BranchesBloc, BranchesState>(
          listener: (context, state) {
            if (state is BranchesLoaded && state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(locale.translateMessage(state.message!)),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is BranchesLoading) {
              return const BranchesOverviewShimmer();
            }
            if (state is BranchesError) {
              return Center(child: Text(state.message));
            }
            if (state is BranchesLoaded) {
              if (state.branches.isEmpty) {
                return Center(
                  child: Text(
                    locale.translate('branches_empty'),
                    style: textStyles.bodySans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<BranchesBloc>().add(
                    const LoadBranches(forceRefresh: true),
                  );
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.branches.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final branch = state.branches[index];
                    return LedgerCard(
                      onTap: canManage
                          ? () => _showBranchModal(context, editing: branch)
                          : null,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colors.brand.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  TablerIcons.building_store,
                                  size: 22,
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
                                        Flexible(
                                          child: Text(
                                            locale.translateMessage(
                                              branch.name,
                                            ),
                                            style: textStyles.bodySans.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (branch.code != null &&
                                            branch.code!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          LedgerPill(
                                            text: branch.code!,
                                            backgroundColor:
                                                colors.surfaceNested,
                                            textColor: colors.textSecondary,
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (branch.address.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            TablerIcons.map_pin,
                                            size: 13,
                                            color: colors.textTooltip,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              locale.translateMessage(
                                                branch.address,
                                              ),
                                              style: textStyles.captionSans
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              LedgerPill(
                                text: branch.isActive
                                    ? locale.translate('branches_active')
                                    : locale.translate('branches_inactive'),
                                backgroundColor: branch.isActive
                                    ? colors.accentGreen.withValues(alpha: 0.12)
                                    : colors.accentRed.withValues(alpha: 0.12),
                                textColor: branch.isActive
                                    ? colors.accentGreen
                                    : colors.accentRed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (branch.phone.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      TablerIcons.phone,
                                      size: 13,
                                      color: colors.textTooltip,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      branch.phone,
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const SizedBox(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceNested,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  locale
                                      .translate('branches_registers')
                                      .replaceAll(
                                        '{count}',
                                        branch.registersCount.toString(),
                                      ),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
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
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
