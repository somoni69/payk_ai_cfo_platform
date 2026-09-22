part of 'cash_screen.dart';

class _PosLine {
  _PosLine({required this.product, required this.qty, required this.price});

  final SaleProduct product;
  double qty;
  double price;

  double get amount => qty * price;
}

bool _isWeighedUnit(String unit) {
  const weighed = {'кг', 'г', 'гр', 'л', 'мл', 'kg', 'g', 'l', 'ml'};
  return weighed.contains(unit.trim().toLowerCase());
}

class CashPosView extends StatefulWidget {
  const CashPosView({super.key, required this.state, required this.isViewer});

  final CashLoaded state;
  final bool isViewer;

  @override
  State<CashPosView> createState() => _CashPosViewState();
}

class _CashPosViewState extends State<CashPosView> {
  final _scanController = TextEditingController();
  final _scanFocus = FocusNode();
  final _gotController = TextEditingController();
  final _cashPartController = TextEditingController();
  final _cashlessPartController = TextEditingController();

  List<SaleProduct> _products = const [];
  var _loadingProducts = true;
  final _lines = <_PosLine>[];
  PaymentMethod _method = PaymentMethod.cash;
  String? _registerId;
  String? _bankId;
  List<BankAccount> _banks = const [];
  String? _error;
  var _submitting = false;
  var _scanning = false;
  var _pinSet = false;
  var _isCashier = false;
  var _isPosAdmin = false;

  bool get _pinNeeded => _isCashier && _pinSet;

