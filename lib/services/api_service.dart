import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient_input.dart';
import '../models/prediction_result.dart';

class ApiService {
  static const defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
  final String baseUrl;
  final http.Client client;
  ApiService({this.baseUrl = defaultUrl, http.Client? client})
    : client = client ?? http.Client();

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response =
          await (body == null
                  ? client.get(uri)
                  : client.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw ApiException(
          data['error'] as String? ?? 'The request could not finish.',
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Cannot reach the local server. Check that the Flask backend is running, then try again.',
      );
    }
  }

  Future<String> template() async {
    try {
      final response = await client
          .get(Uri.parse('$baseUrl/api/template'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw ApiException(
          'The template is not available. Train the models first.',
        );
      }
      return response.body;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Cannot download the template. Check the backend connection.',
      );
    }
  }

  Future<PredictionResult> analyze(PatientInput input) async =>
      PredictionResult(await request('/api/analyze', body: input.toJson()));
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
