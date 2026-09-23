import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Поле формы, которое может случайно принять скан.
class ScanField {
  const ScanField(this.focus, this.controller);

  final FocusNode focus;
  final TextEditingController controller;
}

/// Ловит штрих-код со сканера-клавиатуры, где бы ни стоял курсор.
///
/// Скан отличаем от ручного ввода по скорости. Код всегда кладётся в поле
/// штрих-кода, а поле, куда цифры влетели по ошибке, получает прежнее значение.
/// У существующего товара [anywhere] выключен: скан принимается только в поле кода.
class LedgerScanCapture extends StatefulWidget {
  const LedgerScanCapture({
    super.key,
    required this.barcode,
    required this.barcodeFocus,
    required this.name,
    required this.nameFocus,
    required this.fields,
    this.anywhere = true,
    this.enabled = true,
    this.focusBarcodeOnStart = false,
  });

  final TextEditingController barcode;
  final FocusNode barcodeFocus;
  final TextEditingController name;
  final FocusNode nameFocus;
  final List<ScanField> fields;
  final bool anywhere;
  final bool enabled;
  final bool focusBarcodeOnStart;

  @override
  State<LedgerScanCapture> createState() => _LedgerScanCaptureState();
}

class _LedgerScanCaptureState extends State<LedgerScanCapture> {
  static const _maxGapMs = 100;
  static const _pauseMs = 350;
  static const _fastAvgMs = 50;
  static const _minLen = 8;
  static const _minLenSuffix = 6;

  String _chars = '';
  final List<int> _gaps = [];
  int _last = 0;
  TextEditingController? _target;
  String? _before;
  Timer? _pause;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    if (widget.focusBarcodeOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.barcodeFocus.requestFocus();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNameEnd();
      });
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  TextEditingController? get _focused {
    for (final field in widget.fields) {
      if (field.focus.hasFocus) return field.controller;
    }
    return null;
  }

  void _reset() {
    _pause?.cancel();
    _chars = '';
    _gaps.clear();
    _last = 0;
    _target = null;
    _before = null;
  }

  bool _qualifies({required bool withSuffix}) {
    if (_chars.isEmpty || _chars.contains(RegExp(r'\s'))) return false;
    final foreign = _target != null && _target != widget.barcode;
    if (foreign) {
      if (!RegExp(r'^\d+$').hasMatch(_chars) || _chars.length < _minLen) {
        return false;
      }
      if (withSuffix) return true;
      final avg = _gaps.isEmpty
          ? 0
          : _gaps.reduce((a, b) => a + b) / _gaps.length;
      return avg <= _fastAvgMs;
    }
    return _chars.length >= (withSuffix ? _minLenSuffix : _minLen);
  }

  void _commit() {
    final target = _target;
    final before = _before;
    final code = _chars;
    _reset();
    if (target != null && target != widget.barcode && before != null) {
      target.value = TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      );
    }
    widget.barcode.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    _focusNameEnd();
  }

  void _focusNameEnd() {
    widget.nameFocus.requestFocus();
    final end = widget.name.text.length;
    widget.name.selection = TextSelection.collapsed(offset: end);
  }

  bool _onKey(KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return false;
    }

    final focused = _focused;
    if (!widget.anywhere && focused != widget.barcode) {
      _reset();
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab) {
      final same = _target == focused;
      final fresh = same && now - _last <= _maxGapMs;
      if ((fresh && _qualifies(withSuffix: true)) ||
          (same && _qualifies(withSuffix: false))) {
        _commit();
        return true;
      }
      _reset();
      if (focused == widget.barcode) {
        _focusNameEnd();
        return true;
      }
      return false;
    }

    final char = event.character;
    if (char == null || char.length != 1) {
      _reset();
      return false;
    }

    if (_chars.isNotEmpty && (now - _last > _maxGapMs || _target != focused)) {
      _reset();
    }
    if (_chars.isEmpty) {
      _target = focused;
      _before = focused?.text;
    } else {
      _gaps.add(now - _last);
    }
    _chars += char;
    _last = now;

    _pause?.cancel();
    _pause = Timer(const Duration(milliseconds: _pauseMs), () {
      if (_qualifies(withSuffix: false)) {
        _commit();
      } else {
        _reset();
      }
    });
    return false;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
