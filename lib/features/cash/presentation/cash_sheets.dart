part of 'cash_screen.dart';

extension _CashSheetBuilders on _CashViewMixin {
  void _showOpenShiftBottomSheet(
    BuildContext context,
    List<CashRegister> registers,
  ) {
    final language = context.read<LanguageCubit>();

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_open_shift_title'),
      builder: (context, setSheetState) =>
          _OpenShiftSheetContent(registers: registers),
    );
  }

  /// Точная исходная модалка "Новая операция" согласно скриншоту
  void _showAddTransactionBottomSheet(
    BuildContext context,
    AuthState authState,
    List<CashRegister> registers,
  ) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final formKey = GlobalKey<FormState>();

    bool isIncome = true; // По умолчанию выбран "Приход" как на скриншоте
    final amountController = TextEditingController();
    final counterpartyController = TextEditingController();
    final descriptionController = TextEditingController();
    PaymentMethod selectedPaymentMethod = PaymentMethod.cash;
    final cashPartController = TextEditingController();
    final cashlessPartController = TextEditingController();
    String? selectedBankId;
    var banks = <BankAccount>[];
    var banksLoadStarted = false;
    String? selectedCategory;
    String? selectedRegisterId = registers.isNotEmpty
        ? registers.first.id
        : null;
    final saleLines = <_CashSaleLine>[];
    var saleProducts = <SaleProduct>[];
    var saleProductsLoading = true;
    var saleProductsLoadStarted = false;
    String? itemsError;
    var submitting = false;

    final categories = [
      language.translate('cash_category_salary'),
      language.translate('cash_category_sales'),
      language.translate('cash_category_services'),
      language.translate('cash_category_advance'),
      language.translate('cash_category_inventory'),
      language.translate('cash_category_other'),
    ];

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('cash_new_operation'),
        builder: (context, setSheetState) {
          if (!banksLoadStarted) {
            banksLoadStarted = true;
            try {
              context
                  .read<FinOpsRepository>()
                  .getBankAccounts()
                  .then((list) {
                    setSheetState(() => banks = list);
                  })
                  .catchError((_) {});
            } catch (_) {}
          }
          if (!saleProductsLoadStarted) {
            saleProductsLoadStarted = true;
            context
                .read<CashRepository>()
                .getSaleProducts()
                .then((list) {
                  setSheetState(() {
                    saleProducts = list;
                    saleProductsLoading = false;
                  });
                })
                .catchError((_) {
                  setSheetState(() => saleProductsLoading = false);
                });
          }
          return Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Выбор "Приход" / "Расход" (Сегментный чип как на скриншоте)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setSheetState(() => isIncome = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isIncome
                                ? colors.accentGreen.withValues(alpha: 0.1)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isIncome
                                  ? colors.accentGreen
                                  : colors.border,
                              width: isIncome ? 1.5 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              language.translate('cash_income'),
                              style: textStyles.bodySans.copyWith(
                                color: isIncome
                                    ? colors.accentGreen
                                    : colors.textSecondary,
                                fontWeight: isIncome
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setSheetState(() {
                          isIncome = false;
                          for (final line in saleLines) {
                            line.dispose();
                          }
                          saleLines.clear();
                          itemsError = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isIncome
                                ? colors.accentRed.withValues(alpha: 0.1)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !isIncome
                                  ? colors.accentRed
                                  : colors.border,
                              width: !isIncome ? 1.5 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              language.translate('cash_expense'),
                              style: textStyles.bodySans.copyWith(
                                color: !isIncome
                                    ? colors.accentRed
                                    : colors.textSecondary,
                                fontWeight: !isIncome
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Касса (Заголовок + Наш фирменный ExpansibleWidget)
                if (registers.isNotEmpty) ...[
                  Text(
                    language.translate('cash_register'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExpansibleWidget<String>.selection(
                    cardPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      registers
                          .firstWhere(
                            (r) => r.id == selectedRegisterId,
                            orElse: () => CashRegister(
                              id: '',
                              name: language.translate('cash_default_register'),
                            ),
                          )
                          .name,
                      style: textStyles.bodySans,
                    ),
                    items: registers.map((r) => r.id).toList(),
                    selectedValue: selectedRegisterId,
                    itemLabelBuilder: (id) => registers
                        .firstWhere(
                          (r) => r.id == id,
                          orElse: () => CashRegister(id: id, name: id),
                        )
                        .name,
                    onSelected: (val) =>
                        setSheetState(() => selectedRegisterId = val),
                  ),
                  const SizedBox(height: 16),
                ],

                if (isIncome) ...[
                  Text(
                    language.translate('cash_sale_products_title'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    language.translate('cash_sale_products_hint'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (saleProductsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LedgerShimmer(
                        child: Row(
                          children: [
                            Expanded(
                              child: ShimmerBox(height: 38, borderRadius: 8),
                            ),
                            SizedBox(width: 8),
                            ShimmerBox(width: 70, height: 38, borderRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ...List.generate(saleLines.length, (index) {
                    final line = saleLines[index];
                    SaleProduct? selected;
                    for (final p in saleProducts) {
                      if (p.id == line.productId) {
                        selected = p;
                        break;
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ExpansibleWidget<String>.selection(
                              cardPadding: EdgeInsets.zero,
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                selected?.name ??
                                    language.translate(
                                      'cash_sale_pick_product',
                                    ),
                                style: textStyles.bodySans,
                              ),
                              items: saleProducts.map((p) => p.id).toList(),
                              selectedValue: line.productId,
                              itemLabelBuilder: (id) {
                                final p = saleProducts.firstWhere(
                                  (e) => e.id == id,
                                  orElse: () => SaleProduct(
                                    id: id,
                                    name: id,
                                    unit: '',
                                    price: 0,
                                    stockQty: 0,
                                  ),
                                );
                                return language.translate(
                                  'cash_sale_product_option',
                                  params: {
                                    'name': p.name,
                                    'qty': formatLocalizedNumber(
                                      context,
                                      p.stockQty,
                                    ),
                                    'unit': p.unit,
                                  },
                                );
                              },
                              onSelected: (id) {
                                setSheetState(() {
                                  line.productId = id;
                                  for (final p in saleProducts) {
                                    if (p.id == id) {
                                      line.priceCtrl.text =
                                          formatLocalizedNumber(
                                            context,
                                            p.price,
                                          );
                                      break;
                                    }
                                  }
                                  itemsError = null;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: line.qtyCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: textStyles.bodyMono,
                                    decoration: InputDecoration(
                                      labelText: language.translate(
                                        'cash_sale_qty',
                                      ),
                                    ),
                                    onChanged: (_) => setSheetState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: line.priceCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: textStyles.bodyMono,
                                    decoration: InputDecoration(
                                      labelText: language.translate(
                                        'cash_sale_price',
                                      ),
                                    ),
                                    onChanged: (_) => setSheetState(() {}),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setSheetState(() {
                                      line.dispose();
                                      saleLines.removeAt(index);
                                      itemsError = null;
                                    });
                                  },
                                  icon: Icon(
                                    TablerIcons.trash,
                                    size: 18,
                                    color: colors.accentRed,
                                  ),
                                ),
                              ],
                            ),
                            if (selected != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  language.translate(
                                    'cash_sale_stock',
                                    params: {
                                      'qty': formatLocalizedNumber(
                                        context,
                                        selected.stockQty,
                                      ),
                                      'unit': selected.unit,
                                    },
                                  ),
                                  style: textStyles.smallSans.copyWith(
                                    color: colors.textTooltip,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: saleProducts.isEmpty
                        ? null
                        : () {
                            setSheetState(() {
                              saleLines.add(_CashSaleLine());
                              itemsError = null;
                            });
                          },
                    icon: const Icon(TablerIcons.plus, size: 18),
                    label: Text(language.translate('cash_sale_add_line')),
                  ),
                  if (itemsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      language.resolveMessage(itemsError!),
                      style: textStyles.captionSans.copyWith(
                        color: colors.accentRed,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // 3. Сумма операции — при строках товаров считается автоматически.
                if (saleLines.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            language.translate('cash_sale_total'),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          formatLocalizedNumber(
                            context,
                            _saleLinesTotal(context, saleLines),
                          ),
                          style: textStyles.bodyMono.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: textStyles.bodySans,
                    decoration: InputDecoration(
                      hintText: language.translate('cash_operation_amount'),
                      prefixIcon: Icon(
                        TablerIcons.currency_dollar,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    validator: (val) {
                      if (saleLines.isNotEmpty) return null;
                      final parsed = parseLocalizedNumber(context, val ?? '');
                      if (parsed == null || parsed <= 0) {
                        return language.translate('cash_amount_required');
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                // 4. Способ оплаты (Чипы горизонтально)
                Text(
                  language.translate('cash_payment_method'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PaymentMethod.values.map((pm) {
                    final isSelected = selectedPaymentMethod == pm;

                    // Фирменные цвета согласно запросу
                    final Color selectedColor = switch (pm) {
                      PaymentMethod.alif => colors.accentGreen,
                      PaymentMethod.dushanbeCity => const Color(0xFFFF6B22),
                      _ => colors.brand,
                    };

                    return ChoiceChip(
                      label: Text(language.translate(pm.labelKey)),
                      selected: isSelected,
                      selectedColor: selectedColor,
                      backgroundColor: colors.surface,
                      checkmarkColor: Colors.white,
                      labelStyle: textStyles.captionSans.copyWith(
                        color: isSelected ? Colors.white : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      side: BorderSide(
                        color: isSelected ? selectedColor : colors.border,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setSheetState(() => selectedPaymentMethod = pm);
                        }
                      },
                    );
                  }).toList(),
                ),
                if (selectedPaymentMethod == PaymentMethod.mixed) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cashPartController,
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
                          controller: cashlessPartController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: textStyles.bodyMono,
                          decoration: InputDecoration(
                            labelText: language.translate(
                              'cash_mixed_cashless',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (selectedPaymentMethod != PaymentMethod.cash &&
                    banks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    language.translate('cash_bank'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExpansibleWidget<String>.selection(
                    cardPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      selectedBankId == null
                          ? language.translate('cash_bank_optional')
                          : banks
                                .firstWhere(
                                  (b) => b.id == selectedBankId,
                                  orElse: () => BankAccount(
                                    id: selectedBankId!,
                                    bankName: selectedBankId!,
                                  ),
                                )
                                .bankName,
                      style: textStyles.bodySans,
                    ),
                    items: banks.map((b) => b.id).toList(),
                    selectedValue: selectedBankId,
                    itemLabelBuilder: (id) => banks
                        .firstWhere(
                          (b) => b.id == id,
                          orElse: () => BankAccount(id: id, bankName: id),
                        )
                        .bankName,
                    onSelected: (val) =>
                        setSheetState(() => selectedBankId = val),
                  ),
                ],
                const SizedBox(height: 16),

                // 5. Категория (Заголовок + Наш фирменный ExpansibleWidget)
                Text(
                  language.translate('cash_category'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<String>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    selectedCategory ??
                        language.translate('cash_select_category'),
                    style: textStyles.bodySans.copyWith(
                      color: selectedCategory != null
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                  items: categories,
                  selectedValue: selectedCategory,
                  itemLabelBuilder: (category) => category,
                  onSelected: (val) =>
                      setSheetState(() => selectedCategory = val),
                ),
                const SizedBox(height: 16),

                // 6. Контрагент (Иконка пользователя)
                TextFormField(
                  controller: counterpartyController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    hintText: language.translate('cash_counterparty'),
                    prefixIcon: Icon(
                      TablerIcons.user,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return language.translate('cash_counterparty_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 7. Описание (Иконка документа)
                TextField(
                  controller: descriptionController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    hintText: language.translate('cash_description'),
                    prefixIcon: Icon(
                      TablerIcons.file_text,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: submitting
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    final items = <SaleItemInput>[];
                    if (isIncome && saleLines.isNotEmpty) {
                      for (final line in saleLines) {
                        if (line.productId == null || line.productId!.isEmpty) {
                          setSheetState(() {
                            itemsError = 'cash_sale_err_no_product';
                          });
                          return;
                        }
                        final qty = parseLocalizedNumber(
                          context,
                          line.qtyCtrl.text,
                        );
                        final price = parseLocalizedNumber(
                          context,
                          line.priceCtrl.text,
                        );
                        if (qty == null ||
                            qty <= 0 ||
                            price == null ||
                            price < 0) {
                          setSheetState(() {
                            itemsError = 'cash_sale_err_qty_price';
                          });
                          return;
                        }
                        SaleProduct? product;
                        for (final p in saleProducts) {
                          if (p.id == line.productId) {
                            product = p;
                            break;
                          }
                        }
                        if (product != null && qty > product.stockQty) {
                          setSheetState(() {
                            itemsError = 'cash_sale_err_stock';
                          });
                          return;
                        }
                        items.add(
                          SaleItemInput(
                            productId: line.productId!,
                            qty: qty,
                            price: price,
                          ),
                        );
                      }
                    }

                    final amt = items.isNotEmpty
                        ? items.fold<double>(0, (s, i) => s + i.amount)
                        : parseLocalizedNumber(context, amountController.text);
                    if (amt == null || amt <= 0) {
                      setSheetState(() {
                        itemsError = 'cash_amount_required';
                      });
                      return;
                    }

                    double? cashPart;
                    double? cashlessPart;
                    if (selectedPaymentMethod == PaymentMethod.mixed) {
                      cashPart = parseLocalizedNumber(
                        context,
                        cashPartController.text,
                      );
                      cashlessPart = parseLocalizedNumber(
                        context,
                        cashlessPartController.text,
                      );
                      if (cashPart == null ||
                          cashlessPart == null ||
                          cashPart < 0 ||
                          cashlessPart < 0 ||
                          (cashPart + cashlessPart - amt).abs() > 0.01) {
                        setSheetState(() {
                          itemsError = 'cash_mixed_err_sum';
                        });
                        return;
                      }
                    }

                    final tx = Transaction(
                      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
                      title: counterpartyController.text.trim(),
                      category: selectedCategory ?? 'cash_category_other',
                      amount: amt,
                      isIncome: isIncome,
                      paymentMethod: selectedPaymentMethod,
                      dateTime: DateTime.now(),
                      registerId: selectedRegisterId,
                      cashierName: authState is AuthAuthenticated
                          ? authState.username
                          : 'role_director',
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      cashAmount: cashPart,
                      cashlessAmount: cashlessPart,
                      bankId: selectedBankId,
                      saleItems: items,
                    );

                    setSheetState(() {
                      submitting = true;
                      itemsError = null;
                    });
                    final bloc = context.read<CashBloc>();
                    bloc.add(AddTransactionRequested(tx));
                    final nextState = await bloc.stream.firstWhere(
                      (s) => s is CashLoaded && !s.isSubmitting,
                    );
                    if (!context.mounted) return;
                    if (nextState is CashLoaded &&
                        nextState.errorMessage != null &&
                        !nextState.errorMessage!.startsWith('cash_tx_saved')) {
                      setSheetState(() {
                        submitting = false;
                        itemsError = nextState.errorMessage;
                      });
                      return;
                    }
                    for (final line in saleLines) {
                      line.dispose();
                    }
                    Navigator.pop(context);
                  },
            child: Text(language.translate('save_to_ledger')),
          );
        },
      );
    } finally {
      amountController.dispose();
      counterpartyController.dispose();
      descriptionController.dispose();
      cashPartController.dispose();
      cashlessPartController.dispose();
      for (final line in saleLines) {
        line.dispose();
      }
    }
  }

  Future<void> _showCloseShiftBottomSheet(
    BuildContext context,
    CashShift shift,
  ) async {
    final language = context.read<LanguageCubit>();
    final closedId = await LedgerBottomSheet.show<String>(
      context: context,
      title: language.translate('cash_close_shift_title'),
      builder: (context, setSheetState) =>
          _CloseShiftSheetContent(shift: shift),
    );
    if (closedId != null && context.mounted) {
      await _showShiftReportSheet(context, closedId);
    }
  }

  Future<void> _showShiftReportSheet(BuildContext context, String shiftId) {
    final language = context.read<LanguageCubit>();
    return LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_shift_report_title'),
      builder: (context, setSheetState) =>
          _ShiftReportSheetContent(shiftId: shiftId),
    );
  }

  void _showEditTransactionSheet(
    BuildContext context,
    Transaction transaction,
  ) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final formKey = GlobalKey<FormState>();
    var isIncome = transaction.isIncome;
    final amountController = TextEditingController(
      text: formatLocalizedNumber(context, transaction.amount),
    );
    final initialCounterparty =
        transaction.title == 'cash_operation_default' ||
            transaction.title.startsWith('cash_operation_')
        ? ''
        : transaction.title;
    final counterpartyController = TextEditingController(
      text: initialCounterparty,
    );
    final descriptionController = TextEditingController(
      text: transaction.description ?? '',
    );
    var method = transaction.paymentMethod;
    final cashPartController = TextEditingController(
      text: transaction.cashAmount == null
          ? ''
          : formatLocalizedNumber(context, transaction.cashAmount!),
    );
    final cashlessPartController = TextEditingController(
      text: transaction.cashlessAmount == null
          ? ''
          : formatLocalizedNumber(context, transaction.cashlessAmount!),
    );
    final hasSale =
        transaction.lines.isNotEmpty || transaction.saleItems.isNotEmpty;
    var submitting = false;
    String? error;

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('cash_edit_operation'),
        builder: (context, setSheetState) {
          return Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Выбор "Приход" / "Расход" (Фирменный сегментный переключатель)
                if (!hasSale) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setSheetState(() => isIncome = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isIncome
                                  ? colors.accentGreen.withValues(alpha: 0.1)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isIncome
                                    ? colors.accentGreen
                                    : colors.border,
                                width: isIncome ? 1.5 : 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                language.translate('cash_income'),
                                style: textStyles.bodySans.copyWith(
                                  color: isIncome
                                      ? colors.accentGreen
                                      : colors.textSecondary,
                                  fontWeight: isIncome
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setSheetState(() => isIncome = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isIncome
                                  ? colors.accentRed.withValues(alpha: 0.1)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isIncome
                                    ? colors.accentRed
                                    : colors.border,
                                width: !isIncome ? 1.5 : 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                language.translate('cash_expense'),
                                style: textStyles.bodySans.copyWith(
                                  color: !isIncome
                                      ? colors.accentRed
                                      : colors.textSecondary,
                                  fontWeight: !isIncome
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Сумма операции
                TextFormField(
                  controller: amountController,
                  enabled: !hasSale,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    hintText: language.translate('cash_operation_amount'),
                    prefixIcon: Icon(
                      TablerIcons.currency_dollar,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (val) {
                    final parsed = parseLocalizedNumber(context, val ?? '');
                    if (parsed == null || parsed <= 0) {
                      return language.translate('cash_amount_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 3. Способ оплаты
                Text(
                  language.translate('cash_payment_method'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PaymentMethod.values.map((pm) {
                    final isSelected = method == pm;
                    final Color selectedColor = switch (pm) {
                      PaymentMethod.alif => colors.accentGreen,
                      PaymentMethod.dushanbeCity => const Color(0xFFFF6B22),
                      _ => colors.brand,
                    };

                    return ChoiceChip(
                      label: Text(language.translate(pm.labelKey)),
                      selected: isSelected,
                      selectedColor: selectedColor,
                      backgroundColor: colors.surface,
                      checkmarkColor: Colors.white,
                      labelStyle: textStyles.captionSans.copyWith(
                        color: isSelected ? Colors.white : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      side: BorderSide(
                        color: isSelected ? selectedColor : colors.border,
                      ),
                      onSelected: (v) {
                        if (v) setSheetState(() => method = pm);
                      },
                    );
                  }).toList(),
                ),
                if (method == PaymentMethod.mixed) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cashPartController,
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
                          controller: cashlessPartController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: textStyles.bodyMono,
                          decoration: InputDecoration(
                            labelText: language.translate(
                              'cash_mixed_cashless',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // 4. Контрагент
                TextFormField(
                  controller: counterpartyController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    hintText: language.translate('cash_counterparty'),
                    prefixIcon: Icon(
                      TablerIcons.user,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return language.translate('cash_counterparty_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. Описание
                TextField(
                  controller: descriptionController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    hintText: language.translate('cash_description'),
                    prefixIcon: Icon(
                      TablerIcons.file_text,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    language.resolveMessage(error!),
                    style: textStyles.captionSans.copyWith(
                      color: colors.accentRed,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: submitting
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    final amt = parseLocalizedNumber(
                      context,
                      amountController.text,
                    );
                    if (amt == null || amt <= 0) {
                      setSheetState(() => error = 'cash_amount_required');
                      return;
                    }
                    double? cashPart;
                    double? cashlessPart;
                    if (method == PaymentMethod.mixed) {
                      cashPart = parseLocalizedNumber(
                        context,
                        cashPartController.text,
                      );
                      cashlessPart = parseLocalizedNumber(
                        context,
                        cashlessPartController.text,
                      );
                      if (cashPart == null ||
                          cashlessPart == null ||
                          cashPart < 0 ||
                          cashlessPart < 0 ||
                          (cashPart + cashlessPart - amt).abs() > 0.01) {
                        setSheetState(() => error = 'cash_mixed_err_sum');
                        return;
                      }
                    }
                    setSheetState(() {
                      submitting = true;
                      error = null;
                    });
                    final bloc = context.read<CashBloc>();
                    bloc.add(
                      UpdateTransactionRequested(
                        transaction.copyWith(
                          title: counterpartyController.text.trim(),
                          amount: amt,
                          isIncome: isIncome,
                          paymentMethod: method,
                          description: descriptionController.text.trim(),
                          cashAmount: cashPart,
                          cashlessAmount: cashlessPart,
                        ),
                      ),
                    );
                    final nextState = await bloc.stream.firstWhere(
                      (s) => s is CashLoaded && !s.isSubmitting,
                    );
                    if (!context.mounted) return;
                    if (nextState is CashLoaded &&
                        nextState.errorMessage != null &&
                        !nextState.errorMessage!.startsWith('cash_tx_saved')) {
                      setSheetState(() {
                        submitting = false;
                        error = nextState.errorMessage;
                      });
                      return;
                    }
                    Navigator.pop(context);
                  },
            child: Text(language.translate('common_save')),
          );
        },
      );
    } finally {
      amountController.dispose();
      counterpartyController.dispose();
      descriptionController.dispose();
      cashPartController.dispose();
      cashlessPartController.dispose();
    }
  }
}

class _CashSaleLine {
  String? productId;
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

double _saleLinesTotal(BuildContext context, List<_CashSaleLine> lines) {
  var sum = 0.0;
  for (final line in lines) {
    final qty = parseLocalizedNumber(context, line.qtyCtrl.text) ?? 0;
    final price = parseLocalizedNumber(context, line.priceCtrl.text) ?? 0;
    sum += qty * price;
  }
  return sum;
}

class _OpenShiftSheetContent extends StatefulWidget {
  final List<CashRegister> registers;
  const _OpenShiftSheetContent({required this.registers});

  @override
  State<_OpenShiftSheetContent> createState() => _OpenShiftSheetContentState();
}

class _OpenShiftSheetContentState extends State<_OpenShiftSheetContent> {
  late final TextEditingController _controller;
  String? _selectedRegisterId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '5000');
    _selectedRegisterId = widget.registers.isNotEmpty
        ? widget.registers.first.id
        : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final registers = widget.registers;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          language.translate('cash_open_shift_hint'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),

        if (registers.isNotEmpty) ...[
          Text(
            language.translate('cash_register'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<String>.selection(
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            tilePadding: EdgeInsets.zero,
            title: Text(
              registers
                  .firstWhere(
                    (r) => r.id == _selectedRegisterId,
                    orElse: () => CashRegister(
                      id: '',
                      name: language.translate('cash_default_register'),
                    ),
                  )
                  .name,
              style: textStyles.bodySans,
            ),
            items: registers.map((r) => r.id).toList(),
            selectedValue: _selectedRegisterId,
            itemLabelBuilder: (id) => registers
                .firstWhere(
                  (r) => r.id == id,
                  orElse: () => CashRegister(id: id, name: id),
                )
                .name,
            onSelected: (val) => setState(() => _selectedRegisterId = val),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          language.translate('cash_starting_balance_label'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: textStyles.bodyMono.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(TablerIcons.cash, color: colors.brand, size: 20),
            suffixText: language.translate('cash_currency_suffix'),
            hintText: '5 000',
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: kLedgerModalButtonHeight,
          child: ElevatedButton(
            onPressed: () {
              final bal = parseLocalizedNumber(context, _controller.text);
              if (bal != null && bal >= 0) {
                context.read<CashBloc>().add(
                  OpenShiftRequested(bal, registerId: _selectedRegisterId),
                );
                Navigator.pop(context);
              }
            },
            child: Text(language.translate('cash_open_shift_action')),
          ),
        ),
      ],
    );
  }
}

class _CloseShiftSheetContent extends StatefulWidget {
  final CashShift shift;
  const _CloseShiftSheetContent({required this.shift});

  @override
  State<_CloseShiftSheetContent> createState() =>
      _CloseShiftSheetContentState();
}

class _CloseShiftSheetContentState extends State<_CloseShiftSheetContent> {
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _noteCtrl;
  final Map<String, TextEditingController> _factCtrls = {};
  List<ShiftClosingLine> _lines = const [];
  List<ShiftPersonOption> _people = const [];
  String? _collectorId;
  String? _chiefId;
  String? _auditorId;
  String? _error;
  var _loading = true;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _balanceCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _loadForm();
  }

  Future<void> _loadForm() async {
    final id = widget.shift.id;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final repo = context.read<CashRepository>();
      final results = await Future.wait([
        repo.getClosingForm(id),
        repo.lookupShiftPeople(),
      ]);
      if (!mounted) return;
      final lines = results[0] as List<ShiftClosingLine>;
      for (final line in lines) {
        _factCtrls[line.key] = TextEditingController();
      }
      setState(() {
        _lines = lines;
        _people = results[1] as List<ShiftPersonOption>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _factCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final language = context.read<LanguageCubit>();
    final bal = parseLocalizedNumber(context, _balanceCtrl.text);
    if (bal == null || bal < 0) {
      setState(() => _error = language.translate('cash_actual_balance_hint'));
      return;
    }
    final facts = <ShiftTerminalFact>[];
    for (final line in _lines) {
      final raw = _factCtrls[line.key]?.text ?? '';
      final amount = parseLocalizedNumber(context, raw);
      if (amount == null || amount < 0) {
        setState(() => _error = language.translate('cash_close_err_terminal'));
        return;
      }
      facts.add(ShiftTerminalFact(key: line.key, amount: amount));
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final bloc = context.read<CashBloc>();
    bloc.add(
      CloseShiftRequested(
        bal,
        shiftId: widget.shift.id,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        terminalFacts: facts,
        collectorId: int.tryParse(_collectorId ?? ''),
        chiefCashierId: int.tryParse(_chiefId ?? ''),
        auditorId: int.tryParse(_auditorId ?? ''),
      ),
    );
    final next = await bloc.stream.firstWhere(
      (s) => s is CashLoaded && !s.isSubmitting,
    );
    if (!mounted) return;
    if (next is CashLoaded && next.errorMessage == null) {
      Navigator.pop(context, widget.shift.id);
    } else {
      setState(() {
        _submitting = false;
        _error = next is CashLoaded
            ? context.read<LanguageCubit>().translateMessage(
                next.errorMessage ?? 'error_save_failed',
              )
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final shift = widget.shift;
    final peopleItems = ['', ..._people.map((p) => p.id)];

    String personLabel(String id) {
      if (id.isEmpty) return language.translate('cash_close_person_none');
      for (final p in _people) {
        if (p.id == id) return p.label;
      }
      return id;
    }

    if (_loading) {
      return const LedgerShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShimmerBox(width: 140, height: 14, borderRadius: 4),
            SizedBox(height: 4),
            ShimmerBox(width: 180, height: 12, borderRadius: 4),
            SizedBox(height: 16),
            ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
            SizedBox(height: 16),
            ShimmerBox(width: 120, height: 14, borderRadius: 4),
            SizedBox(height: 8),
            ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
            SizedBox(height: 10),
            ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
            SizedBox(height: 16),
            ShimmerBox(width: 150, height: 14, borderRadius: 4),
            SizedBox(height: 8),
            ShimmerBox(width: double.infinity, height: 40, borderRadius: 12),
            SizedBox(height: 10),
            ShimmerBox(width: double.infinity, height: 40, borderRadius: 12),
            SizedBox(height: 20),
            ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          shift.registerName ?? language.translate('cash_default_register'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          language.translate(
            'cash_close_shift_opening',
            params: {
              'amount': formatLocalizedNumber(context, shift.startingBalance),
            },
          ),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _balanceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: textStyles.bodyMono,
          decoration: InputDecoration(
            labelText: language.translate('cash_shift_actual_balance'),
            suffixText: language.translate('cash_currency_suffix'),
            helperText: language.translate('cash_close_actual_hint'),
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          language.translate('cash_close_terminals'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (_lines.isEmpty)
          Text(
            language.translate('cash_close_no_terminals'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          )
        else ...[
          for (final line in _lines) ...[
            TextField(
              controller: _factCtrls[line.key],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodyMono,
              decoration: InputDecoration(
                labelText: line.label,
                suffixText: language.translate('cash_currency_suffix'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            language.translate('cash_close_terminal_hint'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          language.translate('cash_close_people'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          language.translate('cash_close_collector'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        ExpansibleWidget<String>.selection(
          cardPadding: EdgeInsets.zero,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            personLabel(_collectorId ?? ''),
            style: textStyles.bodySans,
          ),
          items: peopleItems,
          selectedValue: _collectorId ?? '',
          itemLabelBuilder: personLabel,
          onSelected: (v) =>
              setState(() => _collectorId = v.isEmpty ? null : v),
        ),
        const SizedBox(height: 10),
        Text(
          language.translate('cash_close_chief'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        ExpansibleWidget<String>.selection(
          cardPadding: EdgeInsets.zero,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(personLabel(_chiefId ?? ''), style: textStyles.bodySans),
          items: peopleItems,
          selectedValue: _chiefId ?? '',
          itemLabelBuilder: personLabel,
          onSelected: (v) => setState(() => _chiefId = v.isEmpty ? null : v),
        ),
        const SizedBox(height: 10),
        Text(
          language.translate('cash_close_auditor'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        ExpansibleWidget<String>.selection(
          cardPadding: EdgeInsets.zero,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            personLabel(_auditorId ?? ''),
            style: textStyles.bodySans,
          ),
          items: peopleItems,
          selectedValue: _auditorId ?? '',
          itemLabelBuilder: personLabel,
          onSelected: (v) => setState(() => _auditorId = v.isEmpty ? null : v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: language.translate('cash_close_shift_note'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: textStyles.captionSans.copyWith(color: colors.accentRed),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: kLedgerModalButtonHeight,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: Text(language.translate('cash_close_shift_action')),
          ),
        ),
      ],
    );
  }
}

class _ShiftReportSheetContent extends StatefulWidget {
  final String shiftId;
  const _ShiftReportSheetContent({required this.shiftId});

  @override
  State<_ShiftReportSheetContent> createState() =>
      _ShiftReportSheetContentState();
}

class _ShiftReportSheetContentState extends State<_ShiftReportSheetContent> {
  CashShiftReport? _report;
  String? _error;
  var _loading = true;
  var _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final report = await context.read<CashRepository>().getShiftReport(
        widget.shiftId,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _share(String format) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await context.read<CashRepository>().exportShiftReport(
        widget.shiftId,
        format: format,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/smena_${widget.shiftId}.$format');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageCubit>().translateMessage(e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    if (_loading) {
      return const LedgerShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
            SizedBox(height: 12),
            ShimmerBox(width: 160, height: 16, borderRadius: 4),
            SizedBox(height: 10),
            ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
            SizedBox(height: 8),
            ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
            SizedBox(height: 16),
            ShimmerBox(width: 100, height: 14, borderRadius: 4),
            SizedBox(height: 8),
            ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
            SizedBox(height: 6),
            ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
            SizedBox(height: 16),
            ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
            SizedBox(height: 8),
            ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
          ],
        ),
      );
    }
    if (_error != null || _report == null) {
      return Text(
        language.translate('cash_shift_report_error'),
        style: textStyles.bodySans.copyWith(color: colors.accentRed),
      );
    }

    final report = _report!;
    Widget moneyRow(String label, String value, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          language.translate('cash_shift_report_hint'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        Text(
          report.registerName ?? language.translate('cash_default_register'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
        ),
        if (report.cashierName != null)
          Text(
            report.cashierName!,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
        const SizedBox(height: 10),
        moneyRow(
          language.translate('cash_starting_balance_label'),
          '${formatLocalizedNumber(context, report.openingBalance)} TJS',
        ),
        if (report.actualBalance != null)
          moneyRow(
            language.translate('cash_shift_actual_balance'),
            '${formatLocalizedNumber(context, report.actualBalance!)} TJS',
          ),
        const SizedBox(height: 8),
        for (final line in report.lines) ...[
          Text(
            line.label,
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          moneyRow(
            language.translate('cash_shift_report_system'),
            '${formatLocalizedNumber(context, line.system)} TJS',
          ),
          moneyRow(
            language.translate('cash_shift_report_fact'),
            line.fact == null
                ? '—'
                : '${formatLocalizedNumber(context, line.fact!)} TJS',
          ),
          moneyRow(
            language.translate('cash_shift_report_diff'),
            line.diff == null
                ? '—'
                : '${formatLocalizedNumber(context, line.diff!)} TJS',
            color: line.diff == null || line.diff!.abs() < 0.01
                ? colors.accentGreen
                : colors.accentRed,
          ),
          const SizedBox(height: 8),
        ],
        if (report.expenses.isNotEmpty) ...[
          Text(
            language.translate('cash_shift_report_expenses'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          for (final exp in report.expenses)
            moneyRow(
              exp.name,
              '${formatLocalizedNumber(context, exp.amount)} TJS',
            ),
        ],
        if (report.collectorName != null)
          moneyRow(
            language.translate('cash_close_collector'),
            report.collectorName!,
          ),
        if (report.chiefCashierName != null)
          moneyRow(
            language.translate('cash_close_chief'),
            report.chiefCashierName!,
          ),
        if (report.auditorName != null)
          moneyRow(
            language.translate('cash_close_auditor'),
            report.auditorName!,
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: kLedgerModalButtonHeight,
          child: ElevatedButton(
            onPressed: _sharing ? null : () => _share('pdf'),
            child: Text(language.translate('cash_shift_report_pdf')),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: kLedgerModalButtonHeight,
          child: OutlinedButton(
            onPressed: _sharing ? null : () => _share('xlsx'),
            child: Text(language.translate('cash_shift_report_excel')),
          ),
        ),
      ],
    );
  }
}
