import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// Android emulator: 10.0.2.2 | Chrome/Windows: localhost | Real phone: your PC's IP
const baseUrl = 'http://localhost:8000';

class PredictionProvider extends ChangeNotifier {
  String? result;
  List history = [];
  bool loading = false;

  Future<void> predict(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final r = await http.post(Uri.parse('$baseUrl/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data));
      final j = jsonDecode(r.body);
      result = '${j['prediction']} (${(j['probability'] * 100).toStringAsFixed(1)}% chance of >50K)';
      await loadHistory();
    } catch (e) {
      result = 'Error: could not reach the server';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/history'));
      history = jsonDecode(r.body);
      notifyListeners();
    } catch (_) {}
  }
}

void main() => runApp(ChangeNotifierProvider(
  create: (_) => PredictionProvider()..loadHistory(),
  child: const MaterialApp(home: HomePage()),
));

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final age = TextEditingController(text: '40');
  final edu = TextEditingController(text: '13');
  final hours = TextEditingController(text: '45');
  String sex = 'Male';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PredictionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Income Predictor')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: age, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
        TextField(controller: edu, decoration: const InputDecoration(labelText: 'Education years (education.num)'), keyboardType: TextInputType.number),
        TextField(controller: hours, decoration: const InputDecoration(labelText: 'Hours per week'), keyboardType: TextInputType.number),
        DropdownButton<String>(
          value: sex,
          items: ['Male', 'Female'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => sex = v!),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: p.loading
              ? null
              : () => context.read<PredictionProvider>().predict({
            'age': int.parse(age.text),
            'education_num': int.parse(edu.text),
            'hours_per_week': int.parse(hours.text),
            'sex': sex,
          }),
          child: Text(p.loading ? 'Predicting...' : 'Predict'),
        ),
        if (p.result != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(p.result!, style: Theme.of(context).textTheme.titleMedium)),
        const Divider(),
        Text('History', style: Theme.of(context).textTheme.titleLarge),
        ...p.history.map((h) => ListTile(
          leading: Text('#${h['id']}'),
          title: Text('${h['prediction']}  (${(h['probability'] * 100).toStringAsFixed(1)}%)'),
          subtitle: Text('${h['model_name']} - ${h['created_at']}'),
        )),
      ]),
    );
  }
}