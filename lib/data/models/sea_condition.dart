

class SeaCondition{
  final double waveHeight ;
  final double waveDirection ;
  final double wavePeriod ;
  final double seaSurfaceTemperature ;

  SeaCondition({
    required this.waveHeight,
    required this.waveDirection,
    required this.wavePeriod,
    required this.seaSurfaceTemperature,
  });

  factory SeaCondition.fromJson(Map<String, dynamic> json) {
    return SeaCondition(
      waveHeight: (json['wave_height'] ?? 0).toDouble(),
      waveDirection: (json['wave_direction'] ?? 0).toDouble(),
      wavePeriod: (json['wave_period'] ?? 0).toDouble(),
      seaSurfaceTemperature: (json['sea_surface_temperature'] ?? 0).toDouble(),
    );
  }
}