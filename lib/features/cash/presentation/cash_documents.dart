part of 'cash_screen.dart';

class CashReceiptsView extends StatefulWidget {
  const CashReceiptsView({super.key});

  @override
  State<CashReceiptsView> createState() => _CashReceiptsViewState();
}

class _CashReceiptsViewState extends State<CashReceiptsView> {
  var _loading = true;
  String? _error;
  String? _kind;
  List<PosReceipt> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final page = await context.read<PosDocumentsRepository>().receipts(
        kind: _kind,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final kind in const [null, 'sale', 'return', 'exchange'])
                ChoiceChip(
                  label: Text(
                    language.translate(switch (kind) {
                      'sale' => 'cash_receipt_sale',
                      'return' => 'cash_receipt_return',
                      'exchange' => 'cash_receipt_exchange',
                      _ => 'cash_receipt_all',
                    }),
                  ),
                  selected: _kind == kind,
                  onSelected: (_) {
                    setState(() => _kind = kind);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(
              language.resolveMessage(_error!),
              style: TextStyle(color: colors.accentRed),
            )
          else if (_items.isEmpty)
            Text(language.translate('cash_receipt_empty'))
          else
            for (final receipt in _items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '№${receipt.receiptNo ?? receipt.id} · ${language.translate(_kindKey(receipt.kind))}',
                ),
                subtitle: Text(
                  [
                    if (receipt.registerName != null) receipt.registerName!,
                    if (receipt.cashierName != null) receipt.cashierName!,
                    formatLocalizedDateTime(context, receipt.occurredAt),
                  ].join(' · '),
                ),
                trailing: Text(
                  formatLocalizedNumber(
                    context,
                    receipt.amount,
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  ),
                  style: context.textStyles.bodyMono,
                ),
                onTap: () => _open(receipt.id),
              ),
        ],
      ),
    );
  }

  Future<void> _open(int id) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReceiptSheet(id: id),
    );
    if (changed == true) {
      if (!mounted) return;
      context.read<CashBloc>().add(const LoadCashData());
      await _load();
    }
  }
}

String _kindKey(String kind) => switch (kind) {
  'return' => 'cash_receipt_return',
  'exchange' => 'cash_receipt_exchange',
  _ => 'cash_receipt_sale',
};

String _reasonKey(String reason) => switch (reason) {
  'defect' => 'cash_writeoff_defect',
  'expired' => 'cash_writeoff_expired',
  'damage' => 'cash_writeoff_damage',
  'shortage' => 'cash_writeoff_shortage',
  'internal' => 'cash_writeoff_internal',
  _ => 'cash_writeoff_other',
};

class _ReceiptSheet extends StatefulWidget {
  const _ReceiptSheet({required this.id});

  final int id;

