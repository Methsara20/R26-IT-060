/// Weather context returned for an individual short-range forecast day.
class ForecastWeather {
  const ForecastWeather({
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.condition,
  });

  factory ForecastWeather.fromJson(Map<String, dynamic> json) =>
      ForecastWeather(
        temperature: (json['temperature'] as num?)?.toDouble(),
        humidity: (json['humidity'] as num?)?.toDouble(),
        rainfall: (json['rainfall'] as num?)?.toDouble(),
        condition: json['weather_condition']?.toString() ?? 'Unknown',
      );

  final double? temperature;
  final double? humidity;
  final double? rainfall;
  final String condition;
}


/// One forecast observation with demand, confidence, date, and weather.
class ForecastDayResult {
  const ForecastDayResult({
    required this.day,
    required this.date,
    required this.predictedDemand,
    required this.confidencePercentage,
    required this.weather,
  });

  factory ForecastDayResult.fromJson(
    Map<String, dynamic> json, {
    int fallbackDay = 1,
  }) {
    final demand = json['predicted_demand'];
    final confidence = json['confidence_percentage'];
    final weather = json['weather'];
    if (demand is! num ||
        confidence is! num ||
        weather is! Map<String, dynamic>) {
      throw const FormatException('Invalid forecast result');
    }
    return ForecastDayResult(
      day: (json['day'] as num?)?.toInt() ?? fallbackDay,
      date: DateTime.tryParse(
        (json['date'] ?? json['forecast_date'])?.toString() ?? '',
      ),
      predictedDemand: demand.toInt(),
      confidencePercentage: confidence.toInt(),
      weather: ForecastWeather.fromJson(weather),
    );
  }

  final int day;
  final DateTime? date;
  final int predictedDemand;
  final int confidencePercentage;
  final ForecastWeather weather;
}

/// Normalized representation shared by daily, 7-day, and custom responses.
class ShortRangeForecast {
  const ShortRangeForecast({
    required this.type,
    required this.storeId,
    required this.productId,
    required this.totalPredictedDemand,
    required this.averageConfidencePercentage,
    required this.days,
    this.weatherSource,
  });

  factory ShortRangeForecast.fromJson(Map<String, dynamic> json) {
    final type = json['forecast_type']?.toString();
    final storeId = json['store_id']?.toString();
    final productId = json['product_id']?.toString();
    if (type == null || storeId == null || productId == null) {
      throw const FormatException('Invalid forecast identity');
    }

    if (type == 'daily') {
      final day = ForecastDayResult.fromJson(json);
      return ShortRangeForecast(
        type: type,
        storeId: storeId,
        productId: productId,
        totalPredictedDemand: day.predictedDemand,
        averageConfidencePercentage: day.confidencePercentage,
        days: [day],
      );
    }

    final rawDays = json['forecast'];
    final total = json['total_predicted_demand'];
    final confidence = json['average_confidence_percentage'];
    if (rawDays is! List || total is! num || confidence is! num) {
      throw const FormatException('Invalid multi-day forecast');
    }
    return ShortRangeForecast(
      type: type,
      storeId: storeId,
      productId: productId,
      totalPredictedDemand: total.toInt(),
      averageConfidencePercentage: confidence.toInt(),
      weatherSource: json['weather_source']?.toString(),
      days: [
        for (var index = 0; index < rawDays.length; index++)
          ForecastDayResult.fromJson(
            Map<String, dynamic>.from(rawDays[index] as Map),
            fallbackDay: index + 1,
          ),
      ],
    );
  }

  final String type;
  final String storeId;
  final String productId;
  final int totalPredictedDemand;
  final int averageConfidencePercentage;
  final String? weatherSource;
  final List<ForecastDayResult> days;
}
