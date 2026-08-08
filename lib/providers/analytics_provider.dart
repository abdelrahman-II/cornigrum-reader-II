import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

class AnalyticsData {
  final double averageRtf;
  final double averageLatencyMs;
  final int totalSentencesRead;
  final int totalListeningMinutes;
  final List<double> rtfHistory;
  final List<double> latencyHistory;

  const AnalyticsData({
    this.averageRtf = 0.0,
    this.averageLatencyMs = 0.0,
    this.totalSentencesRead = 0,
    this.totalListeningMinutes = 0,
    this.rtfHistory = const [],
    this.latencyHistory = const [],
  });

  Map<String, dynamic> toJson() => {
        'averageRtf': averageRtf,
        'averageLatencyMs': averageLatencyMs,
        'totalSentencesRead': totalSentencesRead,
        'totalListeningMinutes': totalListeningMinutes,
        'rtfHistory': rtfHistory,
        'latencyHistory': latencyHistory,
      };

  factory AnalyticsData.fromJson(Map<String, dynamic> json) => AnalyticsData(
    averageRtf: (json['averageRtf'] ?? 0.0).toDouble(),
    averageLatencyMs: (json['averageLatencyMs'] ?? 0.0).toDouble(),
    totalSentencesRead: json['totalSentencesRead'] ?? 0,
    totalListeningMinutes: json['totalListeningMinutes'] ?? 0,
    rtfHistory: (json['rtfHistory'] as List? ?? []).map((e) => (e as num).toDouble()).toList(),
    latencyHistory: (json['latencyHistory'] as List? ?? []).map((e) => (e as num).toDouble()).toList(),
  );
}

class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  final StorageService _storage;

  AnalyticsNotifier(this._storage) : super(const AnalyticsData()) {
    _load();
  }

  void _load() {
    final map = _storage.loadAnalytics();
    if (map.isNotEmpty) {
      state = AnalyticsData.fromJson(map);
    }
  }

  Future<void> recordSynthesisMetric({
    required double rtf,
    required double latencyMs,
  }) async {
    final newRtfHist = [...state.rtfHistory, rtf];
    if (newRtfHist.length > 50) newRtfHist.removeAt(0);

    final newLatHist = [...state.latencyHistory, latencyMs];
    if (newLatHist.length > 50) newLatHist.removeAt(0);

    final avgRtf = newRtfHist.reduce((a, b) => a + b) / newRtfHist.length;
    final avgLat = newLatHist.reduce((a, b) => a + b) / newLatHist.length;

    state = AnalyticsData(
      averageRtf: avgRtf,
      averageLatencyMs: avgLat,
      totalSentencesRead: state.totalSentencesRead + 1,
      totalListeningMinutes: state.totalListeningMinutes,
      rtfHistory: newRtfHist,
      latencyHistory: newLatHist,
    );

    await _storage.saveAnalytics(state.toJson());
  }

  Future<void> addListeningMinutes(int minutes) async {
    state = AnalyticsData(
      averageRtf: state.averageRtf,
      averageLatencyMs: state.averageLatencyMs,
      totalSentencesRead: state.totalSentencesRead,
      totalListeningMinutes: state.totalListeningMinutes + minutes,
      rtfHistory: state.rtfHistory,
      latencyHistory: state.latencyHistory,
    );
    await _storage.saveAnalytics(state.toJson());
  }
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsData>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AnalyticsNotifier(storage);
});
