import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/ledger_buttons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_barcode_scanner.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/domain/app_access.dart';
import '../../cash/presentation/bank_logo.dart';
import '../../permissions/cubit/permissions_cubit.dart';
import '../../permissions/domain/my_permissions.dart';
import '../domain/playroom_models.dart';
import '../domain/playroom_repository.dart';
import '../domain/playroom_time.dart';
import 'playroom_sheets.dart';

class PlayroomScreen extends StatefulWidget {
  const PlayroomScreen({super.key});

  @override
  State<PlayroomScreen> createState() => _PlayroomScreenState();
}

class _PlayroomScreenState extends State<PlayroomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _orderSearch = TextEditingController();
  final _ticketSearch = TextEditingController();
  Timer? _debounce;
  Timer? _clock;

  var _loading = true;
  String? _error;
  PlayroomTariff? _tariff;
  PlayroomStats _stats = PlayroomStats.empty;
  List<PlayroomOrder> _orders = const [];
  List<PlayroomOrder> _tickets = const [];
  late String _day;
  var _orderQuery = '';
  var _ticketQuery = '';
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _day = storeParts().date;
    _tabs = TabController(length: 2, vsync: this);
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _load(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clock?.cancel();
    _tabs.dispose();
    _orderSearch.dispose();
    _ticketSearch.dispose();
    super.dispose();
  }

  PlayroomRepository get _repo => context.read<PlayroomRepository>();

  Future<void> _load({bool initial = false}) async {
    if (initial && mounted) setState(() => _loading = true);
    try {
      final tariff = await _repo.getTariff();
      final stats = await _repo.getStats();
      final orders = await _repo.listOrders(day: _day, query: _orderQuery);
      final tickets = await _repo.listOrders(
        active: _ticketQuery.isEmpty,
        query: _ticketQuery,
      );
      if (!mounted) return;
      setState(() {
        _tariff = tariff;
        _stats = stats;
        _orders = orders;
        _tickets = tickets;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(context, error);
      });
    }
  }

  Future<void> _reloadOrders() async {
    try {
      final orders = await _repo.listOrders(day: _day, query: _orderQuery);
      final stats = await _repo.getStats();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _stats = stats;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorText(context, error));
    }
  }

  Future<void> _reloadTickets() async {
    try {
      final tickets = await _repo.listOrders(
        active: _ticketQuery.isEmpty,
        query: _ticketQuery,
      );
      final stats = await _repo.getStats();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _stats = stats;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorText(context, error));
    }
  }

  void _queue(VoidCallback apply) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      apply();
    });
  }

  Future<void> _newOrder() async {
    final order = await showPlayroomOrderSheet(context);
    if (!mounted || order == null) return;
    _toast(
      context.read<LanguageCubit>().translate(
        'playroom_toast_created',
        params: {'n': ticketNo(order.number)},
      ),
    );
    await _load();
    if (!mounted) return;
    await showPlayroomTicketSheet(context, order);
  }

  Future<void> _extend(PlayroomOrder order) async {
    final updated = await showPlayroomExtendSheet(context, order);
    if (!mounted || updated == null) return;
    _toast(context.read<LanguageCubit>().translate('playroom_toast_extended'));
    await _load();
    if (!mounted) return;
    await showPlayroomTicketSheet(context, updated);
  }

  Future<void> _close(PlayroomOrder order) async {
    final language = context.read<LanguageCubit>();
    final ok = await _confirm(
      title: language.translate(
        'playroom_confirm_close_title',
        params: {'n': ticketNo(order.number)},
      ),
      message: language.translate('playroom_confirm_close'),
      action: language.translate('playroom_action_close'),
    );
    if (!ok || !mounted) return;
    try {
      await _repo.closeOrder(order.id);
      if (!mounted) return;
      _toast(language.translate('playroom_toast_closed'));
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(_errorText(context, error));
    }
  }

  Future<void> _cancel(PlayroomOrder order) async {
    final language = context.read<LanguageCubit>();
    final ok = await _confirm(
      title: language.translate(
        'playroom_confirm_cancel_title',
        params: {'n': ticketNo(order.number)},
      ),
      message: language.translate(
        'playroom_confirm_cancel',
        params: {'amount': formatSomoni(order.amount)},
      ),
      action: language.translate('playroom_action_cancel'),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.cancelOrder(order.id);
      if (!mounted) return;
      _toast(language.translate('playroom_toast_cancelled'));
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(_errorText(context, error));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool danger = false,
  }) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: LedgerButtons.modalOverlay(ctx),
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(language.translate('common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                action,
                style: textStyles.bodySans.copyWith(
                  color: danger ? colors.accentRed : colors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final auth = context.watch<AuthBloc>().state;
    final role = auth is AuthAuthenticated ? auth.role : null;
    final canCreate =
        role != null &&
        context.watch<PermissionsCubit>().can(
          AppCapability.playroom,
          action: PermAction.create,
          fallbackRole: role,
        );
    final canAct =
        role != null &&
        context.watch<PermissionsCubit>().can(
          AppCapability.playroom,
          action: PermAction.action,
          fallbackRole: role,
        );
    final canCancel = role == UserRole.owner || role == UserRole.director;
    final tariff = _tariff;
    final tariffLine = tariff == null
        ? language.translate('playroom_description')
        : language.translate(
            'playroom_tariff_line',
            params: {
              'from': tariff.openFrom,
              'until': tariff.dayUntil,
              'day': fmtRate(tariff.dayRate),
              'evening': fmtRate(tariff.eveningRate),
            },
          );
    final ticketCount = _stats.expired > 0
        ? _stats.active + _stats.expired
        : _stats.active;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          language.translate('playroom_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (canCreate)
            IconButton(
              tooltip: language.translate('playroom_new_order'),
              onPressed: _newOrder,
              icon: const Icon(TablerIcons.plus),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tariffLine,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _Stats(stats: _stats, language: language),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _error!,
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: language.translate('playroom_tab_orders')),
              Tab(
                text: ticketCount > 0
                    ? '${language.translate('playroom_tab_tickets')} · $ticketCount'
                    : language.translate('playroom_tab_tickets'),
              ),
            ],
          ),
          Expanded(
            child: _loading && _tariff == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _OrdersTab(
                        orders: _orders,
                        day: _day,
                        query: _orderQuery,
                        search: _orderSearch,
                        now: _now,
                        canCancel: canCancel,
                        onSearch: (value) => _queue(() {
                          setState(() => _orderQuery = value.trim());
                          _reloadOrders();
                        }),
                        onDay: (day) {
                          setState(() => _day = day);
                          _reloadOrders();
                        },
                        onRefresh: _reloadOrders,
                        onTicket: (order) =>
                            showPlayroomTicketSheet(context, order),
                        onCancel: _cancel,
                      ),
                      _TicketsTab(
                        tickets: _tickets,
                        query: _ticketQuery,
                        search: _ticketSearch,
                        now: _now,
                        canAct: canAct,
                        onSearch: (value) => _queue(() {
                          setState(() => _ticketQuery = value.trim());
                          _reloadTickets();
                        }),
                        onScan: () async {
                          final code = await LedgerBarcodeScanner.open(context);
                          if (!mounted || code == null || code.isEmpty) return;
                          _ticketSearch.text = code;
                          setState(() => _ticketQuery = code);
                          await _reloadTickets();
                        },
                        onRefresh: _reloadTickets,
                        onTicket: (order) =>
                            showPlayroomTicketSheet(context, order),
                        onExtend: _extend,
                        onClose: _close,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats, required this.language});

  final PlayroomStats stats;
  final LanguageCubit language;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        _Stat(
          language.translate('playroom_stats_orders'),
          '${stats.orders}',
        ),
        _Stat(
          language.translate('playroom_stats_people'),
          '${stats.people}',
        ),
        _Stat(
          language.translate('playroom_stats_revenue'),
          formatSomoni(stats.revenue),
          accent: true,
        ),
        _Stat(
          language.translate('playroom_stats_active'),
          '${stats.active}',
          hint: stats.expired > 0
              ? language.translate(
                  'playroom_stats_expired',
                  params: {'n': '${stats.expired}'},
                )
              : null,
          warn: stats.expired > 0,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.hint, this.accent = false, this.warn = false});

  final String label;
  final String value;
  final String? hint;
  final bool accent;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final valueColor = warn
        ? colors.accentRed
        : accent
        ? colors.brand
        : colors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyles.captionSans.copyWith(color: colors.accentRed),
            ),
        ],
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.orders,
    required this.day,
    required this.query,
    required this.search,
    required this.now,
    required this.canCancel,
    required this.onSearch,
    required this.onDay,
    required this.onRefresh,
    required this.onTicket,
    required this.onCancel,
  });

  final List<PlayroomOrder> orders;
  final String day;
  final String query;
  final TextEditingController search;
  final DateTime now;
  final bool canCancel;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onDay;
  final Future<void> Function() onRefresh;
  final ValueChanged<PlayroomOrder> onTicket;
  final ValueChanged<PlayroomOrder> onCancel;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final total = orders
        .where((order) => order.status != PlayroomStatus.cancelled)
        .fold<double>(0, (sum, order) => sum + order.amount);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () async {
                  final parts = day.split('-');
                  final initial = DateTime(
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                    int.parse(parts[2]),
                  );
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  final month = picked.month.toString().padLeft(2, '0');
                  final date = picked.day.toString().padLeft(2, '0');
                  onDay('${picked.year}-$month-$date');
                },
                child: Text(_prettyDay(day)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: language.translate('playroom_search'),
                    prefixIcon: const Icon(TablerIcons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: orders.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 48),
                      Icon(TablerIcons.ticket, color: colors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        query.isEmpty
                            ? language.translate('playroom_empty_orders')
                            : language.translate(
                                'playroom_empty_search',
                                params: {'q': query},
                              ),
                        textAlign: TextAlign.center,
                        style: textStyles.bodySans,
                      ),
                      if (query.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            language.translate('playroom_empty_orders_hint'),
                            textAlign: TextAlign.center,
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: orders.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == orders.length) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${language.translate('playroom_total')}: ${formatSomoni(total)}',
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final order = orders[index];
                      return _OrderCard(
                        order: order,
                        now: now,
                        showDate: query.isNotEmpty,
                        canCancel: canCancel,
                        onTicket: () => onTicket(order),
                        onCancel: () => onCancel(order),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _TicketsTab extends StatelessWidget {
  const _TicketsTab({
    required this.tickets,
    required this.query,
    required this.search,
    required this.now,
    required this.canAct,
    required this.onSearch,
    required this.onScan,
    required this.onRefresh,
    required this.onTicket,
    required this.onExtend,
    required this.onClose,
  });

  final List<PlayroomOrder> tickets;
  final String query;
  final TextEditingController search;
  final DateTime now;
  final bool canAct;
  final ValueChanged<String> onSearch;
  final VoidCallback onScan;
  final Future<void> Function() onRefresh;
  final ValueChanged<PlayroomOrder> onTicket;
  final ValueChanged<PlayroomOrder> onExtend;
  final ValueChanged<PlayroomOrder> onClose;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: search,
            onChanged: onSearch,
            decoration: InputDecoration(
              isDense: true,
              hintText: language.translate('playroom_ticket_search'),
              prefixIcon: const Icon(TablerIcons.search, size: 18),
              suffixIcon: IconButton(
                tooltip: language.translate('playroom_ticket_search'),
                onPressed: onScan,
                icon: const Icon(TablerIcons.scan, size: 20),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: tickets.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 48),
                      Icon(TablerIcons.device_gamepad_2, color: colors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        query.isEmpty
                            ? language.translate('playroom_empty_tickets')
                            : language.translate(
                                'playroom_empty_search',
                                params: {'q': query},
                              ),
                        textAlign: TextAlign.center,
                        style: textStyles.bodySans,
                      ),
                      if (query.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            language.translate('playroom_empty_tickets_hint'),
                            textAlign: TextAlign.center,
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = tickets[index];
                      return _TicketTile(
                        order: order,
                        now: now,
                        canAct: canAct,
                        onTicket: () => onTicket(order),
                        onExtend: () => onExtend(order),
                        onClose: () => onClose(order),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.now,
    required this.showDate,
    required this.canCancel,
    required this.onTicket,
    required this.onCancel,
  });

  final PlayroomOrder order;
  final DateTime now;
  final bool showDate;
  final bool canCancel;
  final VoidCallback onTicket;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final faded = order.status == PlayroomStatus.cancelled;
    final logo = paymentLogoKey(order.paymentMethod, bankName: order.bankName);
    return Opacity(
      opacity: faded ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
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
                Text(
                  ticketNo(order.number),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                _StatusBadge(order: order, now: now),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${storeTime(order.startAt)} — ${storeTime(order.endAt)}',
              style: textStyles.bodySans,
            ),
            if (showDate)
              Text(
                storeDate(order.startAt),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            Text(
              order.customerName ?? '—',
              style: textStyles.bodySans,
            ),
            if (order.customerPhone != null)
              Text(
                order.customerPhone!,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${order.people} · ${fmtMinutes(order.minutes, hours: language.translate('playroom_unit_h'), minutes: language.translate('playroom_unit_min'))}'
              '${order.extensions.isEmpty ? '' : ' ${language.translate('playroom_extended', params: {'n': '${order.extensions.length}'})}'}',
              style: textStyles.captionSans,
            ),
            Row(
              children: [
                if (logo != null) ...[
                  BankLogo(logo: logo, height: 16),
                  const SizedBox(width: 6),
                ],
                Text(
                  language.translate(order.paymentMethod.labelKey),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  formatSomoni(order.amount),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onTicket,
                  child: Text(language.translate('playroom_action_ticket')),
                ),
                if (canCancel && order.status != PlayroomStatus.cancelled)
                  TextButton(
                    onPressed: onCancel,
                    child: Text(
                      language.translate('playroom_action_cancel'),
                      style: TextStyle(color: colors.accentRed),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({
    required this.order,
    required this.now,
    required this.canAct,
    required this.onTicket,
    required this.onExtend,
    required this.onClose,
  });

  final PlayroomOrder order;
  final DateTime now;
  final bool canAct;
  final VoidCallback onTicket;
  final VoidCallback onExtend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final running = order.status == PlayroomStatus.active;
    final left = secondsLeft(order.endAt, now);
    final upcoming = running && order.startAt.isAfter(now);
    final expired = running && left <= 0;
    final soon = running && !expired && left <= 10 * 60;
    final startMs = order.startAt.millisecondsSinceEpoch;
    final endMs = order.endAt.millisecondsSinceEpoch;
    final progress = ((now.millisecondsSinceEpoch - startMs) /
            (endMs - startMs == 0 ? 1 : endMs - startMs))
        .clamp(0.0, 1.0);
    final unitsH = language.translate('playroom_unit_h');
    final unitsM = language.translate('playroom_unit_min');
    final leftMinutes = (left.abs() / 60).ceil();
    final String line;
    if (!running) {
      line = order.status == PlayroomStatus.closed
          ? language.translate('playroom_status_closed')
          : language.translate('playroom_status_cancelled');
    } else if (upcoming) {
      final wait = ((order.startAt.millisecondsSinceEpoch -
                  now.millisecondsSinceEpoch) /
              60000)
          .ceil();
      line = language.translate(
        'playroom_starts_in',
        params: {'d': fmtMinutes(wait < 0 ? 0 : wait, hours: unitsH, minutes: unitsM)},
      );
    } else if (expired) {
      line = language.translate(
        'playroom_overdue',
        params: {'d': fmtMinutes(leftMinutes, hours: unitsH, minutes: unitsM)},
      );
    } else {
      line = language.translate(
        'playroom_left',
        params: {'d': fmtMinutes(leftMinutes, hours: unitsH, minutes: unitsM)},
      );
    }
    final tone = expired
        ? colors.accentRed
        : soon
        ? colors.accentAmber
        : colors.accentGreen;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: expired ? colors.accentRed.withValues(alpha: 0.08) : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expired
              ? colors.accentRed
              : soon
              ? colors.accentAmber
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '№ ${ticketNo(order.number)}',
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusBadge(order: order, now: now),
            ],
          ),
          Text(
            '${order.customerName ?? language.translate('playroom_no_name')} · ${language.translate('playroom_people_short', params: {'n': '${order.people}'})}',
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '${storeTime(order.startAt)} — ${storeTime(order.endAt)}',
            style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surfaceNested,
              color: tone,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            line,
            style: textStyles.bodySans.copyWith(
              color: expired || soon ? tone : colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: onTicket,
                child: Text(language.translate('playroom_action_ticket')),
              ),
              if (running && canAct) ...[
                TextButton(
                  onPressed: onExtend,
                  child: Text(language.translate('playroom_action_extend')),
                ),
                TextButton(
                  onPressed: onClose,
                  child: Text(language.translate('playroom_action_close')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.order, required this.now});

  final PlayroomOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.watch<LanguageCubit>();
    final (key, color) = switch (order.status) {
      PlayroomStatus.cancelled => (
        'playroom_status_cancelled',
        colors.textSecondary,
      ),
      PlayroomStatus.closed => (
        'playroom_status_closed',
        colors.textSecondary,
      ),
      PlayroomStatus.active when secondsLeft(order.endAt, now) <= 0 => (
        'playroom_status_expired',
        colors.accentRed,
      ),
      PlayroomStatus.active when order.startAt.isAfter(now) => (
        'playroom_status_upcoming',
        colors.brand,
      ),
      PlayroomStatus.active => ('playroom_status_active', colors.accentGreen),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        language.translate(key),
        style: context.textStyles.captionSans.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _prettyDay(String day) {
  final parts = day.split('-');
  if (parts.length != 3) return day;
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}

String _errorText(BuildContext context, Object error) {
  final raw = error.toString();
  const prefix = 'Exception: ';
  final key = raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  return context.read<LanguageCubit>().resolveMessage(key);
}
