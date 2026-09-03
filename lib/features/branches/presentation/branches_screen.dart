import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/ledger_buttons.dart';
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
import '../../../presentation/widgets/ledger_fab.dart';
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
    final locale = context.read<LanguageCubit>();

    LedgerBottomSheet.show(
      context: context,
      title: editing == null ? locale.translate('branches_new') : editing.name,
      builder: (context, setSheetState) =>
          _BranchFormSheet(editing: editing, branchesBloc: branchesBloc),
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
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          locale.translate('branches_title'),
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
      floatingActionButton: canManage
          ? LedgerFab(
              heroTag: null,
              onPressed: () => _showBranchModal(context),
              icon: TablerIcons.plus,
              label: locale.translate('branches_new'),
            )
          : null,
      body: BlocConsumer<BranchesBloc, BranchesState>(
        listener: (context, state) {
          if (state is BranchesLoaded && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(locale.translateMessage(state.message!))),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
                itemCount: state.branches.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final branch = state.branches[index];
                  return InkWell(
                    onTap: canManage
                        ? () => _showBranchModal(context, editing: branch)
                        : null,
                    borderRadius: BorderRadius.circular(12),
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
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colors.brand.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
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
                                              fontSize: 15.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (branch.code != null &&
                                            branch.code!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.surfaceNested,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              branch.code!,
                                              style: textStyles.smallMono
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                            ),
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
                                                    fontSize: 12.5,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: branch.isActive
                                      ? colors.accentGreen.withValues(
                                          alpha: 0.12,
                                        )
                                      : colors.accentRed.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  branch.isActive
                                      ? locale.translate('branches_active')
                                      : locale.translate('branches_inactive'),
                                  style: textStyles.captionSans.copyWith(
                                    color: branch.isActive
                                        ? colors.accentGreen
                                        : colors.accentRed,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
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
                                        fontSize: 12.5,
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
                                    fontSize: 12,
                                  ),
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
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _BranchFormSheet extends StatefulWidget {
  final Branch? editing;
  final BranchesBloc branchesBloc;

  const _BranchFormSheet({this.editing, required this.branchesBloc});

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editing?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.editing?.code ?? '');
    _addressCtrl = TextEditingController(text: widget.editing?.address ?? '');
    _phoneCtrl = TextEditingController(text: widget.editing?.phone ?? '');
    _isActive = widget.editing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    final editing = widget.editing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: locale.translate('branches_name'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          decoration: InputDecoration(
            labelText: locale.translate('branches_code'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: locale.translate('branches_address'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
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
              value: _isActive,
              activeThumbColor: colors.brand,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: kLedgerModalButtonHeight,
          child: ElevatedButton(
            onPressed: () {
              if (_nameCtrl.text.trim().isEmpty) return;
              if (editing == null) {
                widget.branchesBloc.add(
                  CreateBranchRequested(
                    name: _nameCtrl.text.trim(),
                    code: _codeCtrl.text.trim().isNotEmpty
                        ? _codeCtrl.text.trim()
                        : null,
                    address: _addressCtrl.text.trim(),
                    phone: _phoneCtrl.text.trim(),
                  ),
                );
              } else {
                widget.branchesBloc.add(
                  UpdateBranchRequested(
                    id: editing.id,
                    name: _nameCtrl.text.trim(),
                    code: _codeCtrl.text.trim().isNotEmpty
                        ? _codeCtrl.text.trim()
                        : null,
                    address: _addressCtrl.text.trim(),
                    phone: _phoneCtrl.text.trim(),
                    isActive: _isActive,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: Text(locale.translate('common_save')),
          ),
        ),
        if (editing != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: kLedgerModalButtonHeight,
            child: OutlinedButton.icon(
              onPressed: () {
                widget.branchesBloc.add(DeleteBranchRequested(editing.id));
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accentRed,
                side: BorderSide(
                  color: colors.accentRed.withValues(alpha: 0.5),
                ),
              ),
              icon: const Icon(TablerIcons.trash, size: 18),
              label: Text(locale.translate('common_delete')),
            ),
          ),
        ],
      ],
    );
  }
}
