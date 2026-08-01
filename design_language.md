# Ledger Design System & Language Standards

This document serves as the complete technical design system and widget reference for the **PAYK CFO Platform**.

---

## 🎨 Visual Philosophy: "Ledger"
- **Purpose**: Strict financial dashboard, mathematical precision, high data density.
- **Layout**: Left-aligned, structured columns and tables. No centering by default.
- **Borders over Shadows**: No blurry shadows. Blocks are separated by 1px borders (`border` token `#E6E7EA`).
- **Rounding Rules**:
    - **Cards (`LedgerCard`)**: 16px radius.
    - **Buttons / Input Fields**: 8px – 12px radius.
    - **Status Pills (`LedgerPill`)**: 999px (full rounding).
    - **Bottom Sheets (`LedgerBottomSheet`)**: 24px radius with top drag handle.
- **Anti-Patterns**: No gradients, no glassmorphism, no emojis in UI. Use professional linear icons (Tabler Icons).

---

## 🎨 Color Palette (`context.colors`)

| Token | HEX (Color) | Semantic Purpose |
| :--- | :--- | :--- |
| `background` | `#F7F7F4` | General screen background |
| `surface` | `#FFFFFF` | Primary card/block background |
| `surfaceNested` | `#F1F1EC` | Inner highlighted areas / nested cards |
| `textPrimary` | `#1A1D29` | Headings, primary data |
| `textSecondary`| `#5A6072` | Captions, secondary labels |
| `textTooltip` | `#606778` | Hints, placeholders, muted text |
| `border` | `#E6E7EA` | Dividers and borders (1px) |
| `brand` | `#362CD1` | Primary actions, navigation, active tabs |
| `accentGreen` | `#17795E` | Positive delta, income, active status |
| `accentRed` | `#C0392B` | Negative delta, expenses, churn risk |
| `accentAmber` | `#B7791F` | AI features, warnings, pending items |

---

## 🔤 Typography & Font Tokens (`context.textStyles`)

- **System Fonts**: Standard sans-serif for UI text; system monospace with `FontFeature.tabularFigures()` for all numeric values.
- **Weights**: Strictly `w400` (Regular) and `w500` (Medium/Bold).

| Token | Font Family | Size | Weight | Features / Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `displayMono` | Monospace | 30px | `w500` | Tabular figures; large dashboard metrics |
| `h1Sans` | Sans-Serif | 24px | `w500` | Screen & section main titles |
| `h1Mono` | Monospace | 24px | `w500` | Tabular figures; prominent account balances |
| `h2Sans` | Sans-Serif | 20px | `w500` | Card headers & modal section titles |
| `bodySans` | Sans-Serif | 16px | `w400` | Primary UI text, form labels, inputs |
| `bodyMono` | Monospace | 16px | `w400` | Tabular figures; transaction amounts, rates |
| `captionSans` | Sans-Serif | 14px | `w400` | Subtitles, field hints, secondary text |
| `smallSans` | Sans-Serif | 13px | `w500` | Pills, status labels, tooltips |
| `smallMono` | Monospace | 13px | `w400` | Tabular figures; dates, deltas, SKU numbers |

---

## 🌍 Language & Localization (`LanguageCubit`)

- **Supported Languages**: Russian (`ru`) and Tajik (`tg`).
- **Catalog files** (keep keys symmetric):
  - `lib/core/localization/catalogs/ru_catalog.dart`
  - `lib/core/localization/catalogs/tg_catalog.dart`
  - `lib/core/localization/catalogs/tajik_runtime_messages.dart` (RU→TG runtime message map)
- **Translations**: All UI strings must be localized via `LanguageCubit` (`translate`, `translateMessage`, or `resolveMessage`).
- **Error keys**: Prefer stable keys (`error_timeout`, `error_session_expired`, …) from `ErrorKeys` — never show raw Dio/stack traces.
- **Key Pattern**: `feature_key` (e.g., `cash_new_operation_btn`, `warehouse_tab_products`).
- **Dynamic Messages**: Server errors and formatted messages are localized using `translateMessage(msg)` with `{param}` substitution.

### 🔢 Number & Date Formatting Guidelines
- **Formatting Numbers**: Use `formatLocalizedNumber(context, amount)` or `localizedDecimalFormat(context).format(amount)`.
- **Parsing Number Inputs**: Always parse user text inputs using `parseLocalizedNumber(context, text)` (handles both `,` and `.` decimal separators safely).
- **Formatting Dates**: Use `formatLocalizedDateTime(context, dateTime, style: LocalizedDateTimeStyle.dateTime)`.

---

## 📦 Reusable System Widgets (`lib/presentation/widgets/`)

