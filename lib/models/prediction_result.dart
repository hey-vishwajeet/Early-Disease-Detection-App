class PredictionResult {
  final Map<String, dynamic> data;
  const PredictionResult(this.data);
  String get prediction => data['prediction'] as String;
  String get summary => data['summary'] as String;
  double get score => (data['score'] as num).toDouble();
  double get threshold => (data['threshold'] as num).toDouble();
  List<Map<String, dynamic>> get topFeatures =>
      (data['top_features'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get comparison =>
      (data['comparison'] as List).cast<Map<String, dynamic>>();
}
