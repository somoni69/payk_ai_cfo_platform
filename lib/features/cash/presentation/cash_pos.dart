part of 'cash_screen.dart';

class _PosLine {
  _PosLine({required this.product, required this.qty, required this.price});

  final SaleProduct product;
  int qty;
  double price;

  double get amount => qty * price;
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
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scanFocus.dispose();
    _gotController.dispose();
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

  double get _total =>
      _lines.fold<double>(0, (sum, line) => sum + line.amount);

  bool get _cashierNeedsShift {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return false;
    if (auth.role != UserRole.cashier) return false;
    final shift = widget.state.activeShift;
    return shift == null || !shift.isOpen;
  }

  void _addProduct(SaleProduct product) {
    setState(() {
      _error = null;
      final index = _lines.indexWhere((l) => l.product.id == product.id);
      if (index >= 0) {
        _lines[index].qty += 1;
      } else {
        _lines.add(_PosLine(product: product, qty: 1, price: product.price));
      }
    });
    _scanController.clear();
    _scanFocus.requestFocus();
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
      _addProduct(local.first);
      setState(() => _scanning = false);
      return;
    }
    try {
      final found = await context.read<CashRepository>().getSaleProductByBarcode(
        code,
      );
      if (!mounted) return;
      _addProduct(found);
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
      bankId: _method == PaymentMethod.cash ? null : _bankId,
    );
    final done = Completer<String?>();
    cashBloc.add(AddTransactionRequested(tx, result: done));
    final error = await done.future;
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() => _error = language.translateMessage(error));
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
        return AlertDialog(
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final registers = widget.state.registers;
    final filtered = _scanController.text.trim().isEmpty
        ? _products.take(12).toList()
        : _products
              .where((p) {
                final q = _scanController.text.trim().toLowerCase();
                return p.name.toLowerCase().contains(q) ||
                    (p.sku?.toLowerCase().contains(q) ?? false) ||
                    (p.barcode?.contains(_scanController.text.trim()) ??
                        false);
              })
              .take(12)
              .toList();

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
                .firstWhere(
                  (r) => r.id == id,
                  orElse: () => registers.first,
                )
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
          onChanged: (_) => setState(() {}),
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
        if (_loadingProducts)
          const LedgerListShimmer(itemCount: 3)
        else
          ...filtered.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _addProduct(p),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                        Icon(TablerIcons.plus, color: colors.brand, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                        onPressed: () {
                          setState(() {
                            if (line.qty <= 1) {
                              _lines.remove(line);
                            } else {
                              line.qty -= 1;
                            }
                          });
                        },
                        icon: Icon(
                          TablerIcons.minus,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        '${line.qty}',
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => line.qty += 1),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in PaymentMethod.values)
              ChoiceChip(
                label: Text(language.translate(method.labelKey)),
                selected: _method == method,
                onSelected: (_) => setState(() => _method = method),
                selectedColor: colors.brand.withValues(alpha: 0.12),
                side: BorderSide(
                  color: _method == method ? colors.brand : colors.border,
                ),
                labelStyle: textStyles.smallSans.copyWith(
                  color: _method == method ? colors.brand : colors.textPrimary,
                ),
                backgroundColor: colors.surface,
              ),
          ],
        ),
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
          height: 44,
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
      ],
    );
  }
}
