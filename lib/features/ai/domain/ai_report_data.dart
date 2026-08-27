// lib/features/ai/domain/ai_report_data.dart

/// Contenu structuré d'un rapport mensuel généré par KarossaAI,
/// prêt à être mis en page en PDF par [AiReportGenerator].
class AiReportData {
  final String titre;
  final String periode;
  final String narratif; // synthèse rédigée par l'IA (markdown simple)
  final Map<String, dynamic> resume; // sortie brute de get_dashboard_summary
  final List<Map<String, dynamic>> anomalies; // sortie de detect_anomalies

  const AiReportData({
    required this.titre,
    required this.periode,
    required this.narratif,
    required this.resume,
    required this.anomalies,
  });
}