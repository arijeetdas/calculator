// Final refinement per request
// 1. Light-mode buttons slightly darker
// 2. Bigger calculation / expected output / result text
// 3. Added About button near theme toggle
// 4. Added About screen UI (profile image placeholder, details, buttons)
// 5. NOTHING else changed

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  )) {
    throw 'Could not launch $url';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const CalculatorApp());
}

class CalculatorApp extends StatefulWidget {
  const CalculatorApp({super.key});

  @override
  State<CalculatorApp> createState() => _CalculatorAppState();
}

class _CalculatorAppState extends State<CalculatorApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: CalculatorScreen(onToggleTheme: toggleTheme, themeMode: _themeMode),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const CalculatorScreen({super.key, required this.onToggleTheme, required this.themeMode});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String expression = '';
  String liveResult = '';
  bool isFinalized = false;

  List<String> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      history = prefs.getStringList('history') ?? [];
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', history);
  }

  

  bool _endsWithOperator() {
    if (expression.isEmpty) return true;
    return '+-×÷%('.contains(expression.characters.last);
  }

  bool _hasOperator() => RegExp(r'[+\-×÷%]').hasMatch(expression);

  void _updateLiveResult() {
    if (expression.isEmpty) {
      liveResult = '';
      return;
    }

    String evalExp = expression;
    if (_endsWithOperator()) {
      evalExp = expression.substring(0, expression.length - 1);
    }

    if (!_hasOperator()) {
      liveResult = evalExp;
      return;
    }

    try {
      liveResult = _evaluate(evalExp);
    } catch (_) {
      liveResult = '';
    }
  }

  void onButtonPress(String v) {
    setState(() {
      if (v == 'AC') {
        expression = '';
        liveResult = '';
        isFinalized = false;
        return;
      }

      if (v == '⌫') {
        if (expression.isNotEmpty && !isFinalized) {
          expression = expression.substring(0, expression.length - 1);
          _updateLiveResult();
        }
        return;
      }

      if (v == '=') {
        if (expression.isEmpty || !_hasOperator()) return;
        final result = _evaluate(expression);
        history.insert(0, '$expression = $result');
        _saveHistory();
        expression = result;
        liveResult = '';
        isFinalized = true;
        return;
      }

      if (isFinalized && '0123456789.'.contains(v)) {
        expression = v;
        isFinalized = false;
      } else if (isFinalized) {
        isFinalized = false;
      }

      if ('+−×÷%'.contains(v)) {
        if (expression.isEmpty || _endsWithOperator()) return;
        expression += v;
      } else if (v == '( )') {
        expression += expression.isEmpty || _endsWithOperator() ? '(' : ')';
      } else {
        expression += v;
      }

      _updateLiveResult();
    });
  }

  String _evaluate(String exp) {
    exp = exp.replaceAll('×', '*').replaceAll('÷', '/');
    final tokens = RegExp(r'(-?\d+\.?\d*)|[+\-*/%()]')
        .allMatches(exp)
        .map((m) => m.group(0)!)
        .toList();

    final output = <String>[];
    final stack = <String>[];
    final prec = {'+': 1, '-': 1, '*': 2, '/': 2, '%': 2};

    for (final t in tokens) {
      if (double.tryParse(t) != null) {
        output.add(t);
      } else if (prec.containsKey(t)) {
        while (stack.isNotEmpty && prec.containsKey(stack.last) && prec[stack.last]! >= prec[t]!) {
          output.add(stack.removeLast());
        }
        stack.add(t);
      } else if (t == '(') {
        stack.add(t);
      } else if (t == ')') {
        while (stack.last != '(') {
          output.add(stack.removeLast());
        }
        stack.removeLast();
      }
    }

    while (stack.isNotEmpty) {
      output.add(stack.removeLast());
    }

    final eval = <double>[];
    for (final t in output) {
      if (double.tryParse(t) != null) {
        eval.add(double.parse(t));
      } else {
        final b = eval.removeLast();
        final a = eval.removeLast();
        switch (t) {
          case '+': eval.add(a + b); break;
          case '-': eval.add(a - b); break;
          case '*': eval.add(a * b); break;
          case '/': eval.add(a / b); break;
          case '%': eval.add(a % b); break;
        }
      }
    }

    final r = eval.first;
    return r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Button colors (light mode slightly darker)
    final numColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB);
    final opColor = isDark ? const Color(0xFF334155) : const Color(0xFFD1D5DB);
    final acColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFCA5A5);
    final backColor = isDark ? const Color(0xFF3730A3) : const Color(0xFFBFDBFE);
    final eqColor = Colors.blue;

    final keys = [
      'AC', '( )', '%', '÷',
      '7', '8', '9', '×',
      '4', '5', '6', '-',
      '1', '2', '3', '+',
      '0', '.', '⌫', '=',
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.history), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(onReload: _loadHistory)));
        }),
        title: const Text('Calculator'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
          }),
          IconButton(icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode), onPressed: widget.onToggleTheme),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(expression, textAlign: TextAlign.right, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  if (liveResult.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(liveResult, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.grey)),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: keys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemBuilder: (_, i) {
                final k = keys[i];
                final isOp = '+-×÷%'.contains(k) || k == '( )';
                final isAC = k == 'AC';
                final isBack = k == '⌫';
                final isEqual = k == '=';

                Color bg;
                if (isAC) bg = acColor;
                else if (isBack) bg = backColor;
                else if (isEqual) bg = eqColor;
                else if (isOp) bg = opColor;
                else bg = numColor;

                return GestureDetector(
                  onTap: () => onButtonPress(k),
                  child: Container(
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text(k, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: isEqual ? Colors.white : null)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final VoidCallback onReload;
  const HistoryScreen({super.key, required this.onReload});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      history = prefs.getStringList('history') ?? [];
    });
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    await _load();
    widget.onReload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.isEmpty ? const Center(child: Text('No history yet')) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), itemCount: history.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) => Text(history[i], style: Theme.of(context).textTheme.titleMedium)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(onPressed: _clear, icon: const Icon(Icons.delete), label: const Text('Clear History')),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Brand title
            Text(
              ' Vibe Labs ⚡',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Profile image
            const CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage('assets/profile/me.png'),
            ),
            const SizedBox(height: 24),

            // Name & role
            Text(
              'Arijeet Das',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Mobile App Developer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),

            // App title
            Text(
              'The Calculator App',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // App description
            const Text(
  '''A modern, minimal calculator app focused on speed, accuracy, and a smooth user experience.

This app is designed and developed using Flutter and is currently available only for Android mobile devices. It is crafted with attention to detail in UI/UX and performance, making it reliable for everyday calculations.

The Calculator App is a product of Vibe Labs ⚡ and can be downloaded exclusively from Vibe Labs.''',
  textAlign: TextAlign.center,
),

            const SizedBox(height: 24),

            // Version
            Text(
              'Version',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('v1.0.0'),

            const SizedBox(height: 24),

            // Changelog
            Text(
              'Changelog',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Initial Release'),

            const SizedBox(height: 32),

            // GitHub button
            ElevatedButton(
              onPressed: () =>
                openUrl('https://github.com/arijeetdas'),
              child: const Text('GitHub'),
            ),
            const SizedBox(height: 12),

            // Check for updates button
            OutlinedButton(
              onPressed: () => openUrl(
                'https://vibe-labs.netlify.app/calculator'),
              child: const Text('Check for Updates'),
            ),
          ],
        ),
      ),
    );
  }
}