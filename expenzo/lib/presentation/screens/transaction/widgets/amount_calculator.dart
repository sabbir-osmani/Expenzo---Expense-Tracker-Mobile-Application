import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AmountCalculator extends StatefulWidget {
  const AmountCalculator({
    super.key,
    required this.initialValue,
    required this.onConfirm,
  });

  final double initialValue;
  final ValueChanged<double> onConfirm;

  static Future<double?> show(
    BuildContext context, {
    double initialValue = 0,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AmountCalculator(
        initialValue: initialValue,
        onConfirm: (v) => Navigator.of(context).pop(v),
      ),
    );
  }

  @override
  State<AmountCalculator> createState() => _AmountCalculatorState();
}

class _AmountCalculatorState extends State<AmountCalculator> {
  String _display = '0';
  int _operandPaise = 0; // integer paise to avoid float drift
  String? _operator;
  bool _freshEntry = false;
  bool _hasDecimal = false;
  String _hint = ''; // shows e.g. "5,000 +"

  @override
  void initState() {
    super.initState();
    if (widget.initialValue > 0) {
      _display = _fmt(widget.initialValue);
      _operandPaise = _toPaise(widget.initialValue);
    }
  }

  static int _toPaise(double v) => (v * 100).round();
  static double _fromPaise(int p) => p / 100.0;

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    String s = v.toStringAsFixed(2);
    s = s.replaceAll(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  double get _currentValue => double.tryParse(_display) ?? 0;

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (k) {
        case 'C':
          _display = '0';
          _operandPaise = 0;
          _operator = null;
          _freshEntry = false;
          _hasDecimal = false;
          _hint = '';
        case '⌫':
          if (_display.length <= 1) {
            _display = '0';
            _hasDecimal = false;
          } else {
            if (_display.endsWith('.')) _hasDecimal = false;
            _display = _display.substring(0, _display.length - 1);
          }
        case '.':
          if (_freshEntry) {
            _display = '0.';
            _freshEntry = false;
            _hasDecimal = true;
          } else if (!_hasDecimal) {
            _display = '$_display.';
            _hasDecimal = true;
          }
        case '%':
          final v = _currentValue / 100;
          _display = _fmt(v);
          _freshEntry = true;
          _hasDecimal = _display.contains('.');
        case '=':
          _calc();
        case '+': case '-': case '×': case '÷':
          _applyOp(k);
        default:
          if (_freshEntry) {
            _display = k;
            _freshEntry = false;
            _hasDecimal = false;
          } else {
            _display = (_display == '0') ? k
                : (_display.length < 13 ? '$_display$k' : _display);
          }
      }
    });
  }

  void _applyOp(String op) {
    if (_operator != null && !_freshEntry) {
      _calc(keepOp: true);
    } else {
      _operandPaise = _toPaise(_currentValue);
    }
    _hint = '${_fmt(_fromPaise(_operandPaise))} $op';
    _operator = op;
    _freshEntry = true;
    _hasDecimal = false;
  }

  void _calc({bool keepOp = false}) {
    if (_operator == null) return;
    final l = _operandPaise;
    final r = _toPaise(_currentValue);
    int result;
    switch (_operator) {
      case '+': result = l + r;
      case '-': result = l - r;
      case '×': result = ((_fromPaise(l)) * _currentValue * 100).round();
      case '÷': result = _currentValue == 0 ? 0 : ((_fromPaise(l) / _currentValue) * 100).round();
      default:  result = r;
    }
    if (result < 0) result = 0;
    final max = _toPaise(AppConstants.maxTransactionAmount);
    if (result > max) result = max;
    _operandPaise = result;
    _display = _fmt(_fromPaise(result));
    if (!keepOp) { _hint = ''; _operator = null; }
    _freshEntry = true;
    _hasDecimal = _display.contains('.');
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _currentValue > 0;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Display
          _buildDisplay(),
          const SizedBox(height: 16),

          // Keys
          _buildKeys(),
          const SizedBox(height: 14),

          // Confirm
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isValid
                  ? () {
                      HapticFeedback.mediumImpact();
                      widget.onConfirm(double.parse(_currentValue.toStringAsFixed(2)));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isValid ? 'Confirm' : 'Enter Amount',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isValid ? Colors.white : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _currentValue > 0 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pending operation hint
          if (_hint.isNotEmpty)
            Text(_hint,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          // Main number
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _display,
              style: AppTextStyles.amountLarge.copyWith(
                fontSize: 36,
                color: _currentValue > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeys() {
    const rows = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['%', '0', '.', '+'],
    ];

    return Column(
      children: [
        ...rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: row.map((k) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Key(label: k, type: _kType(k), onTap: () => _key(k)),
            ),
          )).toList()),
        )),
        // Bottom row: C (wide), ⌫, =
        Row(children: [
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Key(label: 'C', type: _KeyType.clear, onTap: () => _key('C')),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Key(label: '⌫', type: _KeyType.delete, onTap: () => _key('⌫')),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Key(label: '=', type: _KeyType.equals, onTap: () => _key('=')),
          )),
        ]),
      ],
    );
  }

  _KeyType _kType(String k) {
    if (k == '=') return _KeyType.equals;
    if (k == 'C') return _KeyType.clear;
    if (k == '⌫') return _KeyType.delete;
    if ('+-×÷%'.contains(k)) return _KeyType.operator;
    return _KeyType.digit;
  }
}

enum _KeyType { digit, operator, equals, clear, delete }

class _Key extends StatefulWidget {
  const _Key({required this.label, required this.type, required this.onTap});
  final String label;
  final _KeyType type;
  final VoidCallback onTap;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (widget.type) {
      case _KeyType.equals:
        bg = _pressed ? AppColors.primaryDark : AppColors.primary;
        fg = Colors.white;
      case _KeyType.operator:
        bg = _pressed
            ? AppColors.primaryLight.withValues(alpha: 0.25)
            : AppColors.primaryLight.withValues(alpha: 0.12);
        fg = AppColors.primary;
      case _KeyType.clear:
        bg = _pressed
            ? AppColors.savingsLight
            : AppColors.savings.withValues(alpha: 0.1);
        fg = AppColors.savings;
      case _KeyType.delete:
        bg = _pressed ? AppColors.expenseLight : AppColors.expense.withValues(alpha: 0.08);
        fg = AppColors.expense;
      case _KeyType.digit:
        bg = _pressed ? AppColors.border : AppColors.surfaceVariant;
        fg = AppColors.textPrimary;
    }

    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 54,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: widget.type == _KeyType.digit
              ? Border.all(color: AppColors.border.withValues(alpha: 0.5))
              : null,
        ),
        alignment: Alignment.center,
        child: widget.label == '⌫'
            ? Icon(Icons.backspace_outlined, color: fg, size: 20)
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.type == _KeyType.digit ? 21 : 19,
                  fontWeight: widget.type == _KeyType.digit
                      ? FontWeight.w500
                      : FontWeight.w600,
                  color: fg,
                ),
              ),
      ),
    );
  }
}