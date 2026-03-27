

class SeaCondition{
  final double waveHeight ;
  final double waveDirection ;
  final double wavePeriod ;

  SeaCondition({
    required this.waveHeight,
    required this.waveDirection,
    required this.wavePeriod,
  });

  factory SeaCondition.fromJson(Map<String, dynamic> json) {
    return SeaCondition(
      waveHeight: (json['wave_height'] ?? 0).toDouble(),
      waveDirection: (json['wave_direction'] ?? 0).toDouble(),
      wavePeriod: (json['wave_period'] ?? 0).toDouble(),
    );
  }
}