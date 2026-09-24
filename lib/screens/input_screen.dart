import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/patient_input.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class InputScreen extends StatefulWidget {
  final ApiService api;
  const InputScreen({super.key, required this.api});
  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  List<FeatureDefinition> features = [];
  final controllers = <String, TextEditingController>{};
  final form = GlobalKey<FormState>();
  bool busy = true;
  String? error, notice;

  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> loadConfig() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final config = await widget.api.request('/api/config');
      if (!mounted) return;
      setState(() {
        features = (config['features'] as List)
            .map((f) => FeatureDefinition(f))
            .toList();
        for (final f in features) {
          controllers.putIfAbsent(f.name, () => TextEditingController());
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void fill(Map<String, dynamic> values, String message) {
    if (!mounted) return;
    setState(() {
      for (final f in features) {
        controllers[f.name]!.text = values[f.name]?.toString() ?? '';
      }
      notice = message;
    });
  }

  Future<void> downloadTemplate() async {
    final content = await widget.api.template();
    const name = 'heart-assessment-template.csv';
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: 'text/csv',
      name: name,
    );
    if (kIsWeb) {
      await file.saveTo(name);
    } else {
      final destination = await getSaveLocation(suggestedName: name);
      if (destination != null) await file.saveTo(destination.path);
    }
    if (mounted) {
      setState(
        () => notice =
            'The template includes one real benchmark example. Keep its column names when replacing values.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Heart assessment')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Four measurements. One clear result.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use measurements from a recorded examination. For a quick demonstration, load a real UCI benchmark sample.',
                ),
                const SizedBox(height: 22),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB3261E)),
                    ),
                  ),
                if (features.isEmpty && !busy)
                  OutlinedButton(
                    onPressed: loadConfig,
                    child: const Text('Try again'),
                  ),
                if (features.isNotEmpty) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => perform(() async {
                                final sample = await widget.api.request(
                                  '/api/sample',
                                );
                                fill(
                                  sample['features'] as Map<String, dynamic>,
                                  'Loaded a real UCI example from the held-out test set.',
                                );
                              }),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Load Sample'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => perform(() async {
                                final file = await openFile(
                                  acceptedTypeGroups: [
                                    const XTypeGroup(
                                      label: 'CSV',
                                      extensions: ['csv'],
                                      uniformTypeIdentifiers: [
                                        'public.comma-separated-values-text',
                                      ],
                                    ),
                                  ],
                                );
                                if (file == null) return;
                                if (await file.length() > 60000) {
                                  throw ApiException(
                                    'Please choose a small CSV with one assessment row.',
                                  );
                                }
                                final imported = await widget.api.request(
                                  '/api/import',
                                  body: {'csv': await file.readAsString()},
                                );
                                fill(
                                  imported['features'] as Map<String, dynamic>,
                                  'Imported one assessment. Please check the values below.',
                                );
                              }),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Import CSV'),
                      ),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => perform(downloadTemplate),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('CSV template'),
                      ),
                    ],
                  ),
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        notice!,
                        style: const TextStyle(color: Color(0xFF1765CF)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: TextFormField(
                        key: ValueKey(f.name),
                        controller: controllers[f.name],
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: f.label,
                          suffixText: f.unit,
                          helperText: f.help,
                          helperMaxLines: 3,
                        ),
                        validator: (text) {
                          if (text == null || text.trim().isEmpty) return null;
                          final value = double.tryParse(text);
                          return value == null || !value.isFinite || value < 0
                              ? 'Enter a non-negative number.'
                              : null;
                        },
                      ),
                    ),
                  ),
                  const Text(
                    'If a measurement is unavailable, leave it blank. The model uses a value learned from the training records.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (!form.currentState!.validate()) return;
                            final values = {
                              for (final f in features)
                                f.name: double.tryParse(
                                  controllers[f.name]!.text.trim(),
                                ),
                            };
                            if (values.values.every((v) => v == null)) {
                              setState(
                                () => error =
                                    'Enter a measurement or choose Load Sample.',
                              );
                              return;
                            }
                            perform(() async {
                              final result = await widget.api.analyze(
                                PatientInput(values),
                              );
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ResultScreen(result: result),
                                ),
                              );
                            });
                          },
                    child: Text(busy ? 'Please wait…' : 'Analyze'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
