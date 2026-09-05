class AnalysisResult {
  final double smoothedScore;
  final double riskScore;
  final String verdict;
  final String confidence;
  final int samplesProcessed;
  final bool isFinal;

  const AnalysisResult({
    this.riskScore = 0.0,
    this.smoothedScore = 0.0,
    this.verdict = "Unknown",
    this.confidence = "Waiting for audio...",
    this.samplesProcessed = 0,
    this.isFinal = false,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      riskScore: (json['risk_score'] ?? 0.0).toDouble(),
      smoothedScore: (json['smoothed_score'] ?? 0.0).toDouble(),
      verdict: json['verdict'] ?? "Unknown",
      confidence: json['confidence'] ?? "Waiting for audio...",
      samplesProcessed: json['samples_processed'] as int? ?? 0,
      isFinal: json['is_final'] as bool? ?? false,
    );
  }
}
