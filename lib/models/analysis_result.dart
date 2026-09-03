class AnalysisResult {
  final double smoothedScore;
  final String verdict;
  final String confidence;

  const AnalysisResult({
    this.smoothedScore = 0.0,
    this.verdict = "Unknown",
    this.confidence = "Waiting for audio...",
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      smoothedScore: (json['smoothed_score'] ?? 0.0).toDouble(),
      verdict: json['verdict'] ?? "Unknown",
      confidence: json['confidence'] ?? "Waiting for audio...",
    );
  }
}
