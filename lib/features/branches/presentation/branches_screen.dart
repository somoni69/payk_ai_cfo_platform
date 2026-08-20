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
                      address: addressCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    ),
                  );
                } else {
                  branchesBloc.add(
                    UpdateBranchRequested(
                      id: editing.id,
                      name: nameCtrl.text.trim(),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  locale.translateMessage(branch.name),
                                  style: textStyles.h2Sans.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              LedgerPill(
                                text: branch.isActive
                                    ? locale.translate('branches_active')
                                    : locale.translate('branches_inactive'),
                                backgroundColor: branch.isActive
                                    ? colors.accentGreen.withValues(alpha: 0.1)
                                    : colors.accentRed.withValues(alpha: 0.1),
                                textColor: branch.isActive
                                    ? colors.accentGreen
                                    : colors.accentRed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (branch.address.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  TablerIcons.map_pin,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    locale.translateMessage(branch.address),
                                    style: textStyles.bodySans.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (branch.phone.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  TablerIcons.phone,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  branch.phone,
                                  style: textStyles.bodySans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                locale
                                    .translate('branches_registers')
                                    .replaceAll(
                                      '{count}',
                                      branch.registersCount.toString(),
                                    ),
                                style: textStyles.captionSans.copyWith(
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
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
