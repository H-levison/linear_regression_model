import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String kApiBaseUrl = 'https://linear-regression-model-4w14.onrender.com';

// ── Palette ────────────────────────────────────────────────────────────────
const _bg      = Color(0xFF080808);
const _card    = Color(0xFF161616);
const _orange  = Color(0xFFF7931A);
const _amber   = Color(0xFFFFB347);
const _dim     = Color(0xFF2A2A2A);
const _muted   = Color(0xFF4A4A4A);
const _textSub = Color(0xFF666666);
const _green   = Color(0xFF22C55E);
const _red     = Color(0xFFEF4444);

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BTC Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        splashColor: _orange.withOpacity(0.08),
        highlightColor: Colors.transparent,
      ),
      home: const PredictorPage(),
    );
  }
}

// ── Page ───────────────────────────────────────────────────────────────────
class PredictorPage extends StatefulWidget {
  const PredictorPage({super.key});
  @override
  State<PredictorPage> createState() => _PredictorPageState();
}

class _PredictorPageState extends State<PredictorPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _sp500  = TextEditingController();
  final _gold   = TextEditingController();
  final _dxy    = TextEditingController();
  final _fng    = TextEditingController();
  final _hash   = TextEditingController();
  final _trends = TextEditingController();
  final _volume = TextEditingController();

  // Focus nodes for keyboard auto-advance
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _f3 = FocusNode();
  final _f4 = FocusNode();
  final _f5 = FocusNode();
  final _f6 = FocusNode();
  final _f7 = FocusNode();

  String? _result;
  bool    _loading  = false;
  bool    _hasError = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    for (final c in [_sp500, _gold, _dxy, _fng, _hash, _trends, _volume]) {
      c.dispose();
    }
    for (final f in [_f1, _f2, _f3, _f4, _f5, _f6, _f7]) {
      f.dispose();
    }
    super.dispose();
  }

  void _loadSample() {
    _sp500.text  = '5300.00';
    _gold.text   = '2350.00';
    _dxy.text    = '104.20';
    _fng.text    = '72';
    _hash.text   = '620.00';
    _trends.text = '58';
    _volume.text = '38000000000';
    HapticFeedback.lightImpact();
    // Trigger validation on all fields after filling
    _formKey.currentState?.validate();
  }

  void _clearAll() {
    for (final c in [_sp500, _gold, _dxy, _fng, _hash, _trends, _volume]) {
      c.clear();
    }
    setState(() { _result = null; _hasError = false; });
    HapticFeedback.lightImpact();
  }

  Future<void> _predict() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }
    setState(() { _loading = true; _result = null; _hasError = false; });

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sp500_close':         double.parse(_sp500.text.trim()),
          'gold_close':          double.parse(_gold.text.trim()),
          'dxy_close':           double.parse(_dxy.text.trim()),
          'fng_score':           int.parse(_fng.text.trim()),
          'hash_rate':           double.parse(_hash.text.trim()),
          'google_trends_score': int.parse(_trends.text.trim()),
          'volume':              double.parse(_volume.text.trim()),
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final price = (jsonDecode(res.body)['predicted_close_usd'] as num).toDouble();
        HapticFeedback.lightImpact();
        setState(() { _result = price.toStringAsFixed(2); _hasError = false; });
      } else {
        final detail = jsonDecode(res.body)['detail'];
        final msg    = detail is List
            ? (detail as List).map((e) => e['msg']).join('\n')
            : detail?.toString() ?? 'Prediction failed.';
        setState(() { _result = msg; _hasError = true; });
      }
    } catch (_) {
      setState(() {
        _result   = 'Could not reach the server.\nCheck your connection.';
        _hasError = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              loading: _loading,
              pulseCtrl: _pulseCtrl,
              onClear: _clearAll,
              onSample: _loadSample,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Result card
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.06),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _result != null
                            ? _ResultCard(
                                key: ValueKey(_result),
                                value: _result!,
                                isError: _hasError,
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (_result != null) const SizedBox(height: 20),

                      // Input card
                      Container(
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _dim),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              _sectionTag('Market Indicators'),
                              _FieldRow(
                                icon: Icons.show_chart_rounded,
                                label: 'S&P 500 Close',
                                unit: 'USD',
                                hint: '4500.00',
                                rangeHint: '2,000 – 7,000',
                                controller: _sp500,
                                focusNode: _f1,
                                nextFocus: _f2,
                                keyboard: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => _vFloat(v, 2000, 7000, 'S&P 500'),
                              ),
                              _divider(),
                              _FieldRow(
                                icon: Icons.bar_chart_rounded,
                                label: 'Gold Close',
                                unit: 'USD/oz',
                                hint: '1950.00',
                                rangeHint: '1,000 – 4,000',
                                controller: _gold,
                                focusNode: _f2,
                                nextFocus: _f3,
                                keyboard: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => _vFloat(v, 1000, 4000, 'Gold'),
                              ),
                              _divider(),
                              _FieldRow(
                                icon: Icons.attach_money_rounded,
                                label: 'Dollar Index (DXY)',
                                hint: '103.50',
                                rangeHint: '75 – 130',
                                controller: _dxy,
                                focusNode: _f3,
                                nextFocus: _f4,
                                keyboard: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => _vFloat(v, 75, 130, 'DXY'),
                              ),
                              _sectionTag('Sentiment'),
                              _FieldRow(
                                icon: Icons.sentiment_neutral_rounded,
                                label: 'Fear & Greed',
                                hint: '0 – 100',
                                rangeHint: 'fear ←  → greed',
                                controller: _fng,
                                focusNode: _f4,
                                nextFocus: _f5,
                                keyboard: TextInputType.number,
                                formatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (v) => _vInt(v, 0, 100, 'Fear & Greed'),
                                showProgress: true,
                                progressMax: 100,
                              ),
                              _divider(),
                              _FieldRow(
                                icon: Icons.trending_up_rounded,
                                label: 'Google Trends',
                                hint: '0 – 100',
                                rangeHint: 'low ←  → viral',
                                controller: _trends,
                                focusNode: _f5,
                                nextFocus: _f6,
                                keyboard: TextInputType.number,
                                formatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (v) => _vInt(v, 0, 100, 'Google Trends'),
                                showProgress: true,
                                progressMax: 100,
                              ),
                              _sectionTag('Network & Volume'),
                              _FieldRow(
                                icon: Icons.memory_rounded,
                                label: 'Hash Rate',
                                unit: 'EH/s',
                                hint: '450.00',
                                rangeHint: '50 – 1,500',
                                controller: _hash,
                                focusNode: _f6,
                                nextFocus: _f7,
                                keyboard: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => _vFloat(v, 50, 1500, 'Hash Rate'),
                              ),
                              _divider(),
                              _FieldRow(
                                icon: Icons.swap_horiz_rounded,
                                label: '24h Volume',
                                unit: 'USD',
                                hint: '25000000000',
                                rangeHint: '100M – 1T',
                                controller: _volume,
                                focusNode: _f7,
                                isLast: true,
                                onSubmit: _predict,
                                keyboard: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => _vVolume(v),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _PredictButton(loading: _loading, onTap: _predict),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTag(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _orange,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: _dim, height: 1)),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: _dim, indent: 52);

  String? _vFloat(String? v, double min, double max, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = double.tryParse(v.trim());
    if (n == null) return 'Enter a valid number';
    if (n < min || n > max) return 'Must be between $min and $max';
    return null;
  }

  String? _vInt(String? v, int min, int max, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Whole number required';
    if (n < min || n > max) return 'Must be between $min and $max';
    return null;
  }

  String? _vVolume(String? v) {
    if (v == null || v.trim().isEmpty) return 'Volume is required';
    final n = double.tryParse(v.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 1e8 || n > 1e12) return 'Must be between 100,000,000 and 1,000,000,000,000';
    return null;
  }
}

// ── Header ─────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool loading;
  final AnimationController pulseCtrl;
  final VoidCallback onClear;
  final VoidCallback onSample;

  const _Header({
    required this.loading,
    required this.pulseCtrl,
    required this.onClear,
    required this.onSample,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orange.withOpacity(0.25)),
            ),
            child: const Icon(Icons.currency_bitcoin, color: _orange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bitcoin Price Predictor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'ML-powered · Random Forest',
                  style: TextStyle(color: _textSub, fontSize: 11.5),
                ),
              ],
            ),
          ),
          // Status dot
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: loading
                    ? _orange.withOpacity(0.4 + pulseCtrl.value * 0.6)
                    : _green,
                boxShadow: [
                  BoxShadow(
                    color: (loading ? _orange : _green).withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Sample button
          _IconChip(
            icon: Icons.bolt_rounded,
            label: 'Sample',
            onTap: onSample,
          ),
          const SizedBox(width: 8),
          // Clear button
          _IconChip(
            icon: Icons.refresh_rounded,
            label: 'Clear',
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _dim),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _textSub),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: _textSub, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Field row ──────────────────────────────────────────────────────────────
class _FieldRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String hint;
  final String rangeHint;
  final String? unit;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final bool isLast;
  final VoidCallback? onSubmit;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final bool showProgress;
  final int progressMax;

  const _FieldRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.rangeHint,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    this.unit,
    this.nextFocus,
    this.isLast = false,
    this.onSubmit,
    this.formatters,
    this.validator,
    this.showProgress = false,
    this.progressMax = 100,
  });

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool    _focused  = false;
  String? _error;
  String  _value    = '';

  void _onChanged(String val) {
    setState(() {
      _value = val;
      // Only show error after user has typed something
      if (val.isNotEmpty) {
        _error = widget.validator?.call(val);
      } else {
        _error = null;
      }
    });
  }

  double? get _progressValue {
    if (!widget.showProgress) return null;
    final n = int.tryParse(_value);
    if (n == null) return null;
    return (n / widget.progressMax).clamp(0.0, 1.0);
  }

  Color get _progressColor {
    final v = _progressValue;
    if (v == null) return _orange;
    if (v < 0.25) return const Color(0xFF3B82F6); // blue = fear
    if (v < 0.50) return const Color(0xFF22C55E); // green = neutral
    if (v < 0.75) return _amber;                  // amber = greedy
    return _red;                                   // red = extreme greed
  }

  bool get _hasError => _error != null && _error!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            color: _hasError
                ? _red.withOpacity(0.05)
                : _focused
                    ? _orange.withOpacity(0.04)
                    : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Icon badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _hasError
                        ? _red.withOpacity(0.15)
                        : _focused
                            ? _orange.withOpacity(0.15)
                            : _orange.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 15,
                    color: _hasError
                        ? _red
                        : _focused
                            ? _orange
                            : _textSub,
                  ),
                ),
                const SizedBox(width: 12),
                // Label + range hint
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: _hasError
                              ? _red.withOpacity(0.85)
                              : _focused
                                  ? Colors.white.withOpacity(0.9)
                                  : _textSub,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.rangeHint,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Text input
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: widget.keyboard,
                    inputFormatters: widget.formatters,
                    textAlign: TextAlign.right,
                    textInputAction: widget.isLast
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onFieldSubmitted: (_) {
                      if (widget.isLast) {
                        widget.onSubmit?.call();
                      } else {
                        widget.nextFocus?.requestFocus();
                      }
                    },
                    onChanged: _onChanged,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: TextStyle(
                      color: _hasError ? _red.shade200 : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                      suffixText: widget.unit,
                      suffixStyle: const TextStyle(
                        color: _textSub,
                        fontSize: 12,
                      ),
                      // Hide default error display — we handle it ourselves
                      errorStyle: const TextStyle(fontSize: 0, height: 0),
                    ),
                    validator: widget.validator,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Inline error text
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _hasError
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(52, 2, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 11, color: _red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: _red,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Progress bar for 0–100 score fields
        if (widget.showProgress && _value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(52, 0, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                child: LinearProgressIndicator(
                  value: _progressValue ?? 0,
                  backgroundColor: _dim,
                  valueColor: AlwaysStoppedAnimation(_progressColor),
                  minHeight: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Predict button ─────────────────────────────────────────────────────────
class _PredictButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _PredictButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: loading ? 0.75 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_orange, _amber],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _orange.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withOpacity(0.15),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Predict',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Result card ────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final String value;
  final bool isError;
  const _ResultCard({super.key, required this.value, required this.isError});

  @override
  Widget build(BuildContext context) {
    if (isError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _red.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _red.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: _red.withOpacity(0.9),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _orange.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PREDICTED',
                  style: TextStyle(
                    color: _orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              const Text('BTC / USD',
                  style: TextStyle(color: _textSub, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text(
                  '\$',
                  style: TextStyle(
                      color: _orange, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  _formatPrice(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _dim),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.memory_rounded, size: 13, color: _textSub),
              const SizedBox(width: 5),
              const Text('Random Forest Regressor',
                  style: TextStyle(color: _textSub, fontSize: 12)),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green,
                ),
              ),
              const SizedBox(width: 5),
              const Text('Daily close estimate',
                  style: TextStyle(color: _textSub, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPrice(String raw) {
    final n = double.tryParse(raw);
    if (n == null) return raw;
    final parts   = n.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final dec     = parts[1];
    final buffer  = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '$buffer.$dec';
  }
}

extension on Color {
  Color get shade200 => withOpacity(0.75);
}
