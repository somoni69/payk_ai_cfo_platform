# Replace Dialogs with LedgerBottomSheet in CRM and HR

Replace centered `AlertDialog` widgets in CRM and HR screens with the standard `LedgerBottomSheet` to maintain UI consistency with Tasks and Warehouse modules.

## Proposed Changes

### [CRM Screen](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/crm_screen.dart)

#### [crm_screen.dart](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/crm_screen.dart)

- Import `ledger_bottom_sheet.dart`.
- Update `_showAddClientDialog` to `_showAddClientBottomSheet` using `LedgerBottomSheet.show`.
- Update `_showAddDealDialog` to `_showAddDealBottomSheet` using `LedgerBottomSheet.show`.
- Use `footerBuilder` for the "Add" button and `LedgerBottomSheet.confirmDiscard` for the exit confirmation.

### [HR Screen](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/hr_screen.dart)

#### [hr_screen.dart](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/hr_screen.dart)

- Import `ledger_bottom_sheet.dart`.
- Update `_showAddEmployeeDialog` to `_showAddEmployeeBottomSheet` using `LedgerBottomSheet.show`.
- Update `_showRecalcSalaryDialog` to `_showRecalcSalaryBottomSheet` using `LedgerBottomSheet.show`.
- Use `footerBuilder` for action buttons.

## Verification Plan

### Manual Verification
1.  **CRM Screen**:
    *   Tap the "Add Client" icon. Verify it opens as a bottom sheet.
    *   Fill fields, try to close, verify the confirmation dialog.
    *   Tap the "Add Deal" icon. Verify it opens as a bottom sheet with dropdowns.
2.  **HR Screen**:
    *   Tap the "Add Employee" icon. Verify it opens as a bottom sheet.
    *   Double-tap a salary record. Verify the recalculation form opens as a bottom sheet.
