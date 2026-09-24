import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:disease_risk_app/screens/home_screen.dart';
import 'package:disease_risk_app/services/api_service.dart';
import 'package:disease_risk_app/services/report_generator.dart';
import 'package:disease_risk_app/models/prediction_result.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/heart_result.json').readAsStringSync())
          as Map<String, dynamic>;

  testWidgets('Complete sample assessment and measured comparison flow', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path == '/api/config') {
          return http.Response(
            jsonEncode({'features': fixture['features']}),
            200,
          );
        }
        if (request.url.path == '/api/sample') {
          return http.Response(jsonEncode({'features': fixture['input']}), 200);
        }
        if (request.url.path == '/api/analyze') {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(fixture), 200);
        }
        return http.Response('{"error":"Unexpected route"}', 404);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: HomeScreen(api: api)));
    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(4));
    await tester.ensureVisible(find.text('Analyze'));
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a measurement or choose Load Sample.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Load Sample'));
    await tester.tap(find.text('Load Sample'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Loaded a real UCI example'), findsOneWidget);
    await tester.ensureVisible(find.text('Analyze'));
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    expect(submitted!['features'], fixture['input']);
    expect(find.text(fixture['prediction'] as String), findsOneWidget);
    expect(find.text('What influenced this result?'), findsOneWidget);
    await tester.ensureVisible(find.text('How do the two models compare?'));
    await tester.tap(find.text('How do the two models compare?'));
    await tester.pumpAndSettle();
    expect(find.text('88.5%'), findsOneWidget);
    expect(find.text('78.7%'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
  });

  test('PDF builds from the real result without overflow', () async {
    final bytes = await ReportGenerator.buildPdf(PredictionResult(fixture));
    expect(bytes.length, greaterThan(2000));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    final output = File('build/test-reports/heart-assessment.pdf');
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(bytes);
  });

  test('Server errors stay visible without synthetic predictions', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response('{"error":"Models not trained"}', 503),
      ),
    );
    await expectLater(
      api.request('/api/config'),
      throwsA(predicate((e) => e.toString() == 'Models not trained')),
    );
  });
}
