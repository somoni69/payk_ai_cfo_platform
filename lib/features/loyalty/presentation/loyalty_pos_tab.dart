import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_barcode_scanner.dart';
import '../domain/loyalty_models.dart';
import '../domain/loyalty_repository.dart';
import 'loyalty_format.dart';

class LoyaltyPosTab extends StatefulWidget {
  const LoyaltyPosTab({
    super.key,
    required this.terminals,
    required this.programEnabled,
    required this.canManage,
  });

  final List<LoyaltyTerminal> terminals;
  final bool programEnabled;
  final bool canManage;

  @override
  State<LoyaltyPosTab> createState() => _LoyaltyPosTabState();
}

class _Seen {
  const _Seen(this.cash, this.payk, this.coupon);

  final double cash;
  final double payk;
  final double coupon;

  factory _Seen.of(LoyaltyPreview preview) {
    return _Seen(
      preview.cashToPay,
      preview.payk,
      preview.coupon.applied ? preview.coupon.amount : 0,
    );
  }
}

class _LoyaltyPosTabState extends State<LoyaltyPosTab> {
  final _code = TextEditingController();
  final _amount = TextEditingController();
  final _bill = TextEditingController();
  final _excluded = TextEditingController();
  final _card = TextEditingController();
  int? _terminalId;
  var _wholesale = false;
  var _busy = false;
  String? _error;
  LoyaltyPosState? _pos;
  _Seen? _seen;
  var _acked = true;
  String? _commitKey;
  List<LoyaltyBillRow> _bills = const [];
  Timer? _poll;

  LoyaltyRepository get _repo => context.read<LoyaltyRepository>();

  @override
  void initState() {
    super.initState();
    final active = widget.terminals.where((t) => t.isActive);
    _terminalId = (active.isEmpty ? widget.terminals : active).firstOrNull?.id;
    _loadBills();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _code.dispose();
    _amount.dispose();
    _bill.dispose();
    _excluded.dispose();
    _card.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    try {
      final rows = await _repo.bills(terminalId: _terminalId);
      if (!mounted) return;
      setState(() => _bills = rows);
    } catch (_) {}
  }

