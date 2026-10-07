class PeriodSettings {
  final int avgCycleLength;
  final int avgPeriodLength;

  const PeriodSettings({
    required this.avgCycleLength,
    required this.avgPeriodLength,
  });

  factory PeriodSettings.fromMap(Map<String, dynamic>? map) {
    return PeriodSettings(
      avgCycleLength: (map?['avgCycleLength'] as num?)?.toInt() ?? 28,
      avgPeriodLength: (map?['avgPeriodLength'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'avgCycleLength': avgCycleLength,
      'avgPeriodLength': avgPeriodLength,
    };
  }
}
