import 'package:flutter/material.dart';

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
  }) async {
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
  double _operand = 0;
  String? _operator;
  bool _freshEntry = false;
  bool _hasDecimal = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue > 0) {
      _display = _fmt(widget.initialValue);
      _operand = widget.initialValue;
    }
  }

  void _onKey(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _display = '0';
          _operand = 0;
          _operator = null;
          _freshEntry = false;
          _hasDecimal = false;

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
          final current = double.tryParse(_display) ?? 0;
          _display = _fmt(current / 100);
          _freshEntry = true;
          _hasDecimal = _display.contains('.');

        case '=':
          _calculate();

        case '+':
        case '-':
        case '×':
        case '÷':
          _applyOperator(key);

        default:
          if (_freshEntry) {
            _display = key;
            _freshEntry = false;
            _hasDecimal = false;
          } else {
            if (_display == '0') {
              _display = key;
            } else if (_display.length < 15) {
              _display = '$_display$key';
            }
          }
      }
    });
  }

  void _applyOperator(String op) {
    if (_operator != null && !_freshEntry) {
      _calculate();
    } else {
      _operand = double.tryParse(_display) ?? 0;
    }
    _operator = op;
    _freshEntry = true;
    _hasDecimal = false;
  }

  void _calculate() {
    if (_operator == null) return;
    final right = double.tryParse(_display) ?? 0;
    double result;

    switch (_operator) {
      case '+':
        result = _operand + right;
      case '-':
        result = _operand - right;
      case '×':
        result = _operand * right;
      case '÷':
        result = right == 0 ? 0 : _operand / right;
      default:
        result = right;
    }

    if (result < 0) result = 0;
    if (result > AppConstants.maxTransactionAmount) {
      result = AppConstants.maxTransactionAmount;
    }

    _operand = result;
    _display = _fmt(result);
    _operator = null;
    _freshEntry = true;
    _hasDecimal = _display.contains('.');
  }

  String _fmt(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    String s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    return s;
  }

  double get _currentValue => double.tryParse(_display) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_operator != null)
                  Text(
                    '${_fmt(_operand)} $_operator',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                Text(
                  _display,
                  style: AppTextStyles.amountLarge,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildKeypad(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_operator != null) _calculate();
                final val = _currentValue;
                if (val > 0) {
                  widget.onConfirm(
                      double.parse(val.toStringAsFixed(2)));
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    const rows = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['%', '0', '.', '+'],
      ['C', '⌫', '', '='],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              if (key.isEmpty) {
                return const Expanded(child: SizedBox());
              }
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _CalcKey(
                    label: key,
                    onTap: () => _onKey(key),
                    type: _keyType(key),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  _KeyType _keyType(String key) {
    if (key == '=') return _KeyType.equals;
    if (key == 'C') return _KeyType.clear;
    if (key == '⌫') return _KeyType.delete;
    if (key == '+' ||
        key == '-' ||
        key == '×' ||
        key == '÷' ||
        key == '%') {
      return _KeyType.operator;
    }
    return _KeyType.digit;
  }
}

enum _KeyType { digit, operator, equals, clear, delete }

class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.label,
    required this.onTap,
    required this.type,
  });

  final String label;
  final VoidCallback onTap;
  final _KeyType type;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case _KeyType.equals:
        bg = AppColors.primary;
        fg = Colors.white;
      case _KeyType.operator:
        bg = AppColors.primary.withValues(alpha: 0.1);
        fg = AppColors.primary;
      case _KeyType.clear:
        bg = AppColors.savingsLight;
        fg = AppColors.savings;
      case _KeyType.delete:
        bg = AppColors.expenseLight;
        fg = AppColors.expense;
      case _KeyType.digit:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.titleLarge.copyWith(color: fg),
        ),
      ),
    );
  }
}