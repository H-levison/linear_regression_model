import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// Local development URL.
// - iOS Simulator / desktop: use 'http://localhost:8000'
// - Android Emulator:        use 'http://10.0.2.2:8000'
// - Physical device:         use your machine's local IP, e.g. 'http://192.168.1.x:8000'
const String kApiBaseUrl = 'https://linear-regression-model-4w14.onrender.com';

void main() {
  runApp(const BitcoinPredictorApp());
}

class BitcoinPredictorApp extends StatelessWidget {
  const BitcoinPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BTC Price Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF7931A), // Bitcoin orange
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFF7931A), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        ),
      ),
      home: const PredictorPage(),
    );
  }
}

class PredictorPage extends StatefulWidget {
  const PredictorPage({super.key});

  @override
  State<PredictorPage> createState() => _PredictorPageState();
}

class _PredictorPageState extends State<PredictorPage> {
  final _formKey = GlobalKey<FormState>();

  final _sp500Controller        = TextEditingController();
  final _goldController         = TextEditingController();
  final _dxyController          = TextEditingController();
  final _fngController          = TextEditingController();
  final _hashRateController     = TextEditingController();
  final _trendsController       = TextEditingController();
  final _volumeController       = TextEditingController();

  String?  _result;
  bool     _isLoading = false;
  bool     _hasError  = false;

  @override
  void dispose() {
    _sp500Controller.dispose();
    _goldController.dispose();
    _dxyController.dispose();
    _fngController.dispose();
    _hashRateController.dispose();
    _trendsController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _result    = null;
      _hasError  = false;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$kApiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sp500_close':          double.parse(_sp500Controller.text.trim()),
              'gold_close':           double.parse(_goldController.text.trim()),
              'dxy_close':            double.parse(_dxyController.text.trim()),
              'fng_score':            int.parse(_fngController.text.trim()),
              'hash_rate':            double.parse(_hashRateController.text.trim()),
              'google_trends_score':  int.parse(_trendsController.text.trim()),
              'volume':               double.parse(_volumeController.text.trim()),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body) as Map<String, dynamic>;
        final price = (data['predicted_close_usd'] as num).toDouble();
        setState(() {
          _result   = '\$${price.toStringAsFixed(2)}';
          _hasError = false;
        });
      } else {
        final body = jsonDecode(response.body);
        final msg  = body['detail'] ?? 'Prediction failed (${response.statusCode}).';
        setState(() {
          _result   = msg is List ? (msg as List).map((e) => e['msg']).join('\n') : msg.toString();
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _result   = 'Could not reach the server. Check your connection or the API URL.';
        _hasError = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/4/46/Bitcoin.svg',
              height: 26,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.currency_bitcoin,
                color: Color(0xFFF7931A),
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BTC Price Predictor',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('Market Indicators'),
                const SizedBox(height: 12),
                _InputField(
                  controller: _sp500Controller,
                  label: 'S&P 500 Close',
                  hint: 'e.g. 4500.00',
                  suffix: 'USD',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateFloat(v, min: 2000, max: 7000,
                      label: 'S&P 500 Close'),
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _goldController,
                  label: 'Gold Close Price',
                  hint: 'e.g. 1950.00',
                  suffix: 'USD/oz',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateFloat(v, min: 1000, max: 4000,
                      label: 'Gold Close'),
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _dxyController,
                  label: 'US Dollar Index (DXY)',
                  hint: 'e.g. 103.50',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateFloat(v, min: 75, max: 130,
                      label: 'DXY'),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Sentiment Indicators'),
                const SizedBox(height: 12),
                _InputField(
                  controller: _fngController,
                  label: 'Fear & Greed Index',
                  hint: '0 (extreme fear) – 100 (extreme greed)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => _validateInt(v, min: 0, max: 100,
                      label: 'Fear & Greed Index'),
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _trendsController,
                  label: 'Google Trends Score',
                  hint: '0 – 100',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => _validateInt(v, min: 0, max: 100,
                      label: 'Google Trends Score'),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Network & Volume'),
                const SizedBox(height: 12),
                _InputField(
                  controller: _hashRateController,
                  label: 'Bitcoin Hash Rate',
                  hint: 'e.g. 450.00',
                  suffix: 'EH/s',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateFloat(v, min: 50, max: 1500,
                      label: 'Hash Rate'),
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _volumeController,
                  label: '24h Trading Volume',
                  hint: 'e.g. 25000000000',
                  suffix: 'USD',
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateVolume(v),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _predict,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF7931A),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFF7A4A0D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Predict',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_result != null) _ResultCard(result: _result!, isError: _hasError),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateFloat(String? v, {required double min, required double max, required String label}) {
    if (v == null || v.trim().isEmpty) return '$label is required.';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Enter a valid number.';
    if (parsed < min || parsed > max) return '$label must be between $min and $max.';
    return null;
  }

  String? _validateInt(String? v, {required int min, required int max, required String label}) {
    if (v == null || v.trim().isEmpty) return '$label is required.';
    final parsed = int.tryParse(v.trim());
    if (parsed == null) return 'Enter a whole number.';
    if (parsed < min || parsed > max) return '$label must be between $min and $max.';
    return null;
  }

  String? _validateVolume(String? v) {
    if (v == null || v.trim().isEmpty) return 'Trading volume is required.';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Enter a valid number.';
    if (parsed < 1e8 || parsed > 1e12) return 'Volume must be between 100,000,000 and 1,000,000,000,000.';
    return null;
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFF7931A),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? suffix;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.suffix,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5A5A5A), fontSize: 13),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
      ),
      validator: validator,
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String result;
  final bool isError;

  const _ResultCard({required this.result, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.redAccent : const Color(0xFFF7931A);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.show_chart,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isError ? 'Error' : 'Predicted Close Price',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result,
            style: TextStyle(
              color: isError ? Colors.redAccent.shade100 : Colors.white,
              fontSize: isError ? 14 : 28,
              fontWeight: isError ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          if (!isError) ...[
            const SizedBox(height: 6),
            const Text(
              'Random Forest · Daily close estimate',
              style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
