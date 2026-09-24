class FeatureDefinition {
  final String name, label, unit, help;
  FeatureDefinition(Map<String, dynamic> json)
    : name = json['name'] as String,
      label = json['label'] as String,
      unit = json['unit'] as String,
      help = json['help'] as String;
}

class PatientInput {
  final Map<String, double?> features;
  const PatientInput(this.features);
  Map<String, dynamic> toJson() => {'features': features};
}
