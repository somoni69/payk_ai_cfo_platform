import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/observability/app_error_reporter.dart';
import '../../../core/lifecycle/foreground_ticker.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/ledger_layout.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../cash/domain/transaction_model.dart';
import '../../cash/presentation/bank_logo.dart';
import '../../fin_ops/domain/fin_ops_models.dart';
import '../domain/playroom_models.dart';
import '../domain/playroom_repository.dart';
import '../domain/playroom_time.dart';

const _methods = <PaymentMethod>[
  PaymentMethod.cash,
  PaymentMethod.card,
  PaymentMethod.alif,
  PaymentMethod.dushanbeCity,
];

const _presets = <int>[30, 60, 90, 120, 180];

Future<PlayroomOrder?> showPlayroomOrderSheet(BuildContext context) {
  final repo = context.read<PlayroomRepository>();
  final language = context.read<LanguageCubit>();
  return showLedgerModalSheet<PlayroomOrder>(
    context: context,
    builder: (sheetContext) => _OrderSheet(repo: repo, language: language),
  );
}

Future<PlayroomOrder?> showPlayroomExtendSheet(
  BuildContext context,
  PlayroomOrder order,
) {
  final repo = context.read<PlayroomRepository>();
  final language = context.read<LanguageCubit>();
  return showLedgerModalSheet<PlayroomOrder>(
    context: context,
    builder: (sheetContext) =>
        _ExtendSheet(repo: repo, language: language, order: order),
  );
}

