import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_screen.dart';
import 'history_screen.dart';

/// Calculator disguise screen.
///
/// Looks and functions as a fully working calculator.
/// SECRET: Type [_secretCode] digit-by-digit, then press [=]
///         to unlock the evidence vault.
///
/// Default secret: "1234" — change before deployment!
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  // ── Secret Config ────────────────────────────────────────────────────
  //
  // Change this to any numeric sequence before shipping.
  // Users will enter these digits then press '=' to unlock.
  static const String _secretCode = '1234';

  // ── Calculator State ─────────────────────────────────────────────────
  String _display = '0';
  String _topDisplay = ''; // Shows previous operand + operator
  double _firstOperand = 0;
  String _operator = '';
  bool _waitingForSecond = false;
  bool _justCalculated = false;
  String _digitBuffer = ''; // Tracks digits for secret detection

  // ── Animation for unlock ─────────────────────────────────────────────
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ── Input Handlers ───────────────────────────────────────────────────

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      // Track digit buffer for secret detection (keep last N digits)
      _digitBuffer += digit;
      if (_digitBuffer.length > _secretCode.length) {
        _digitBuffer =
            _digitBuffer.substring(_digitBuffer.length - _secretCode.length);
      }

      if (_waitingForSecond) {
        _display = digit;
        _waitingForSecond = false;
      } else if (_display == '0' || _justCalculated) {
        _display = digit;
        _justCalculated = false;
      } else if (_display.length < 12) {
        _display += digit;
      }
    });
  }

  void _onDecimal() {
    HapticFeedback.lightImpact();
    _digitBuffer = ''; // Decimal breaks secret sequence
    setState(() {
      if (_waitingForSecond) {
        _display = '0.';
        _waitingForSecond = false;
        return;
      }
      if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _onOperator(String op) {
    HapticFeedback.mediumImpact();
    _digitBuffer = ''; // Operator breaks secret sequence
    setState(() {
      _firstOperand = double.tryParse(_display) ?? 0;
      _operator = op;
      _topDisplay = '${_formatResult(_firstOperand)} $op';
      _waitingForSecond = true;
      _justCalculated = false;
    });
  }

  void _onEquals() {
    HapticFeedback.mediumImpact();

    // ── Secret code check ──────────────────────────────────────────────
    if (_digitBuffer == _secretCode) {
      _unlockVault();
      return;
    }

    // ── Normal calculation ─────────────────────────────────────────────
    if (_operator.isEmpty || _waitingForSecond) return;

    final second = double.tryParse(_display) ?? 0;
    double result = 0;

    switch (_operator) {
      case '+':
        result = _firstOperand + second;
        break;
      case '−':
        result = _firstOperand - second;
        break;
      case '×':
        result = _firstOperand * second;
        break;
      case '÷':
        result = second != 0 ? _firstOperand / second : double.nan;
        break;
    }

    setState(() {
      _topDisplay = '${_formatResult(_firstOperand)} $_operator ${_formatResult(second)} =';
      _display = result.isNaN ? 'Error' : _formatResult(result);
      _operator = '';
      _firstOperand = result;
      _justCalculated = true;
      _digitBuffer = '';
    });
  }

  void _onClear() {
    HapticFeedback.heavyImpact();
    setState(() {
      _display = '0';
      _topDisplay = '';
      _firstOperand = 0;
      _operator = '';
      _waitingForSecond = false;
      _justCalculated = false;
      _digitBuffer = '';
    });
  }

  void _onPlusMinus() {
    HapticFeedback.lightImpact();
    _digitBuffer = '';
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      _display = _formatResult(-val);
    });
  }

  void _onPercent() {
    HapticFeedback.lightImpact();
    _digitBuffer = '';
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      _display = _formatResult(val / 100);
    });
  }

  // ── Vault Unlock ─────────────────────────────────────────────────────

  void _unlockVault() {
    _onClear(); // Reset calculator display
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const ReportScreen(),
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _formatResult(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }
    // Up to 8 significant decimal places, trim trailing zeros
    final str = value.toStringAsFixed(8);
    return str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Hidden history button (long press top-right corner)
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onLongPress: _openHistory,
                child: const SizedBox(width: 60, height: 40),
              ),
            ),

            // ── Display ───────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Secondary line (previous operation)
                    AnimatedOpacity(
                      opacity: _topDisplay.isEmpty ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _topDisplay,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w300,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Main display — shakes on wrong input (future use)
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _display,
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Buttons ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Row 1
                  _buildRow([
                    _CalcBtn('AC', _onClear, type: _BtnType.function),
                    _CalcBtn('+/−', _onPlusMinus, type: _BtnType.function),
                    _CalcBtn('%', _onPercent, type: _BtnType.function),
                    _CalcBtn('÷', () => _onOperator('÷'),
                        type: _BtnType.operator,
                        active: _operator == '÷' && _waitingForSecond),
                  ]),
                  const SizedBox(height: 12),
                  // Row 2
                  _buildRow([
                    _CalcBtn('7', () => _onDigit('7')),
                    _CalcBtn('8', () => _onDigit('8')),
                    _CalcBtn('9', () => _onDigit('9')),
                    _CalcBtn('×', () => _onOperator('×'),
                        type: _BtnType.operator,
                        active: _operator == '×' && _waitingForSecond),
                  ]),
                  const SizedBox(height: 12),
                  // Row 3
                  _buildRow([
                    _CalcBtn('4', () => _onDigit('4')),
                    _CalcBtn('5', () => _onDigit('5')),
                    _CalcBtn('6', () => _onDigit('6')),
                    _CalcBtn('−', () => _onOperator('−'),
                        type: _BtnType.operator,
                        active: _operator == '−' && _waitingForSecond),
                  ]),
                  const SizedBox(height: 12),
                  // Row 4
                  _buildRow([
                    _CalcBtn('1', () => _onDigit('1')),
                    _CalcBtn('2', () => _onDigit('2')),
                    _CalcBtn('3', () => _onDigit('3')),
                    _CalcBtn('+', () => _onOperator('+'),
                        type: _BtnType.operator,
                        active: _operator == '+' && _waitingForSecond),
                  ]),
                  const SizedBox(height: 12),
                  // Row 5 — zero is wide
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildButton(
                          label: '0',
                          onTap: () => _onDigit('0'),
                          type: _BtnType.number,
                          wide: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildButton(
                          label: '.',
                          onTap: _onDecimal,
                          type: _BtnType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildButton(
                          label: '=',
                          onTap: _onEquals,
                          type: _BtnType.equals,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<_CalcBtn> buttons) {
    return Row(
      children: buttons.map((btn) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: btn == buttons.last ? 0 : 12,
            ),
            child: _buildButton(
              label: btn.label,
              onTap: btn.onTap,
              type: btn.type,
              active: btn.active,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    _BtnType type = _BtnType.number,
    bool wide = false,
    bool active = false,
  }) {
    Color bg;
    Color fg;

    switch (type) {
      case _BtnType.function:
        bg = const Color(0xFFA5A5A5);
        fg = Colors.black;
      case _BtnType.operator:
        bg = active ? Colors.white : const Color(0xFF00B4A6);
        fg = active ? const Color(0xFF00B4A6) : Colors.white;
      case _BtnType.equals:
        bg = const Color(0xFF00B4A6);
        fg = Colors.white;
      case _BtnType.number:
        bg = const Color(0xFF333333);
        fg = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 80,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(wide ? 40 : 40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: wide ? Alignment.centerLeft : Alignment.center,
        padding: wide ? const EdgeInsets.only(left: 30) : EdgeInsets.zero,
        child: Text(
          label,
          style: TextStyle(
            fontSize: label.length == 1 ? 34 : 24,
            fontWeight: FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Data helpers ─────────────────────────────────────────────────────────────

enum _BtnType { number, function, operator, equals }

class _CalcBtn {
  final String label;
  final VoidCallback onTap;
  final _BtnType type;
  final bool active;

  const _CalcBtn(
    this.label,
    this.onTap, {
    this.type = _BtnType.number,
    this.active = false,
  });
}