  @override
  void initState() {
    super.initState();
    final registers = widget.state.registers;
    if (registers.isNotEmpty) {
      _registerId = registers.first.id;
      final shiftName = widget.state.activeShift?.registerName;
      if (shiftName != null && shiftName.isNotEmpty) {
        final match = registers.where((r) => r.name == shiftName);
        if (match.isNotEmpty) _registerId = match.first.id;
      }
    }
    _loadCatalog();
    _loadBanks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPinStatus();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scanFocus.dispose();
    _gotController.dispose();
    _cashPartController.dispose();
    _cashlessPartController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final list = await context.read<CashRepository>().getSaleProducts();
      if (!mounted) return;
      setState(() {
        _products = list;
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadBanks() async {
    try {
      final list = await context.read<FinOpsRepository>().getBankAccounts();
      if (!mounted) return;
      setState(() => _banks = list);
    } catch (_) {}
  }

  Future<void> _loadPinStatus() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final isCashier = auth.role == UserRole.cashier;
    final isAdmin =
        auth.role == UserRole.owner || auth.role == UserRole.director;
    if (!isCashier && !isAdmin) return;
    try {
      final isSet = await context.read<CashRepository>().getPosPinStatus();
      if (!mounted) return;
      setState(() {
        _isCashier = isCashier;
        _isPosAdmin = isAdmin;
        _pinSet = isSet;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCashier = isCashier;
        _isPosAdmin = isAdmin;
      });
    }
  }

  List<PosCartLine> _cartSnapshot() {
    return [
      for (final line in _lines)
        PosCartLine(
          name: line.product.name,
          barcode: line.product.barcode,
          qty: line.qty.toDouble(),
          price: line.price,
        ),
    ];
  }

  Future<bool> _confirmCartEdit({
    required String kind,
    required SaleProduct product,
    required double qtyBefore,
    required double qtyAfter,
  }) async {
    if (!_pinNeeded) return true;
    final language = context.read<LanguageCubit>();
    final registerId = int.tryParse(_registerId ?? '');
    final action = PosEditAction(
      kind: kind,
      registerId: registerId,
      productName: product.name,
      productBarcode: product.barcode,
      price: product.price,
      qtyBefore: qtyBefore,
      qtyAfter: qtyAfter,
      cart: _cartSnapshot(),
    );
    final pinController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dlg) {
          var error = '';
          var busy = false;
          return Theme(
            data: LedgerButtons.modalOverlay(dlg),
            child: StatefulBuilder(
              builder: (context, setDialog) {
                final colors = context.colors;
                return AlertDialog(
                  title: Text(language.translate('cash_pin_title')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 8,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: language.translate('cash_pin_title'),
                          counterText: '',
                        ),
                        onSubmitted: (_) async {
                          if (busy) return;
                          final ok = await _submitPin(
                            pinController.text,
                            action,
                            language,
                            (msg) => setDialog(() => error = msg),
                          );
                          if (ok && dlg.mounted) Navigator.pop(dlg, true);
                        },
                      ),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          error,
                          style: TextStyle(
                            color: colors.accentRed,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dlg, false),
                      child: Text(language.translate('common_cancel')),
                    ),
                    ElevatedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setDialog(() => busy = true);
                              final ok = await _submitPin(
                                pinController.text,
                                action,
                                language,
                                (msg) => setDialog(() {
                                  error = msg;
                                  busy = false;
                                }),
                              );
                              if (ok && dlg.mounted) Navigator.pop(dlg, true);
                              if (!ok && dlg.mounted) {
                                setDialog(() => busy = false);
                              }
                            },
                      child: Text(language.translate('cash_pin_confirm')),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
      return confirmed == true;
    } finally {
      pinController.dispose();
    }
  }

  Future<bool> _submitPin(
    String pin,
    PosEditAction action,
    LanguageCubit language,
    void Function(String message) onError,
  ) async {
    final trimmed = pin.replaceAll(RegExp(r'\D'), '');
    if (trimmed.length < 4) {
      onError(language.translate('cash_pin_too_short'));
      return false;
    }
    try {
      final result = await context.read<CashRepository>().verifyPosPin(
        trimmed,
        action: action,
      );
      if (result.ok) return true;
      if (result.retryAfter > 0) {
        onError(
          '${language.translate('cash_pin_locked')} ${result.retryAfter} ${language.translate('cash_pin_seconds')}',
        );
      } else {
        onError(language.translate('cash_pin_wrong'));
      }
      return false;
    } catch (_) {
      onError(language.translate('cash_pin_failed'));
      return false;
    }
  }

  Future<void> _qtyDown(_PosLine line) async {
    final weighed = _isWeighedUnit(line.product.unit);
    final remove = weighed || line.qty <= 1;
    final ok = await _confirmCartEdit(
      kind: remove ? 'remove' : 'qty_down',
      product: line.product,
      qtyBefore: line.qty,
      qtyAfter: remove ? 0 : line.qty - 1,
    );
    if (!ok || !mounted) return;
    setState(() {
      if (remove) {
        _lines.remove(line);
      } else {
        line.qty -= 1;
      }
    });
  }

  Future<void> _showPinSetup() async {
    final language = context.read<LanguageCubit>();
    final pinController = TextEditingController();
    final repeatController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dlg) {
          var error = '';
          var busy = false;
          return Theme(
            data: LedgerButtons.modalOverlay(dlg),
            child: StatefulBuilder(
              builder: (context, setDialog) {
                final colors = context.colors;
                return AlertDialog(
                  title: Text(language.translate('cash_pin_setup_title')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: language.translate('cash_pin_new'),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: repeatController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: language.translate('cash_pin_repeat'),
                          counterText: '',
                        ),
                      ),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          error,
                          style: TextStyle(
                            color: colors.accentRed,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dlg),
                      child: Text(language.translate('common_cancel')),
                    ),
                    ElevatedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final pin = pinController.text.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              final repeat = repeatController.text.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              if (pin.length < 4) {
                                setDialog(
                                  () => error = language.translate(
                                    'cash_pin_too_short',
                                  ),
                                );
                                return;
                              }
                              if (pin != repeat) {
                                setDialog(
                                  () => error = language.translate(
                                    'cash_pin_mismatch',
                                  ),
                                );
                                return;
                              }
                              setDialog(() => busy = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final repo = context.read<CashRepository>();
                              try {
                                await repo.savePosPin(pin);
                                if (!mounted) return;
                                setState(() => _pinSet = true);
                                if (dlg.mounted) Navigator.pop(dlg);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      language.translate('cash_pin_saved'),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setDialog(() {
                                  busy = false;
                                  error = language.translateMessage(
                                    e.toString(),
                                  );
                                });
                              }
                            },
                      child: Text(language.translate('common_save')),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    } finally {
      pinController.dispose();
      repeatController.dispose();
    }
  }

  double get _total => _lines.fold<double>(0, (sum, line) => sum + line.amount);

  bool get _cashierNeedsShift {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return false;
    if (auth.role != UserRole.cashier) return false;
    final shift = widget.state.activeShift;
    return shift == null || !shift.isOpen;
  }

  void _addProduct(SaleProduct product, {double qty = 1}) {
    setState(() {
      _error = null;
      final index = _lines.indexWhere((l) => l.product.id == product.id);
      if (index >= 0) {
        _lines[index].qty += qty;
      } else {
        _lines.add(_PosLine(product: product, qty: qty, price: product.price));
      }
    });
    _scanController.clear();
    _scanFocus.requestFocus();
  }

  Future<void> _pickProduct(SaleProduct product) async {
    if (_isWeighedUnit(product.unit)) {
      final qty = await _askWeight(product);
      if (qty == null || qty <= 0 || !mounted) return;
      _addProduct(product, qty: qty);
      return;
    }
    _addProduct(product);
  }

  Future<double?> _askWeight(SaleProduct product) async {
    final language = context.read<LanguageCubit>();
    final controller = TextEditingController();
    try {
      return await showDialog<double>(
        context: context,
        builder: (dlg) {
          return Theme(
            data: LedgerButtons.modalOverlay(dlg),
            child: AlertDialog(
              title: Text(language.translate('cash_pos_weight_title')),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      '${language.translate('cash_pos_weight_qty')} (${product.unit})',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlg),
                  child: Text(language.translate('common_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value =
                        parseLocalizedNumber(context, controller.text) ??
                        double.tryParse(controller.text.replaceAll(',', '.'));
                    if (value == null || value <= 0) return;
                    Navigator.pop(dlg, value);
                  },
                  child: Text(language.translate('common_add')),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openCamera() async {
    if (_scanning) return;
    final code = await LedgerBarcodeScanner.open(context);
    if (code == null || !mounted) return;
    _scanController.text = code;
    await _handleScan();
  }

  Future<void> _handleScan() async {
    final code = _scanController.text.trim();
    if (code.isEmpty || _scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    final local = _products.where((p) {
      final needle = code.toLowerCase();
      return (p.barcode != null && p.barcode == code) ||
          (p.sku != null && p.sku == code) ||
          p.name.toLowerCase() == needle;
    });
    if (local.isNotEmpty) {
      await _pickProduct(local.first);
      setState(() => _scanning = false);
      return;
    }
    try {
      final found = await context
          .read<CashRepository>()
          .getSaleProductByBarcode(code);
      if (!mounted) return;
      await _pickProduct(found);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.read<LanguageCubit>().translate('cash_pos_not_found');
      });
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _checkout() async {
    final language = context.read<LanguageCubit>();
    if (_lines.isEmpty) {
      setState(() => _error = language.translate('cash_pos_empty_cart'));
      return;
    }
    if (_cashierNeedsShift) {
      setState(() => _error = language.translate('cash_pos_no_shift'));
      return;
    }
    if (_registerId == null || _registerId!.isEmpty) return;

    double? cashPart;
    double? cashlessPart;
    if (_method == PaymentMethod.mixed) {
      cashPart = parseLocalizedNumber(context, _cashPartController.text);
      cashlessPart = parseLocalizedNumber(
        context,
        _cashlessPartController.text,
      );
      if (cashPart == null ||
          cashlessPart == null ||
          cashPart < 0 ||
          cashlessPart < 0 ||
          (cashPart + cashlessPart - _total).abs() > 0.01) {
        setState(() => _error = language.translate('cash_mixed_err_sum'));
        return;
      }
    }

    final cashBloc = context.read<CashBloc>();
    if (_method == PaymentMethod.cash) {
      final proceed = await _confirmCashChange(language);
      if (proceed != true) return;
      if (!mounted) return;
    }

    setState(() => _submitting = true);
    final tx = Transaction(
      id: '',
      title: language.translate('cash_tab_pos'),
      category: language.translate('cash_category_sales'),
      amount: _total,
      isIncome: true,
      paymentMethod: _method,
      dateTime: DateTime.now(),
      cashierName: '',
      registerId: _registerId,
      saleItems: [
        for (final line in _lines)
          SaleItemInput(
            productId: line.product.id,
            qty: line.qty.toDouble(),
            price: line.price,
          ),
      ],
      cashAmount: cashPart,
      cashlessAmount: cashlessPart,
      bankId: _method == PaymentMethod.cash ? null : _bankId,
    );
    cashBloc.add(AddTransactionRequested(tx));
    final nextState = await cashBloc.stream.firstWhere(
      (s) => s is CashLoaded && !s.isSubmitting,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (nextState is CashLoaded &&
        nextState.errorMessage != null &&
        !nextState.errorMessage!.startsWith('cash_tx_saved')) {
      setState(
        () => _error = language.translateMessage(nextState.errorMessage!),
      );
      return;
    }
    setState(() {
      _lines.clear();
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(language.translate('cash_pos_done')),
        backgroundColor: context.colors.accentGreen,
      ),
    );
  }

  Future<bool?> _confirmCashChange(LanguageCubit language) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    _gotController.text = _total.toStringAsFixed(2);
    return showDialog<bool>(
      context: context,
      builder: (dlg) {
        return Theme(
          data: LedgerButtons.modalOverlay(dlg),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(language.translate('cash_pos_change_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  formatLocalizedNumber(context, _total),
                  style: textStyles.displayMono.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _gotController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: textStyles.bodyMono,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_pos_change_got'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlg, false),
                child: Text(language.translate('common_cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final got =
                      double.tryParse(
                        _gotController.text.replaceAll(',', '.'),
                      ) ??
                      _total;
                  final change = got - _total;
                  Navigator.pop(dlg, true);
                  if (change > 0 && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${language.translate('cash_pos_change_due')}: ${formatLocalizedNumber(context, change)}',
                        ),
                        backgroundColor: colors.brand,
                      ),
                    );
                  }
                },
                child: Text(language.translate('cash_pos_checkout')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentChip(BuildContext context, PaymentMethod method) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final isSelected = _method == method;
    final selectedColor = switch (method) {
      PaymentMethod.alif => colors.accentGreen,
      PaymentMethod.dushanbeCity => const Color(0xFFFF6B22),
      _ => colors.brand,
    };

    return ChoiceChip(
      label: Text(language.translate(method.labelKey)),
      selected: isSelected,
      selectedColor: selectedColor,
      backgroundColor: colors.surface,
      checkmarkColor: Colors.white,
      labelStyle: textStyles.captionSans.copyWith(
        color: isSelected ? Colors.white : colors.textPrimary,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
      ),
      side: BorderSide(color: isSelected ? selectedColor : colors.border),
      onSelected: (selected) {
        if (!selected) return;
        setState(() {
          _method = method;
          _bankId = _defaultBankIdFor(method, _banks);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final registers = widget.state.registers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24 + kLiquidNavClearance),
      children: [
        if (_cashierNeedsShift)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.accentAmber.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              language.translate('cash_pos_no_shift'),
              style: textStyles.captionSans.copyWith(color: colors.accentAmber),
            ),
          ),
        if (registers.length > 1) ...[
          const SizedBox(height: 10),
          ExpansibleWidget<String>.selection(
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            title: Text(
              registers
                  .firstWhere(
                    (r) => r.id == _registerId,
                    orElse: () => registers.first,
                  )
                  .name,
              style: textStyles.bodySans,
            ),
            items: registers.map((r) => r.id).toList(),
            selectedValue: _registerId,
            itemLabelBuilder: (id) => registers
                .firstWhere((r) => r.id == id, orElse: () => registers.first)
                .name,
            onSelected: (id) => setState(() => _registerId = id),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _scanController,
          focusNode: _scanFocus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _handleScan(),
          decoration: InputDecoration(
            labelText: language.translate('cash_pos_scan_hint'),
            prefixIcon: Icon(TablerIcons.barcode, color: colors.brand),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 96,
              minHeight: 48,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: language.translate('scan_barcode_title'),
                  onPressed: _scanning ? null : _openCamera,
                  icon: Icon(TablerIcons.camera, color: colors.brand),
                ),
                IconButton(
                  onPressed: _scanning ? null : _handleScan,
                  icon: _scanning
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.brand,
                          ),
                        )
                      : Icon(TablerIcons.search, color: colors.brand),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: textStyles.captionSans.copyWith(color: colors.accentRed),
          ),
        ],
        const SizedBox(height: 12),
        if (!_loadingProducts &&
            _products.any(
              (p) => (p.barcode == null || p.barcode!.isEmpty),
            )) ...[
          Text(
            language.translate('cash_quick_title'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            language.translate('cash_quick_hint'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _products.where(
                (item) => item.barcode == null || item.barcode!.isEmpty,
              ))
                Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _pickProduct(p),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 148,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatLocalizedNumber(context, p.price),
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_loadingProducts)
          const CashPosShimmer(catalogOnly: true)
        else
          ListenableBuilder(
            listenable: _scanController,
            builder: (context, _) {
              final query = _scanController.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? _products.take(12).toList()
                  : _products
                        .where((p) {
                          return p.name.toLowerCase().contains(query) ||
                              (p.sku?.toLowerCase().contains(query) ?? false) ||
                              (p.barcode?.toLowerCase().contains(query) ??
                                  false);
                        })
                        .take(12)
                        .toList();
              return Column(
                children: [
                  for (final p in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _pickProduct(p),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: textStyles.bodySans.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${formatLocalizedNumber(context, p.price)} • ${formatLocalizedNumber(context, p.stockQty)} ${p.unit}',
                                        style: textStyles.captionSans.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  TablerIcons.plus,
                                  color: colors.brand,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        Text(
          language.translate('cash_pos_cart'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_lines.isEmpty)
          Text(
            language.translate('cash_pos_empty_cart'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (final line in _lines) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.product.name,
                          style: textStyles.bodySans.copyWith(fontSize: 14),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _qtyDown(line),
                        icon: Icon(
                          TablerIcons.minus,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        formatLocalizedNumber(
                          context,
                          line.qty,
                          minimumFractionDigits: 0,
                          maximumFractionDigits: 3,
                        ),
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: _isWeighedUnit(line.product.unit)
                            ? null
                            : () => setState(() => line.qty += 1),
                        icon: Icon(
                          TablerIcons.plus,
                          size: 16,
                          color: colors.brand,
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          formatLocalizedNumber(context, line.amount),
                          style: textStyles.bodyMono.copyWith(fontSize: 13),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 16),
                Row(
                  children: [
                    Text(
                      language.translate('amount'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatLocalizedNumber(context, _total),
                      style: textStyles.h1Mono.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          language.translate('cash_payment_method'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in PaymentMethod.inputValues)
              _buildPaymentChip(context, method),
          ],
        ),
        if (_method == PaymentMethod.mixed) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashPartController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: textStyles.bodyMono,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_mixed_cash'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cashlessPartController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: textStyles.bodyMono,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_mixed_cashless'),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_method != PaymentMethod.cash && _banks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExpansibleWidget<String>.selection(
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            title: Text(
              _bankId == null
                  ? language.translate('cash_bank_optional')
                  : _banks
                        .firstWhere(
                          (b) => b.id == _bankId,
                          orElse: () =>
                              BankAccount(id: _bankId!, bankName: _bankId!),
                        )
                        .bankName,
              style: textStyles.bodySans,
            ),
            items: _banks.map((b) => b.id).toList(),
            selectedValue: _bankId,
            itemLabelBuilder: (id) => _banks
                .firstWhere(
                  (b) => b.id == id,
                  orElse: () => BankAccount(id: id, bankName: id),
                )
                .bankName,
            onSelected: (id) => setState(() => _bankId = id),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.isViewer || _submitting ? null : _checkout,
            child: _submitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.surface,
                    ),
                  )
                : Text(language.translate('cash_pos_checkout')),
          ),
        ),
        if (_isPosAdmin) ...[
          const SizedBox(height: 16),
          Container(
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
                    Icon(TablerIcons.key, size: 18, color: colors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        language.translate('cash_pin_setup_title'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      language.translate(
                        _pinSet ? 'cash_pin_is_set' : 'cash_pin_not_set',
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: _pinSet
                            ? colors.accentGreen
                            : colors.accentAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  language.translate('cash_pin_setup_desc'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _showPinSetup,
                  child: Text(language.translate('cash_pin_change')),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