### 1. `LedgerCard` (`ledger_card.dart`)
- **Purpose**: Standard flat container for all list items and content blocks.
- **Styling**: `16px` border radius, `1px` border (`border`), `surface` background color, zero elevation/shadow.
- **Parameters**: `required child`, `padding` (default `all(16)`), `backgroundColor`, `borderColor`.

### 2. `LedgerPill` (`ledger_pill.dart`)
- **Purpose**: Status capsules and badges.
- **Styling**: `999px` full border radius, `smallSans` `w500` font.
- **Parameters**: `required text`, `required backgroundColor`, `required textColor`, `fontSize` (default `10`), `padding` (default `h: 8, v: 2`).

### 3. `LedgerAICard` (`ledger_ai_card.dart`)
- **Purpose**: AI insights, recommendations, and warnings.
- **Styling**: `accentAmber` 1px border, `16px` radius, internal vertical amber indicator line (`4px` width, `16px` height).
- **Parameters**: `required title`, `required content`, `trailing`.

### 4. `LedgerBottomSheet` (`ledger_bottom_sheet.dart`)
- **Purpose**: System modal bottom sheet for all forms and actions.
- **Styling**: `24px` top border radius, top drag handle (`32x3px`), 1.5px border, maximum height limit `92%` of screen.
- **Static API**:
  - `LedgerBottomSheet.show<T>({required context, required title, required builder, footerBuilder, isDismissible, enableDrag})`
  - `LedgerBottomSheet.confirmDiscard(context)`: Standard confirmation alert dialog before discarding unsaved form changes.

### 5. `LedgerOperationRow` (`ledger_operation_row.dart`)
- **Purpose**: Transaction and activity list row item.
- **Styling**: Left title in `bodySans` `w500`, category in `captionSans`, optional status pill, right amount in `bodyMono` `w500` (`accentGreen` for income, `accentRed` for expense).
- **Parameters**: `required title`, `required category`, `required amount`, `required isIncome`, `pillText`, `pillColor`, `pillTextColor`, `onTap`.

### 6. `LedgerCollapsingHeader` (`ledger_collapsing_header.dart`)
- **Purpose**: Standard `SliverAppBar` header across all module screens.
- **Features**: Pinned and floating by default. Responsive font sizing (24px desktop/tablet, 22px mobile) with clamped text scaling (`0.85..1.15`). Supports actions and tab bar `bottom`.
- **Parameters**: `required title`, `titleWidget`, `actions`, `bottom`, `expandedHeight`, `pinned`, `floating`, `snap`.

### 7. `ExpansibleWidget<T>` (`expansible_widget.dart`)
- **Purpose**: Accordion cards and selection dropdown pickers.
- **Variants**:
  - `ExpansibleWidget({...})`: Expands to reveal custom `children` list with dividers.
  - `ExpansibleWidget.selection({...})`: Selection picker with radio-like checkmarks. Automatically enables top search input when `items.length > 12`.
- **Parameters**: `title`, `subtitle`, `cardPadding`, `tilePadding`, `controller`, `initiallyExpanded`, plus selection parameters (`items`, `selectedValue`, `itemLabelBuilder`, `onSelected`).

### 8. `BottomActionWrapper` (`bottom_action_wrapper.dart`)
- **Purpose**: Sticky bottom button bar container.
- **Styling**: Protects full-width primary action buttons from bottom iPhone notch/home bar using `SafeArea(top: false)` with `horizontal: 20, vertical: 12` padding.
- **Parameters**: `required child`, `backgroundColor`.

### 9. `PaykLogo` (`payk_logo.dart`)
- **Purpose**: Module and app branding logo.
- **Fallback**: Displays `assets/images/payk_logo_transparent.png`, or a styled `P` brand badge + `PAYK` text fallback.
- **Parameters**: `height` (default `26.0`), `color`.

---

## 🛠 Architectural & Coding Rules

- **No Hardcoding**: Never use direct `Color(0xFF...)` or manual `TextStyle(...)` in feature views. Access styles strictly through `context.colors` and `context.textStyles`.
- **Tab-Aware Floating Buttons**: Always attach `_tabController.addListener(_handleTabChange)` when using `FloatingActionButton.extended` so that buttons switch dynamically during gesture swipes as well as tab taps.
- **Button Label Cleanliness**: Never include a leading `+` symbol in `label` text when `icon: Icon(TablerIcons.plus)` is specified.
- **Component Reuse**: Always check `lib/presentation/widgets/` for suitable components before creating custom layouts.
- **Clean Architecture**: Strictly separate Domain, Data, and BLoC/Presentation layers.