  void _watch(LoyaltyPreview preview) {
    _poll?.cancel();
    if (preview.state != 'pending') return;
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _refresh();
    });
  }

  bool _differs(LoyaltyPreview preview, _Seen seen) {
    final coupon = preview.coupon.applied ? preview.coupon.amount : 0.0;
    return (preview.cashToPay - seen.cash).abs() > 0.004 ||
        (preview.payk - seen.payk).abs() > 0.004 ||
        (coupon - seen.coupon).abs() > 0.004;
  }

  void _accept(LoyaltyPosState next, {required bool pricedNow}) {
    final preview = next.preview;
    final seen = _seen;
    final changed = !pricedNow && seen != null && _differs(preview, seen);
    setState(() {
      _pos = next;
      _error = null;
      if (pricedNow || !changed) {
        _seen = _Seen.of(preview);
        _acked = true;
      } else {
        _acked = false;
      }
    });
    _watch(preview);
  }

  Future<void> _refresh() async {
    final id = _pos?.preview.id;
    if (id == null || _busy) return;
    try {
      final next = await _repo.preview(id);
      if (!mounted || _pos?.preview.id != id) return;
      _accept(next, pricedNow: false);
    } catch (_) {}
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _identify() async {
    final terminal = _terminalId;
    final code = _code.text.trim();
    if (terminal == null || code.isEmpty) return;
    await _guard(() async {
      final next = await _repo.identify(terminalId: terminal, code: code);
      _commitKey = null;
      _accept(next, pricedNow: true);
    });
  }

  Future<void> _price() async {
    final preview = _pos?.preview;
    final amount = _amount.text.trim().replaceAll(',', '.');
    final bill = _bill.text.trim();
    if (preview == null || amount.isEmpty || bill.isEmpty) return;
    await _guard(() async {
      final next = await _repo.price(
        preview.id,
        amount: amount,
        billExtId: bill,
        excludedAmount: _excluded.text.trim().replaceAll(',', '.'),
        cardAmount: _card.text.trim().replaceAll(',', '.'),
        wholesale: _wholesale,
      );
      _commitKey ??= DateTime.now().microsecondsSinceEpoch.toRadixString(16);
      _accept(next, pricedNow: true);
    });
  }

  Future<void> _commit() async {
    final preview = _pos?.preview;
    final seen = _seen;
    if (preview == null || seen == null || !_acked) return;
    final key = _commitKey ?? DateTime.now().microsecondsSinceEpoch.toString();
    await _guard(() async {
      await _repo.commit(
        preview.id,
        key: key,
        expectedCash: seen.cash,
        expectedCoupon: seen.coupon,
      );
      if (!mounted) return;
      final language = context.read<LanguageCubit>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(language.translate('loyalty_pos_done'))),
      );
      setState(() {
        _pos = null;
        _seen = null;
        _commitKey = null;
        _code.clear();
        _amount.clear();
        _bill.clear();
        _excluded.clear();
        _card.clear();
        _wholesale = false;
      });
      _poll?.cancel();
      await _loadBills();
    });
  }

  Future<void> _cancel() async {
    final id = _pos?.preview.id;
    if (id == null) return;
    await _guard(() async {
      await _repo.cancelPreview(id);
      _poll?.cancel();
      setState(() {
        _pos = null;
        _seen = null;
        _commitKey = null;
      });
    });
  }

  Future<void> _scan() async {
    final code = await LedgerBarcodeScanner.open(context);
    if (code == null || !mounted) return;
    _code.text = code;
    await _identify();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final text = context.textStyles;
    final preview = _pos?.preview;
    final member = _pos?.member;
    final priced = preview?.priced == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (!widget.programEnabled)
          _Banner(language.translate('loyalty_pos_off'), warn: true),
        if (widget.terminals.isEmpty)
          Text(language.translate('loyalty_no_terminals'))
        else ...[
          Text(
            language.translate('loyalty_pos_terminal'),
            style: text.captionSans.copyWith(color: colors.textSecondary),
          ),
          DropdownButton<int>(
            isExpanded: true,
            value: _terminalId,
            items: [
              for (final terminal in widget.terminals)
                DropdownMenuItem(
                  value: terminal.id,
                  child: Text(
                    '${terminal.name} · ${loyaltyFormatLabel(language, terminal.formatCode)}',
                  ),
                ),
            ],
            onChanged: (id) {
              setState(() => _terminalId = id);
              _loadBills();
            },
          ),
        ],
        const SizedBox(height: 8),
        Text(
          language.translate('loyalty_pos_code_hint'),
          style: text.captionSans.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: language.translate('loyalty_pos_code'),
                ),
                onSubmitted: (_) => _identify(),
              ),
            ),
            IconButton(onPressed: _scan, icon: const Icon(TablerIcons.scan)),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _busy || _terminalId == null ? null : _identify,
          child: Text(language.translate('loyalty_pos_identify')),
        ),
        if (member != null) ...[
          const SizedBox(height: 12),
          _Banner(
            '${member.name} · ${member.phone}\n${loyaltyStatusLabel(language, member.status)} · ${language.translate('loyalty_balance')} ${formatLocalizedNumber(context, member.balance, minimumFractionDigits: 2, maximumFractionDigits: 2)}',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: language.translate('loyalty_pos_amount'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bill,
            decoration: InputDecoration(
              labelText: language.translate('loyalty_pos_bill'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _excluded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: language.translate('loyalty_pos_excluded'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _card,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: language.translate('loyalty_pos_card'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(language.translate('loyalty_pos_wholesale')),
            value: _wholesale,
            activeTrackColor: colors.brand,
            onChanged: (value) => setState(() => _wholesale = value),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _price,
            child: Text(language.translate('loyalty_pos_calc')),
          ),
        ],
        if (priced && preview != null) ...[
          const SizedBox(height: 12),
          _Quote(preview: preview),
          if (!_acked) ...[
            const SizedBox(height: 8),
            _Banner(language.translate('loyalty_pos_changed'), warn: true),
            TextButton(
              onPressed: () => setState(() {
                _seen = _Seen.of(preview);
                _acked = true;
              }),
              child: Text(language.translate('loyalty_pos_ack')),
            ),
          ],
          if (preview.clientConfirmed)
            Text(
              language.translate('loyalty_pos_confirmed'),
              style: text.captionSans.copyWith(color: colors.accentGreen),
            )
          else
            Text(
              language.translate('loyalty_pos_wait'),
              style: text.captionSans.copyWith(color: colors.textSecondary),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy || !_acked ? null : _commit,
                  child: Text(language.translate('loyalty_pos_commit')),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _cancel,
                child: Text(language.translate('loyalty_pos_cancel')),
              ),
            ],
          ),
          if (!preview.coinSuggested)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _guard(() async {
                      final next = await _repo.suggestCoin(preview.id);
                      _accept(next, pricedNow: false);
                    }),
              child: Text(language.translate('loyalty_pos_suggest_coin')),
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            language.resolveMessage(_error!),
            style: TextStyle(color: colors.accentRed),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _terminalId == null ? null : _returnBill,
              child: Text(language.translate('loyalty_pos_return')),
            ),
            if (widget.canManage) ...[
              OutlinedButton(
                onPressed: _terminalId == null ? null : _sms,
                child: Text(language.translate('loyalty_pos_sms')),
              ),
              OutlinedButton(
                onPressed: _terminalId == null ? null : _late,
                child: Text(language.translate('loyalty_pos_late')),
              ),
            ],
          ],
        ),
        if (_bills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            language.translate('loyalty_pos_recent'),
            style: text.bodySans.copyWith(fontWeight: FontWeight.w600),
          ),
          for (final bill in _bills.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${bill.extId} · ${bill.member}'),
              subtitle: Text(
                '${loyaltyModeLabel(language, bill.mode)} · ${bill.state}',
              ),
              trailing: Text(
                formatLocalizedNumber(
                  context,
                  bill.amount,
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2,
                ),
                style: text.bodyMono,
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _returnBill() async {
    final language = context.read<LanguageCubit>();
    final bill = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.translate('loyalty_pos_return')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bill,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_pos_return_bill'),
              ),
            ),
            TextField(
              controller: amount,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_pos_return_amount'),
              ),
            ),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_reason'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('loyalty_pos_return')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      bill.dispose();
      amount.dispose();
      note.dispose();
      return;
    }
    await _guard(() async {
      await _repo.returnBill(
        terminalId: _terminalId!,
        billExtId: bill.text,
        amount: amount.text.trim().replaceAll(',', '.'),
        note: note.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageCubit>().translate('loyalty_pos_return_done'),
          ),
        ),
      );
      await _loadBills();
    });
    bill.dispose();
    amount.dispose();
    note.dispose();
  }

  Future<void> _sms() async {
    final language = context.read<LanguageCubit>();
    final phone = TextEditingController();
    final code = TextEditingController();
    var started = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          return AlertDialog(
            title: Text(language.translate('loyalty_pos_sms')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phone,
                  decoration: InputDecoration(
                    labelText: language.translate('loyalty_phone'),
                  ),
                ),
                if (started)
                  TextField(
                    controller: code,
                    decoration: InputDecoration(
                      labelText: language.translate('loyalty_pos_code'),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(language.translate('common_cancel')),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    if (!started) {
                      await _repo.startSms(
                        terminalId: _terminalId!,
                        phone: phone.text,
                      );
                      setDialog(() => started = true);
                    } else {
                      final next = await _repo.confirmSms(
                        terminalId: _terminalId!,
                        phone: phone.text,
                        code: code.text,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      _accept(next, pricedNow: true);
                    }
                  } catch (error) {
                    if (!mounted) return;
                    setState(() => _error = error.toString());
                  }
                },
                child: Text(
                  language.translate(
                    started ? 'common_save' : 'loyalty_pos_sms',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    phone.dispose();
    code.dispose();
  }

  Future<void> _late() async {
    final language = context.read<LanguageCubit>();
    final phone = TextEditingController();
    final bill = TextEditingController();
    final amount = TextEditingController();
    final day = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.translate('loyalty_pos_late')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phone,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_phone'),
              ),
            ),
            TextField(
              controller: bill,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_pos_bill'),
              ),
            ),
            TextField(
              controller: amount,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_pos_amount'),
              ),
            ),
            TextField(
              controller: day,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_pos_day'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('common_save')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _guard(() async {
        await _repo.lateAccrual(
          terminalId: _terminalId!,
          phone: phone.text,
          billExtId: bill.text,
          amount: amount.text.trim().replaceAll(',', '.'),
          day: day.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageCubit>().translate('loyalty_saved'),
            ),
          ),
        );
      });
    }
    phone.dispose();
    bill.dispose();
    amount.dispose();
    day.dispose();
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message, {this.warn = false});

  final String message;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (warn ? colors.accentAmber : colors.brand).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.preview});

  final LoyaltyPreview preview;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    String money(double value) => formatLocalizedNumber(
      context,
      value,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    );
    final rows = <(String, String)>[
      (
        language.translate('loyalty_pos_mode'),
        loyaltyModeLabel(language, preview.mode),
      ),
      (language.translate('loyalty_pos_earn'), money(preview.earn)),
      (language.translate('loyalty_pos_burn'), money(preview.burn)),
      (language.translate('loyalty_pos_coin'), money(preview.coin)),
      (language.translate('loyalty_pos_payk'), money(preview.payk)),
      (language.translate('loyalty_pos_cash'), money(preview.cashToPay)),
      if (preview.coupon.applied || preview.coupon.offer > 0)
        (
          language.translate('loyalty_pos_coupon'),
          money(
            preview.coupon.applied
                ? preview.coupon.amount
                : preview.coupon.offer,
          ),
        ),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(row.$1)),
                Text(row.$2, style: context.textStyles.bodyMono),
              ],
            ),
          ),
      ],
    );
  }
}