  @override
  State<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<_ReceiptSheet> {
  var _loading = true;
  String? _error;
  PosReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final receipt = await context.read<PosDocumentsRepository>().receipt(
        widget.id,
      );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final receipt = _receipt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: _loading
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : receipt == null
          ? Text(language.resolveMessage(_error ?? ''))
          : ListView(
              children: [
                Text(
                  '№${receipt.receiptNo ?? receipt.id}',
                  style: context.textStyles.h2Sans,
                ),
                Text(language.translate(_kindKey(receipt.kind))),
                const SizedBox(height: 8),
                for (final line in receipt.lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.productName),
                    subtitle: Text(
                      '${formatLocalizedNumber(context, line.qty, maximumFractionDigits: 3)} ${line.unit}',
                    ),
                    trailing: Text(
                      formatLocalizedNumber(
                        context,
                        line.amount,
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      ),
                    ),
                  ),
                if (receipt.canAct) ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _act(receipt, exchange: false),
                    child: Text(
                      language.translate('cash_receipt_return_action'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _act(receipt, exchange: true),
                    child: Text(
                      language.translate('cash_receipt_exchange_action'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _act(PosReceipt receipt, {required bool exchange}) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ReturnExchangeSheet(receipt: receipt, exchange: exchange),
    );
    if (done == true && mounted) Navigator.pop(context, true);
  }
}

class _ReturnPick {
  _ReturnPick(this.line) : qty = line.leftQty;

  final PosReceiptLine line;
  bool selected = false;
  bool defect = false;
  double qty;
}

class _NewLine {
  _NewLine(this.product) : qty = 1;

  final SaleProduct product;
  double qty;
}

class _ReturnExchangeSheet extends StatefulWidget {
  const _ReturnExchangeSheet({required this.receipt, required this.exchange});

  final PosReceipt receipt;
  final bool exchange;

  @override
  State<_ReturnExchangeSheet> createState() => _ReturnExchangeSheetState();
}

class _ReturnExchangeSheetState extends State<_ReturnExchangeSheet> {
  late final List<_ReturnPick> _picks;
  final _newLines = <_NewLine>[];
  final _comment = TextEditingController();
  final _scan = TextEditingController();
  final _pin = TextEditingController();
  String _reason = 'defect';
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _picks = [
      for (final line in widget.receipt.lines)
        if (line.kind == 'sale' && line.leftQty > 0) _ReturnPick(line),
    ];
  }

  @override
  void dispose() {
    _comment.dispose();
    _scan.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final language = context.read<LanguageCubit>();
    final chosen = _picks.where((p) => p.selected && p.qty > 0).toList();
    if (chosen.isEmpty) {
      setState(() => _error = language.translate('cash_receipt_pick'));
      return;
    }
    if (widget.exchange && _newLines.isEmpty) {
      setState(() => _error = language.translate('cash_receipt_need_new'));
      return;
    }
    if (chosen.any((p) => p.defect) &&
        _reason == 'other' &&
        _comment.text.trim().length < 2) {
      setState(() => _error = language.translate('cash_writeoff_other_hint'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final lines = [
      for (final pick in chosen)
        ReturnLineInput(
          movementId: pick.line.movementId,
          qty: pick.qty,
          toWriteoff: pick.defect,
        ),
    ];
    try {
      final repo = context.read<PosDocumentsRepository>();
      final pin = _pin.text.trim();
      if (widget.exchange) {
        await repo.exchangeReceipt(
          receiptId: widget.receipt.id,
          registerId: widget.receipt.registerId,
          lines: lines,
          newLines: [
            for (final line in _newLines)
              PosSaleLine(
                productId: int.parse(line.product.id),
                qty: line.qty,
                price: line.product.price,
              ),
          ],
          paymentMethod: widget.receipt.paymentMethod,
          writeoffReason: chosen.any((p) => p.defect) ? _reason : null,
          comment: _comment.text,
          pin: pin.isEmpty ? null : pin,
          requestId: newDocumentKey(),
        );
      } else {
        await repo.returnReceipt(
          receiptId: widget.receipt.id,
          registerId: widget.receipt.registerId,
          lines: lines,
          paymentMethod: widget.receipt.paymentMethod,
          writeoffReason: chosen.any((p) => p.defect) ? _reason : null,
          comment: _comment.text,
          pin: pin.isEmpty ? null : pin,
          requestId: newDocumentKey(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _addScanned() async {
    final code = _scan.text.trim();
    if (code.isEmpty) return;
    try {
      final product = await context
          .read<CashRepository>()
          .getSaleProductByBarcode(code);
      if (!mounted) return;
      setState(() {
        final index = _newLines.indexWhere((l) => l.product.id == product.id);
        if (index >= 0) {
          _newLines[index].qty += 1;
        } else {
          _newLines.add(_NewLine(product));
        }
        _scan.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        children: [
          Text(
            language.translate(
              widget.exchange
                  ? 'cash_receipt_exchange_action'
                  : 'cash_receipt_return_action',
            ),
            style: context.textStyles.h2Sans,
          ),
          for (final pick in _picks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: pick.selected,
              title: Text(pick.line.productName),
              subtitle: Text(
                '${language.translate('cash_receipt_qty')}: ${formatLocalizedNumber(context, pick.qty, maximumFractionDigits: 3)} / ${formatLocalizedNumber(context, pick.line.leftQty, maximumFractionDigits: 3)}',
              ),
              onChanged: (value) =>
                  setState(() => pick.selected = value == true),
              secondary: IconButton(
                onPressed: () => setState(() => pick.defect = !pick.defect),
                icon: Icon(
                  TablerIcons.alert_triangle,
                  color: pick.defect ? colors.accentRed : colors.textSecondary,
                ),
              ),
            ),
          if (_picks.any((p) => p.defect))
            DropdownButton<String>(
              isExpanded: true,
              value: _reason,
              items: [
                for (final reason in const [
                  'defect',
                  'expired',
                  'damage',
                  'shortage',
                  'internal',
                  'other',
                ])
                  DropdownMenuItem(
                    value: reason,
                    child: Text(language.translate(_reasonKey(reason))),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _reason = value);
              },
            ),
          if (widget.exchange) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scan,
                    decoration: InputDecoration(
                      labelText: language.translate('cash_pos_scan_hint'),
                    ),
                    onSubmitted: (_) => _addScanned(),
                  ),
                ),
                IconButton(
                  onPressed: _addScanned,
                  icon: const Icon(TablerIcons.plus),
                ),
              ],
            ),
            for (final line in _newLines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.product.name),
                trailing: Text(
                  formatLocalizedNumber(
                    context,
                    line.qty,
                    maximumFractionDigits: 3,
                  ),
                ),
              ),
          ],
          TextField(
            controller: _comment,
            decoration: InputDecoration(
              labelText: language.translate('cash_writeoff_comment'),
            ),
          ),
          TextField(
            controller: _pin,
            obscureText: true,
            decoration: InputDecoration(
              labelText: language.translate('cash_pin_title'),
            ),
          ),
          if (_error != null)
            Text(
              language.resolveMessage(_error!),
              style: TextStyle(color: colors.accentRed),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: Text(language.translate('common_save')),
          ),
        ],
      ),
    );
  }
}

class CashWriteoffsView extends StatefulWidget {
  const CashWriteoffsView({super.key, required this.isViewer});

  final bool isViewer;

  @override
  State<CashWriteoffsView> createState() => _CashWriteoffsViewState();
}

class _CashWriteoffsViewState extends State<CashWriteoffsView> {
  var _loading = true;
  String? _error;
  String? _reason;
  WriteoffPage? _page;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _page == null;
      _error = null;
    });
    try {
      final page = await context.read<PosDocumentsRepository>().writeoffs(
        reason: _reason,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final page = _page;
    return Column(
      children: [
        if (!widget.isViewer)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final done = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const _WriteoffSheet(),
                );
                if (done == true) _load();
              },
              icon: const Icon(TablerIcons.plus),
              label: Text(language.translate('cash_writeoff_new')),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final reason in const [
                      null,
                      'defect',
                      'expired',
                      'damage',
                      'shortage',
                      'internal',
                      'other',
                    ])
                      ChoiceChip(
                        label: Text(
                          language.translate(
                            reason == null
                                ? 'cash_receipt_all'
                                : _reasonKey(reason),
                          ),
                        ),
                        selected: _reason == reason,
                        onSelected: (_) {
                          setState(() => _reason = reason);
                          _load();
                        },
                      ),
                  ],
                ),
                if (page != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      formatLocalizedNumber(
                        context,
                        page.totalCost,
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      ),
                      style: context.textStyles.bodyMono,
                    ),
                  ),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(language.resolveMessage(_error!))
                else if (page == null || page.items.isEmpty)
                  Text(language.translate('cash_writeoff_empty'))
                else
                  for (final doc in page.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '№${doc.number} · ${language.translate(_reasonKey(doc.reason))}',
                      ),
                      subtitle: Text(
                        [
                          for (final line in doc.lines) line.productName,
                          if (doc.comment != null) doc.comment!,
                        ].join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        formatLocalizedNumber(
                          context,
                          doc.totalCost,
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WriteoffLine {
  _WriteoffLine(this.product) : qty = 1;
  final SaleProduct product;
  double qty;
}

class _WriteoffSheet extends StatefulWidget {
  const _WriteoffSheet();

  @override
  State<_WriteoffSheet> createState() => _WriteoffSheetState();
}

class _WriteoffSheetState extends State<_WriteoffSheet> {
  final _lines = <_WriteoffLine>[];
  final _scan = TextEditingController();
  final _comment = TextEditingController();
  final _pin = TextEditingController();
  String _reason = 'defect';
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _scan.dispose();
    _comment.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final code = _scan.text.trim();
    if (code.isEmpty) return;
    try {
      final product = await context
          .read<CashRepository>()
          .getSaleProductByBarcode(code);
      if (!mounted) return;
      setState(() {
        final index = _lines.indexWhere((l) => l.product.id == product.id);
        if (index >= 0) {
          _lines[index].qty += 1;
        } else {
          _lines.add(_WriteoffLine(product));
        }
        _scan.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _save() async {
    final language = context.read<LanguageCubit>();
    if (_lines.isEmpty) {
      setState(() => _error = language.translate('cash_pos_empty_cart'));
      return;
    }
    if (_reason == 'other' && _comment.text.trim().length < 2) {
      setState(() => _error = language.translate('cash_writeoff_other_hint'));
      return;
    }
    setState(() => _busy = true);
    try {
      final shift = context.read<CashBloc>().state;
      int? registerId;
      if (shift is CashLoaded && shift.registers.isNotEmpty) {
        registerId = int.tryParse(shift.registers.first.id);
      }
      await context.read<PosDocumentsRepository>().createWriteoff(
        registerId: registerId,
        reason: _reason,
        comment: _comment.text,
        pin: _pin.text.trim().isEmpty ? null : _pin.text.trim(),
        lines: [
          for (final line in _lines)
            PosSaleLine(
              productId: int.parse(line.product.id),
              qty: line.qty,
              price: line.product.price,
            ),
        ],
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        children: [
          Text(
            language.translate('cash_writeoff_new'),
            style: context.textStyles.h2Sans,
          ),
          DropdownButton<String>(
            isExpanded: true,
            value: _reason,
            items: [
              for (final reason in const [
                'defect',
                'expired',
                'damage',
                'shortage',
                'internal',
                'other',
              ])
                DropdownMenuItem(
                  value: reason,
                  child: Text(language.translate(_reasonKey(reason))),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _reason = value);
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scan,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_pos_scan_hint'),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(onPressed: _add, icon: const Icon(TablerIcons.plus)),
            ],
          ),
          for (final line in _lines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.product.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: line.qty <= 1
                        ? null
                        : () => setState(() => line.qty -= 1),
                    icon: const Icon(TablerIcons.minus),
                  ),
                  Text(
                    formatLocalizedNumber(
                      context,
                      line.qty,
                      maximumFractionDigits: 3,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => line.qty += 1),
                    icon: const Icon(TablerIcons.plus),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _comment,
            decoration: InputDecoration(
              labelText: language.translate('cash_writeoff_comment'),
            ),
          ),
          TextField(
            controller: _pin,
            obscureText: true,
            decoration: InputDecoration(
              labelText: language.translate('cash_pin_title'),
            ),
          ),
          if (_error != null)
            Text(
              language.resolveMessage(_error!),
              style: TextStyle(color: colors.accentRed),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: Text(language.translate('common_save')),
          ),
        ],
      ),
    );
  }
}
