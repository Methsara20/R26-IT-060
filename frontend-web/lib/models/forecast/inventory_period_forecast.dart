/// Historical seasonal weather values returned with an inventory forecast.
class SeasonalWeatherSummary {
  const SeasonalWeatherSummary({
    required this.averageTemperature,
    required this.averageHumidity,
    required this.totalRainfall,
    required this.rainyDays,
    required this.stormDays,
    required this.sunnyDays,
  });

  factory SeasonalWeatherSummary.fromJson(Map<String, dynamic> json) =>
      SeasonalWeatherSummary(
        averageTemperature: (json['avg_temperature'] as num?)?.toDouble(),
        averageHumidity: (json['avg_humidity'] as num?)?.toDouble(),
        totalRainfall: (json['total_rainfall'] as num?)?.toDouble(),
        rainyDays: (json['rainy_days'] as num?)?.toInt(),
        stormDays: (json['storm_days'] as num?)?.toInt(),
        sunnyDays: (json['sunny_days'] as num?)?.toInt(),
      );

  final double? averageTemperature;
  final double? averageHumidity;
  final double? totalRainfall;
  final int? rainyDays;
  final int? stormDays;
  final int? sunnyDays;
}

/// A monthly result used independently and inside quarterly responses.
class InventoryMonthForecast {
  const InventoryMonthForecast({
    required this.year,
    required this.month,
    required this.predictedDemand,
    required this.confidencePercentage,
    required this.weather,
    this.monthName,
  });

  factory InventoryMonthForecast.fromMonthlyJson(Map<String, dynamic> json) =>
      _fromJson(
        json,
        json['weather_profile'],
        demandKey: 'predicted_monthly_demand',
      );
  factory InventoryMonthForecast.fromQuarterJson(Map<String, dynamic> json) =>
      _fromJson(json, json['weather'], demandKey: 'predicted_demand');

  static InventoryMonthForecast _fromJson(
    Map<String, dynamic> json,
    dynamic weatherJson, {
    required String demandKey,
  }) {
    final year = json['year'];
    final month = json['month'];
    final demand = json[demandKey];
    final confidence = json['confidence_percentage'];
    if (year is! num ||
        month is! num ||
        demand is! num ||
        confidence is! num ||
        weatherJson is! Map) {
      throw const FormatException('Invalid monthly inventory forecast');
    }
    final weather = Map<String, dynamic>.from(weatherJson);
    return InventoryMonthForecast(
      year: year.toInt(),
      month: month.toInt(),
      monthName: (json['month_name'] ?? weather['month_name'])?.toString(),
      predictedDemand: demand.toInt(),
      confidencePercentage: confidence.toInt(),
      weather: SeasonalWeatherSummary.fromJson(weather),
    );
  }

  final int year;
  final int month;
  final String? monthName;
  final int predictedDemand;
  final int confidencePercentage;
  final SeasonalWeatherSummary weather;
}

/// Normalized automatic monthly or quarterly forecast response.
class InventoryPeriodForecast {
  const InventoryPeriodForecast({
    required this.type,
    required this.storeId,
    required this.category,
    required this.brand,
    required this.gender,
    required this.totalPredictedDemand,
    required this.averageConfidencePercentage,
    required this.months,
    required this.weatherSource,
    required this.weatherMode,
  });

  factory InventoryPeriodForecast.fromJson(Map<String, dynamic> json) {
    final type = json['forecast_type']?.toString();
    final storeId = json['store_id']?.toString();
    final category = json['category']?.toString();
    final brand = json['brand']?.toString();
    final gender = json['gender']?.toString();
    if (type == null ||
        storeId == null ||
        category == null ||
        brand == null ||
        gender == null) {
      throw const FormatException('Invalid inventory forecast identity');
    }
    if (type == 'inventory_monthly_auto') {
      final month = InventoryMonthForecast.fromMonthlyJson(json);
      return InventoryPeriodForecast(
        type: type,
        storeId: storeId,
        category: category,
        brand: brand,
        gender: gender,
        totalPredictedDemand: month.predictedDemand,
        averageConfidencePercentage: month.confidencePercentage,
        months: [month],
        weatherSource: json['weather_source']?.toString() ?? 'Unknown',
        weatherMode: json['weather_mode']?.toString() ?? 'Unknown',
      );
    }
    final rawMonths = json['monthly_forecasts'];
    final demand = json['predicted_quarterly_demand'];
    final confidence = json['average_confidence_percentage'];
    if (rawMonths is! List || demand is! num || confidence is! num) {
      throw const FormatException('Invalid quarterly inventory forecast');
    }
    return InventoryPeriodForecast(
      type: type,
      storeId: storeId,
      category: category,
      brand: brand,
      gender: gender,
      totalPredictedDemand: demand.toInt(),
      averageConfidencePercentage: confidence.toInt(),
      months: rawMonths
          .map(
            (item) => InventoryMonthForecast.fromQuarterJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      weatherSource: json['weather_source']?.toString() ?? 'Unknown',
      weatherMode: json['weather_mode']?.toString() ?? 'Unknown',
    );
  }

  final String type;
  final String storeId;
  final String category;
  final String brand;
  final String gender;
  final int totalPredictedDemand;
  final int averageConfidencePercentage;
  final List<InventoryMonthForecast> months;
  final String weatherSource;
  final String weatherMode;
}