Future<void> showPlayroomTicketSheet(
  BuildContext context,
  PlayroomOrder order,
) {
  final repo = context.read<PlayroomRepository>();
  final language = context.read<LanguageCubit>();
  return showLedgerModalSheet<void>(
    context: context,
    builder: (sheetContext) =>
        _TicketSheet(repo: repo, language: language, order: order),
  );
}

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({required this.repo, required this.language});

  final PlayroomRepository repo;
  final LanguageCubit language;

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  ForegroundTicker? _clock;
  var _applyingPreset = false;

  var _people = 1;
  var _minutes = 60;
  var _startMode = 'now';
  var _startTime = '';
  var _nowTick = 0;
  PaymentMethod _method = PaymentMethod.cash;
  String? _bankId;
  int? _registerId;
  var _noShift = false;
  var _ready = false;
  var _submitting = false;
  String? _loadError;
  PlayroomTariff? _tariff;
  List<PlayroomRegister> _registers = const [];
  List<BankAccount> _banks = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _nowTick = now.millisecondsSinceEpoch;
    _startTime = storeParts(now).hhmm;
    _clock = ForegroundTicker(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() => _nowTick = DateTime.now().millisecondsSinceEpoch);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _clock?.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthBloc>().state;
      final userId = auth is AuthAuthenticated ? auth.id : null;
      final isCashier =
          auth is AuthAuthenticated && auth.role == UserRole.cashier;
      final loaded = await Future.wait([
        widget.repo.getTariff(),
        widget.repo.getRegisters(),
        widget.repo.getOpenShifts(),
      ]);
      List<BankAccount> banks = const [];
      try {
        banks = await widget.repo.getBanks();
      } catch (e, st) {
        // Banks only feed the non-cash option; cash payment still works.
        AppErrorReporter.reportOptional(e, st, context: 'playroom_banks');
      }
      if (!mounted) return;
      final registers = loaded[1] as List<PlayroomRegister>;
      final shifts = loaded[2] as List<PlayroomOpenShift>;
      PlayroomOpenShift? mine;
      if (userId != null) {
        for (final shift in shifts) {
          if (shift.cashierId == userId) {
            mine = shift;
            break;
          }
        }
      }
      setState(() {
        _tariff = loaded[0] as PlayroomTariff;
        _registers = registers;
        _banks = banks;
        _noShift = isCashier && mine == null;
        _registerId =
            mine?.registerId ?? (registers.isEmpty ? null : registers.first.id);
        _ready = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loadError = _errorKey(error);
      });
    }
  }

  StoreClock get _today =>
      storeParts(DateTime.fromMillisecondsSinceEpoch(_nowTick));

  int? get _startMinute {
    if (_startMode == 'now') return _today.minute;
    return hhmmToMinute(_startTime);
  }

  String _span(int total) => fmtMinutes(
    total,
    hours: widget.language.translate('playroom_unit_h'),
    minutes: widget.language.translate('playroom_unit_min'),
  );

  String? _problem(double? rate, bool stepOk, bool fits) {
    if (_loadError != null) return widget.language.resolveMessage(_loadError!);
    final start = _startMinute;
    if (start == null) {
      return widget.language.translate('playroom_order_pick_time');
    }
    if (rate == null) return widget.language.translate('playroom_order_closed');
    if (!stepOk) return widget.language.translate('playroom_order_step');
    if (!fits) {
      final left = cappedMinutes(start);
      return widget.language.translate(
        'playroom_order_midnight',
        params: {'d': _span(left < 0 ? 0 : left)},
      );
    }
    if (_noShift) return widget.language.translate('playroom_order_no_shift');
    if (_registerId == null) {
      return widget.language.translate('playroom_order_no_register');
    }
    return null;
  }

  Future<void> _submit(String? problem, bool needsBank) async {
    if (problem != null || needsBank || _registerId == null || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final order = await widget.repo.createOrder(
        PlayroomOrderInput(
          registerId: _registerId!,
          people: _people,
          minutes: _minutes,
          startAt: _startMode == 'time' ? isoAt(_today.date, _startTime) : null,
          customerName: name.isEmpty ? null : name,
          customerPhone: phone.isEmpty ? null : phone,
          paymentMethod: _method.apiValue,
          bankId: _method == PaymentMethod.cash
              ? null
              : int.tryParse(_bankId ?? ''),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(context, widget.language.resolveMessage(_errorKey(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final tariff = _tariff;
    final start = _startMinute;
    final rate = tariff == null || start == null
        ? null
        : rateAt(
            minuteOfDay: start,
            openFrom: tariff.openFrom,
            dayUntil: tariff.dayUntil,
            dayRate: tariff.dayRate,
            eveningRate: tariff.eveningRate,
          );
    final stepOk = _minutes >= 30 && _minutes % 30 == 0;
    final fits = start != null && start + _minutes <= 24 * 60;
    final amount = rate != null && stepOk
        ? playroomPrice(_people, rate, _minutes)
        : 0.0;
    final problem = _ready ? _problem(rate, stepOk, fits) : null;
    final needsBank =
        _method != PaymentMethod.cash && (_bankId == null || _bankId!.isEmpty);
    final endText = start == null ? '--:--' : endClock(start, _minutes);
    final startText = _startMode == 'now' ? _today.hhmm : _startTime;

    return LedgerBottomSheet(
      title: widget.language.translate('playroom_order_title'),
      maxHeight: ledgerModalHeightOf(context),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text(widget.language.translate('common_cancel')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: problem != null || needsBank || !_ready || _submitting
                  ? null
                  : () => _submit(problem, needsBank),
              child: Text(
                widget.language.translate(
                  'playroom_order_pay',
                  params: {'amount': formatSomoni(amount)},
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.language.translate('playroom_order_people'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StepButton(
                icon: TablerIcons.minus,
                tooltip: widget.language.translate('playroom_order_less'),
                onPressed: _people <= 1
                    ? null
                    : () => setState(() => _people -= 1),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_people',
                  textAlign: TextAlign.center,
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StepButton(
                icon: TablerIcons.plus,
                tooltip: widget.language.translate('playroom_order_more'),
                onPressed: _people >= 50
                    ? null
                    : () => setState(() => _people += 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DurationField(
            language: widget.language,
            minutes: _minutes,
            controller: _customCtrl,
            onPreset: (value) {
              _applyingPreset = true;
              _customCtrl.clear();
              _applyingPreset = false;
              setState(() => _minutes = value);
            },
            onCustom: (value) {
              if (_applyingPreset) return;
              final hours = double.tryParse(value.replaceAll(',', '.'));
              setState(() {
                _minutes = hours == null ? 0 : (hours * 60).round();
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            widget.language.translate('playroom_order_start'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Choice(
                label:
                    '${widget.language.translate('playroom_order_now')} · ${_today.hhmm}',
                selected: _startMode == 'now',
                onTap: () => setState(() => _startMode = 'now'),
              ),
              _Choice(
                label: widget.language.translate('playroom_order_at_time'),
                selected: _startMode == 'time',
                onTap: () => setState(() => _startMode = 'time'),
              ),
              if (_startMode == 'time')
                OutlinedButton(
                  onPressed: () async {
                    final initial = _timeOf(_startTime);
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: initial,
                    );
                    if (picked == null || !mounted) return;
                    setState(() {
                      _startTime =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  },
                  child: Text(_startTime),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            maxLength: 120,
            decoration: _field(
              context,
              widget.language.translate('playroom_order_customer'),
              widget.language.translate('playroom_order_optional'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            maxLength: 32,
            keyboardType: TextInputType.phone,
            decoration: _field(
              context,
              widget.language.translate('playroom_order_phone'),
              widget.language.translate('playroom_order_optional'),
            ),
          ),
          if (_registers.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              widget.language.translate('playroom_order_register'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            ExpansibleWidget<int>.selection(
              title: Text(_registerName()),
              items: [for (final item in _registers) item.id],
              selectedValue: _registers.any((item) => item.id == _registerId)
                  ? _registerId
                  : null,
              itemLabelBuilder: (id) => _nameOfRegister(id),
              onSelected: (id) => setState(() => _registerId = id),
            ),
          ],
          const SizedBox(height: 16),
          _PaymentField(
            language: widget.language,
            method: _method,
            bankId: _bankId,
            banks: _banks,
            onMethod: (method) => setState(() {
              _method = method;
              _bankId = _defaultBankId(method, _banks);
            }),
            onBank: (id) => setState(() => _bankId = id),
          ),
          const SizedBox(height: 16),
          _Summary(
            problem: problem,
            rows: [
              if (problem == null && rate != null) ...[
                _Row(
                  widget.language.translate('playroom_order_tariff'),
                  widget.language.translate(
                    'playroom_order_per_person',
                    params: {'rate': fmtRate(rate)},
                  ),
                ),
                _Row(
                  widget.language.translate('playroom_order_time'),
                  '$startText — $endText · ${_span(_minutes)}',
                ),
                _Row(
                  widget.language.translate('playroom_order_formula'),
                  '$_people × ${_span(_minutes)} × ${fmtRate(rate)}',
                ),
              ],
            ],
            totalLabel: widget.language.translate('playroom_order_total'),
            total: problem == null ? formatSomoni(amount) : null,
          ),
          if (!_ready)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (needsBank && problem == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.language.translate('playroom_order_bank'),
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ),
        ],
      ),
    );
  }

  String _registerName() {
    if (_registerId == null) {
      return widget.language.translate('playroom_order_register');
    }
    return _nameOfRegister(_registerId!);
  }

  String _nameOfRegister(int id) {
    for (final item in _registers) {
      if (item.id == id) return item.name;
    }
    return '#$id';
  }
}

class _ExtendSheet extends StatefulWidget {
  const _ExtendSheet({
    required this.repo,
    required this.language,
    required this.order,
  });

  final PlayroomRepository repo;
  final LanguageCubit language;
  final PlayroomOrder order;

  @override
  State<_ExtendSheet> createState() => _ExtendSheetState();
}

class _ExtendSheetState extends State<_ExtendSheet> {
  final _customCtrl = TextEditingController();
  var _applyingPreset = false;
  var _minutes = 60;
  PaymentMethod _method = PaymentMethod.cash;
  String? _bankId;
  var _submitting = false;
  PlayroomTariff? _tariff;
  List<BankAccount> _banks = const [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tariff = await widget.repo.getTariff();
      List<BankAccount> banks = const [];
      try {
        banks = await widget.repo.getBanks();
      } catch (e, st) {
        // Banks only feed the non-cash option; cash payment still works.
        AppErrorReporter.reportOptional(e, st, context: 'playroom_banks');
      }
      if (!mounted) return;
      setState(() {
        _tariff = tariff;
        _banks = banks;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = _errorKey(error));
    }
  }

  String _span(int total) => fmtMinutes(
    total,
    hours: widget.language.translate('playroom_unit_h'),
    minutes: widget.language.translate('playroom_unit_min'),
  );

  Future<void> _submit(String? problem, bool needsBank) async {
    if (problem != null || needsBank || _submitting) return;
    setState(() => _submitting = true);
    try {
      final order = await widget.repo.extendOrder(
        widget.order.id,
        PlayroomExtendInput(
          minutes: _minutes,
          paymentMethod: _method.apiValue,
          bankId: _method == PaymentMethod.cash
              ? null
              : int.tryParse(_bankId ?? ''),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(context, widget.language.resolveMessage(_errorKey(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final order = widget.order;
    final from = storeParts(order.endAt);
    final sameDay = from.date == storeParts(order.startAt).date;
    final tariff = _tariff;
    final rate = tariff != null && sameDay
        ? rateAt(
            minuteOfDay: from.minute,
            openFrom: tariff.openFrom,
            dayUntil: tariff.dayUntil,
            dayRate: tariff.dayRate,
            eveningRate: tariff.eveningRate,
          )
        : null;
    final stepOk = _minutes >= 30 && _minutes % 30 == 0;
    final fits = sameDay && from.minute + _minutes <= 24 * 60;
    final amount = rate != null && stepOk
        ? playroomPrice(order.people, rate, _minutes)
        : 0.0;
    final needsBank =
        _method != PaymentMethod.cash && (_bankId == null || _bankId!.isEmpty);
    String? problem;
    if (_loadError != null) {
      problem = widget.language.resolveMessage(_loadError!);
    } else if (_tariff != null && (!sameDay || rate == null)) {
      problem = widget.language.translate('playroom_extend_day_over');
    } else if (!stepOk) {
      problem = widget.language.translate('playroom_order_step');
    } else if (!fits) {
      final left = cappedMinutes(from.minute);
      problem = widget.language.translate(
        'playroom_order_midnight',
        params: {'d': _span(left < 0 ? 0 : left)},
      );
    }
    final endText = endClock(from.minute, _minutes);

    return LedgerBottomSheet(
      title: widget.language.translate(
        'playroom_extend_title',
        params: {'n': ticketNo(order.number)},
      ),
      maxHeight: ledgerModalHeightOf(context),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text(widget.language.translate('common_cancel')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed:
                  problem != null || needsBank || _submitting || _tariff == null
                  ? null
                  : () => _submit(problem, needsBank),
              child: Text(
                widget.language.translate(
                  'playroom_extend_pay',
                  params: {'amount': formatSomoni(amount)},
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.language.translate(
              'playroom_extend_about',
              params: {
                'people': '${order.people}',
                'time':
                    '${storeTime(order.startAt)} — ${storeTime(order.endAt)}',
              },
            ),
            style: textStyles.bodySans.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _DurationField(
            language: widget.language,
            minutes: _minutes,
            controller: _customCtrl,
            onPreset: (value) {
              _applyingPreset = true;
              _customCtrl.clear();
              _applyingPreset = false;
              setState(() => _minutes = value);
            },
            onCustom: (value) {
              if (_applyingPreset) return;
              final hours = double.tryParse(value.replaceAll(',', '.'));
              setState(() {
                _minutes = hours == null ? 0 : (hours * 60).round();
              });
            },
          ),
          const SizedBox(height: 16),
          _PaymentField(
            language: widget.language,
            method: _method,
            bankId: _bankId,
            banks: _banks,
            onMethod: (method) => setState(() {
              _method = method;
              _bankId = _defaultBankId(method, _banks);
            }),
            onBank: (id) => setState(() => _bankId = id),
          ),
          const SizedBox(height: 16),
          _Summary(
            problem: problem,
            rows: [
              if (problem == null && rate != null) ...[
                _Row(
                  widget.language.translate('playroom_extend_from'),
                  '${from.hhmm} — $endText',
                ),
                _Row(
                  widget.language.translate('playroom_order_tariff'),
                  widget.language.translate(
                    'playroom_order_per_person',
                    params: {'rate': fmtRate(rate)},
                  ),
                ),
              ],
            ],
            totalLabel: widget.language.translate('playroom_order_total'),
            total: problem == null ? formatSomoni(amount) : null,
          ),
        ],
      ),
    );
  }
}

class _TicketSheet extends StatefulWidget {
  const _TicketSheet({
    required this.repo,
    required this.language,
    required this.order,
  });

  final PlayroomRepository repo;
  final LanguageCubit language;
  final PlayroomOrder order;

  @override
  State<_TicketSheet> createState() => _TicketSheetState();
}

class _TicketSheetState extends State<_TicketSheet> {
  String? _busy;

  Future<void> _share(String format) async {
    setState(() => _busy = format);
    try {
      final bytes = await widget.repo.downloadTicketPdf(
        widget.order.id,
        format: format,
      );
      final dir = await getTemporaryDirectory();
      final name = 'bilet-${ticketNo(widget.order.number)}-$format.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
      );
    } catch (_) {
      if (mounted) {
        _snack(
          context,
          widget.language.translate('playroom_toast_print_error'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final language = widget.language;
    return LedgerBottomSheet(
      title: language.translate(
        'playroom_ticket_title',
        params: {'n': ticketNo(order.number)},
      ),
      maxHeight: ledgerModalHeightOf(context),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy != null ? null : () => _share('color'),
              child: Text(language.translate('playroom_ticket_pdf')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _busy != null ? null : () => _share('thermal'),
              child: Text(language.translate('playroom_ticket_print')),
            ),
          ),
        ],
      ),
      child: _TicketCard(order: order, language: language),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.order, required this.language});

  final PlayroomOrder order;
  final LanguageCubit language;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final unitsH = language.translate('playroom_unit_h');
    final unitsM = language.translate('playroom_unit_min');
    final stamp = switch (order.status) {
      PlayroomStatus.cancelled => language.translate(
        'playroom_status_cancelled',
      ),
      PlayroomStatus.closed => language.translate('playroom_status_closed'),
      PlayroomStatus.active => null,
    };
    final method = language.translate(order.paymentMethod.labelKey);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceNested,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: colors.brand,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    children: [
                      Text(
                        (order.storeName ?? 'PAYK').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyles.captionSans.copyWith(
                          color: colors.onBrand.withValues(alpha: 0.8),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        language.translate('playroom_ticket_heading'),
                        style: textStyles.h2Sans.copyWith(
                          color: colors.onBrand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B82E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          language.translate(
                            'playroom_ticket_number',
                            params: {'n': ticketNo(order.number)},
                          ),
                          style: textStyles.captionSans.copyWith(
                            color: const Color(0xFF1B1A2E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${storeTime(order.startAt)} — ${storeTime(order.endAt)}',
                        style: textStyles.h2Sans.copyWith(
                          color: colors.onBrand,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        storeDate(order.startAt),
                        style: textStyles.captionSans.copyWith(
                          color: colors.onBrand.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Detail(
                              language.translate('playroom_ticket_people'),
                              '${order.people}',
                            ),
                          ),
                          Expanded(
                            child: _Detail(
                              language.translate('playroom_ticket_duration'),
                              fmtMinutes(
                                order.baseMinutes,
                                hours: unitsH,
                                minutes: unitsM,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _Detail(
                              language.translate('playroom_ticket_tariff'),
                              language.translate(
                                'playroom_ticket_rate',
                                params: {'rate': fmtRate(order.rate)},
                              ),
                            ),
                          ),
                          Expanded(
                            child: _Detail(
                              language.translate('playroom_ticket_payment'),
                              order.bankName == null
                                  ? method
                                  : '$method · ${order.bankName}',
                            ),
                          ),
                        ],
                      ),
                      if (order.customerName != null) ...[
                        const SizedBox(height: 10),
                        _Detail(
                          language.translate('playroom_ticket_customer'),
                          order.customerName!,
                        ),
                      ],
                      if (order.extensions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final extra in order.extensions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    language.translate(
                                      'playroom_ticket_extension',
                                      params: {
                                        'd': fmtMinutes(
                                          extra.minutes,
                                          hours: unitsH,
                                          minutes: unitsM,
                                        ),
                                        'rate': fmtRate(extra.rate),
                                      },
                                    ),
                                    style: textStyles.captionSans.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatSomoni(extra.amount),
                                  style: textStyles.captionSans,
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                language.translate('playroom_ticket_paid'),
                                style: textStyles.bodySans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              formatSomoni(order.amount),
                              style: textStyles.h2Sans.copyWith(
                                color: colors.accentGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          QrImageView(
                            data: order.code,
                            size: 96,
                            backgroundColor: colors.onBrand,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  language.translate('playroom_ticket_show'),
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (order.createdByName != null)
                                  Text(
                                    '${language.translate('playroom_ticket_cashier')}: ${order.createdByName}',
                                    style: textStyles.captionSans.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                Text(
                                  order.code,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (stamp != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.accentRed, width: 3),
                      ),
                      child: Text(
                        stamp.toUpperCase(),
                        style: textStyles.h2Sans.copyWith(
                          color: colors.accentRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.language,
    required this.minutes,
    required this.controller,
    required this.onPreset,
    required this.onCustom,
  });

  final LanguageCubit language;
  final int minutes;
  final TextEditingController controller;
  final ValueChanged<int> onPreset;
  final ValueChanged<String> onCustom;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final preset = _presets.contains(minutes) && controller.text.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language.translate('playroom_order_duration'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _presets)
              _Choice(
                label: fmtMinutes(
                  value,
                  hours: language.translate('playroom_unit_h'),
                  minutes: language.translate('playroom_unit_min'),
                ),
                selected: preset && minutes == value,
                onTap: () => onPreset(value),
              ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: onCustom,
                decoration: _field(
                  context,
                  language.translate('playroom_order_custom'),
                  null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentField extends StatelessWidget {
  const _PaymentField({
    required this.language,
    required this.method,
    required this.bankId,
    required this.banks,
    required this.onMethod,
    required this.onBank,
  });

  final LanguageCubit language;
  final PaymentMethod method;
  final String? bankId;
  final List<BankAccount> banks;
  final ValueChanged<PaymentMethod> onMethod;
  final ValueChanged<String?> onBank;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    BankAccount? selected;
    for (final bank in banks) {
      if (bank.id == bankId) selected = bank;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language.translate('playroom_order_method'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _methods)
              _Choice(
                label: language.translate(item.labelKey),
                logo: item,
                selected: method == item,
                onTap: () => onMethod(item),
              ),
          ],
        ),
        if (method != PaymentMethod.cash) ...[
          const SizedBox(height: 12),
          Text(
            language.translate('playroom_order_bank'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<String>.selection(
            title: selected == null
                ? Text(language.translate('playroom_order_bank'))
                : BankNameLabel(
                    name: selected.bankName,
                    style: textStyles.bodySans,
                  ),
            items: [for (final bank in banks) bank.id],
            selectedValue: selected?.id,
            itemLabelBuilder: (id) {
              for (final bank in banks) {
                if (bank.id == id) return bank.bankName;
              }
              return id;
            },
            itemLeadingBuilder: (id) {
              String name = id;
              for (final bank in banks) {
                if (bank.id == id) name = bank.bankName;
              }
              final logo = bankLogoKeyForName(name);
              if (logo == null) return null;
              return BankLogo(logo: logo, height: 18);
            },
            onSelected: onBank,
          ),
        ],
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.logo,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final PaymentMethod? logo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final mark = logo == null ? null : paymentLogoKey(logo!);
    final showLogo =
        mark != null &&
        (logo == PaymentMethod.alif || logo == PaymentMethod.dushanbeCity);
    return Material(
      color: selected ? colors.brand.withValues(alpha: 0.12) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? colors.brand : colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
              child: showLogo
                  ? BankLogo(logo: mark, height: 22)
                  : Text(
                      label,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? colors.brand : colors.textSecondary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.problem,
    required this.rows,
    required this.totalLabel,
    required this.total,
  });

  final String? problem;
  final List<Widget> rows;
  final String totalLabel;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceNested,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: problem != null
          ? Text(
              problem!,
              style: textStyles.bodySans.copyWith(
                color: colors.accentRed,
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                ...rows,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        totalLabel,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      total ?? '',
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textStyles.captionSans.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textStyles.captionSans.copyWith(
            color: colors.textSecondary,
            fontSize: 10,
            letterSpacing: 0.6,
          ),
        ),
        Text(
          value,
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

InputDecoration _field(BuildContext context, String label, String? hint) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    counterText: '',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

TimeOfDay _timeOf(String hhmm) {
  final minute = hhmmToMinute(hhmm);
  if (minute == null) return TimeOfDay.now();
  return TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
}

String? _defaultBankId(PaymentMethod method, List<BankAccount> banks) {
  final pattern = switch (method) {
    PaymentMethod.alif => RegExp(r'alif|алиф', caseSensitive: false),
    PaymentMethod.dushanbeCity => RegExp(
      r'(^|\b)dc(\b|$)|dushanbe|душанбе',
      caseSensitive: false,
    ),
    _ => null,
  };
  if (pattern == null) return null;
  for (final bank in banks) {
    if (pattern.hasMatch(bank.bankName)) return bank.id;
  }
  return null;
}

String _errorKey(Object error) {
  final raw = error.toString();
  const prefix = 'Exception: ';
  return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
