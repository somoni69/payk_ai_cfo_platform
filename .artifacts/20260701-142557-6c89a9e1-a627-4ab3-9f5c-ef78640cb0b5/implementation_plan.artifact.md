# Refine Inline Month Picker Animation and Layout

Improve the "Inline-панель" in the HR screen by adding a smooth expansion animation (similar to how bottom sheets feel) and reducing the bottom spacing to match the user's feedback.

## Proposed Changes

### [HR Screen](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/hr_screen.dart)

#### [hr_screen.dart](file:///C:/Users/Farzod/payk_ai_cfo_platform/lib/presentation/screens/hr_screen.dart)

- Wrap the inline month picker in a `ClipRect` and `AnimatedAlign` (or `SizeTransition`) to create a smooth sliding expansion effect from the top.
- Reduce the bottom padding and remove the large `Divider` to make the panel more compact and reduce the "gap" between the picker and the content.
- Adjust the layout of `_buildInlineMonthPicker` to be more integrated.

```dart
// Implementation snippet for the animation
ClipRect(
  child: AnimatedAlign(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    alignment: Alignment.topCenter,
    heightFactor: _isMonthPickerExpanded ? 1.0 : 0.0,
    child: _buildInlineMonthPicker(),
  ),
)
```

## Verification Plan

### Manual Verification
1. Navigate to the **HR and KPI** screen.
2. Tap the period selector in the AppBar.
3. Verify that the picker slides down smoothly instead of appearing instantly.
4. Verify that the bottom margin is smaller and looks more balanced compared to the previous version.
5. Tap a month and verify it slides back up smoothly.
