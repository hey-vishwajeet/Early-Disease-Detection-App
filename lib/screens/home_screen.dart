import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'input_screen.dart';

class HomeScreen extends StatelessWidget {
  final ApiService api;
  HomeScreen({super.key, ApiService? api}) : api = api ?? ApiService();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    color: Color(0xFF1765CF),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'HEART DISEASE · STUDENT RESEARCH PROTOTYPE',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1765CF),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hybrid Quantum Machine Learning Platform for Early Disease Detection',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 22),
                Text(
                  'Explore how a quantum machine learning model classifies heart-disease benchmark records using four measurements.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Load a real sample or enter recorded measurements. See the result, the three main influences, and a comparison with a classical model.',
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => InputScreen(api: api)),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Start Assessment'),
                ),
                const SizedBox(height: 28),
                const Text(
                  'For research and learning only. Benchmark classification is not a medical diagnosis, a prediction of future disease, or proof of early detection.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF66778A)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
