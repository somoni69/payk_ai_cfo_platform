# Walkthrough - Replace Dialogs with LedgerBottomSheet

I have replaced the centered `AlertDialog` widgets in the CRM and HR screens with the standard `LedgerBottomSheet`. This ensures UI consistency across all modules, matching the behavior in the Tasks and Warehouse screens.

## Changes

### [CRM Screen](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/crm_screen.dart)

- **New Client Form**: Converted from `AlertDialog` to `LedgerBottomSheet`.
- **New Deal Form**: Converted from `AlertDialog` to `LedgerBottomSheet`.
- **UI Enhancements**:
    - Used `ExpansibleWidget` for selecting clients and deal stages instead of standard `DropdownButtonFormField`.
    - Integrated `LedgerBottomSheet.confirmDiscard` to warn users if they try to close a form with unsaved changes.
    - Used design system typography and colors.

### [HR Screen](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/hr_screen.dart)

- **Add Employee Form**: Converted from `AlertDialog` to `LedgerBottomSheet`.
- **Salary Adjustment Form**: Converted from `AlertDialog` to `LedgerBottomSheet`.
- **UI Enhancements**:
    - Consistent look and feel with the rest of the application.
    - Added dirty state checks and discard confirmation dialogs.

## Verification Summary

### Automated Tests
- Ran `analyze_files` on `crm_screen.dart` and `hr_screen.dart`.
- **Result**: No compilation errors or lint warnings.

### Manual Verification
- Verified that clicking the "Add" buttons now triggers a bottom sheet instead of a centered dialog.
- Verified that the "Discard Changes" warning appears when trying to close a partially filled form.
- Verified that all inputs use the correct themes and styles from the Ledger design system.
