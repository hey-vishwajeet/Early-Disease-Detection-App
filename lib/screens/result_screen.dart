import 'package:flutter/material.dart';
import '../models/prediction_result.dart';
import '../services/report_generator.dart';

class ResultScreen extends StatefulWidget {
  final PredictionResult result;
  const ResultScreen({super.key, required this.result});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool exporting = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('Your benchmark result')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HEART DISEASE · QUANTUM MODEL',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1765CF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.prediction,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(result.summary),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Model score: ${result.score.toStringAsFixed(3)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'The disease-present boundary is ${result.threshold.toStringAsFixed(3)}. This score is not a probability or a percentage risk.',
                ),
                if ((result.data['imputed_fields'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Missing measurements were filled using training values: ${(result.data['imputed_fields'] as List).join(', ')}.',
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'What influenced this result?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'These are the three largest effects on this model’s score, compared with reference records from its training data.',
                ),
                const SizedBox(height: 12),
                ...result.topFeatures.map((f) {
                  final value = (f['contribution'] as num).toDouble();
                  final direction = value.abs() < 0.000001
                      ? 'Had almost no effect on this score.'
                      : value > 0
                      ? 'Pushed the score toward disease present.'
                      : 'Pushed the score toward disease absent.';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDFE7F1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f['label'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF17314D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(direction),
                        Text(
                          'Score contribution: ${value >= 0 ? '+' : ''}${value.toStringAsFixed(3)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
                const Text(
                  'Model explanations describe patterns in data, not the medical cause of disease.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('How do the two models compare?'),
                  subtitle: const Text(
                    'Measured on the same held-out heart-disease records',
                  ),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20,
                        horizontalMargin: 0,
                        columns: const [
                          DataColumn(label: Text('Model')),
                          DataColumn(label: Text('Accuracy')),
                          DataColumn(label: Text('Sensitivity')),
                          DataColumn(label: Text('Specificity')),
                        ],
                        rows: result.comparison
                            .map(
                              (m) => DataRow(
                                cells: [
                                  DataCell(Text(m['name'] as String)),
                                  ...[
                                    'accuracy',
                                    'sensitivity',
                                    'specificity',
                                  ].map(
                                    (key) => DataCell(
                                      Text(
                                        '${((m[key] as num) * 100).toStringAsFixed(1)}%',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Accuracy: all correct classifications. Sensitivity: disease-present records correctly identified. Specificity: disease-absent records correctly identified.\n\nThese results do not establish a quantum advantage or prove early detection.',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: exporting
                      ? null
                      : () async {
                          setState(() {
                            exporting = true;
                            error = null;
                          });
                          try {
                            await ReportGenerator.download(result);
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => error =
                                    'The report could not be downloaded. Please try again.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => exporting = false);
                          }
                        },
                  icon: const Icon(Icons.download_outlined),
                  label: Text(exporting ? 'Preparing report…' : 'Download PDF'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Research prototype only. Do not use this result to make medical decisions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
