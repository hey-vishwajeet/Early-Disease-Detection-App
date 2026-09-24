import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/prediction_result.dart';

class ReportGenerator {
  static Future<Uint8List> buildPdf(PredictionResult result) async {
    final data = result.data;
    final dataset = data['dataset'] as Map<String, dynamic>;
    final source = dataset['source'] as Map<String, dynamic>;
    final document = pw.Document(
      title: 'Heart disease benchmark assessment',
      author: 'Hybrid QML Student Prototype',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        build: (_) => [
          pw.Text(
            'Hybrid Quantum Machine Learning Platform\nfor Early Disease Detection',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Heart disease | Student research prototype'),
          pw.Divider(),
          pw.Text(
            result.prediction,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(result.summary),
          pw.SizedBox(height: 12),
          pw.Text(
            'Quantum model score: ${result.score.toStringAsFixed(4)}; decision boundary: ${result.threshold.toStringAsFixed(4)}.',
          ),
          pw.Text(
            'Uncalibrated decision margin. Not a disease probability or future risk.',
          ),
          pw.Header(level: 1, text: 'Recorded measurements'),
          pw.TableHelper.fromTextArray(
            headers: ['Measurement', 'Value', 'Unit'],
            data: (data['features'] as List)
                .map(
                  (f) => [
                    f['label'],
                    data['input'][f['name']]?.toString() ??
                        'Missing (training median used)',
                    f['unit'],
                  ],
                )
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.Header(level: 1, text: 'Three main model influences'),
          ...result.topFeatures.map(
            (f) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                '${f['label']}: ${(f['contribution'] as num) >= 0 ? '+' : ''}${(f['contribution'] as num).toStringAsFixed(4)} score units.',
              ),
            ),
          ),
          pw.Text(
            'Exact four-feature Shapley explanation with eight training reference records. Baseline score: ${(data['explanation']['baseline'] as num).toStringAsFixed(4)}. Effects explain model behavior, not medical causation.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Header(level: 1, text: 'Measured comparison'),
          pw.TableHelper.fromTextArray(
            headers: ['Model', 'Accuracy', 'Sensitivity', 'Specificity'],
            data: result.comparison
                .map(
                  (m) => [
                    m['name'],
                    ...['accuracy', 'sensitivity', 'specificity'].map(
                      (key) => '${((m[key] as num) * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                )
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Both models use the same four selected inputs and held-out test set (${result.comparison.first['test_rows']} records). No quantum advantage is assumed.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Header(level: 1, text: 'Provenance and limitations'),
          pw.Text(
            'Model version: ${data['model_version']}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '${source['citation']}; ${source['license']}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            source['source_url'] as String,
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Dataset SHA-256: ${dataset['sha256']}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            data['context'] as String,
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Research prototype only. Not a medical diagnosis. Do not use for medical decisions.',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ),
    );
    return document.save();
  }

  static Future<void> download(PredictionResult result) async {
    await Printing.sharePdf(
      bytes: await buildPdf(result),
      filename: 'heart-assessment.pdf',
    );
  }
}
