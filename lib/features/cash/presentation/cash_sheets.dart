part of 'cash_screen.dart';

extension _CashSheetBuilders on _CashViewState {
  void _showOpenShiftBottomSheet(
    BuildContext context,
    List<CashRegister> registers,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final controller = TextEditingController(text: '5000');
    String? selectedRegisterId = registers.isNotEmpty
        ? registers.first.id
        : null;

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_open_shift_title'),
      builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate('cash_open_shift_hint'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

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

            Text(
              language.translate('cash_starting_balance_label'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodyMono.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  TablerIcons.cash,
                  color: colors.brand,
                  size: 20,
                ),
                suffixText: language.translate('cash_currency_suffix'),
                hintText: '5 000',
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      footerBuilder: (context, setSheetState) {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              final bal = parseLocalizedNumber(context, controller.text);
              if (bal != null && bal >= 0) {
                context.read<CashBloc>().add(OpenShiftRequested(bal));
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              language.translate('cash_open_shift_action'),
              style: textStyles.bodySans.copyWith(
                color: colors.surface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Точная исходная модалка "Новая операция" согласно скриншоту
  void _showAddTransactionBottomSheet(
    BuildContext context,
    AuthState authState,
    List<CashRegister> registers,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final formKey = GlobalKey<FormState>();

    bool isIncome = true; // По умолчанию выбран "Приход" как на скриншоте
    final amountController = TextEditingController();
    final counterpartyController = TextEditingController();
    final descriptionController = TextEditingController();
    PaymentMethod selectedPaymentMethod = PaymentMethod.cash;
    String? selectedCategory;
    String? selectedRegisterId = registers.isNotEmpty
        ? registers.first.id
        : null;

    final categories = [
      language.translate('cash_category_salary'),
      language.translate('cash_category_sales'),
      language.translate('cash_category_services'),
      language.translate('cash_category_advance'),
      language.translate('cash_category_inventory'),
      language.translate('cash_category_other'),
    ];

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_new_operation'),
      builder: (context, setSheetState) {
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
                      onTap: () => setSheetState(() => isIncome = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isIncome
                              ? colors.accentRed.withValues(alpha: 0.1)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isIncome ? colors.accentRed : colors.border,
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

              // 3. Сумма операции (Иконка доллара)
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
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: isSelected ? selectedColor : colors.border,
                    ),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedPaymentMethod = pm);
                    },
                  );
                }).toList(),
              ),
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
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final amt = parseLocalizedNumber(
                context,
                amountController.text,
              )!;

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
              );

              context.read<CashBloc>().add(AddTransactionRequested(tx));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              language.translate('save_to_ledger'),
              style: textStyles.bodySans.copyWith(
                color: colors.surface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}
