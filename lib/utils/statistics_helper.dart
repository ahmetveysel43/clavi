// utils/statistics_helper.dart

import 'dart:math' as math;

class StatisticsHelper {
  /// Calculates the standard deviation of a dataset
  static double calculateStandardDeviation(List<double> data) {
    if (data.isEmpty || data.length < 2) return 0;
    
    final mean = data.reduce((a, b) => a + b) / data.length;
    final squaredDiffs = data.map((value) => math.pow(value - mean, 2).toDouble()).toList();
    final variance = squaredDiffs.reduce((a, b) => a + b) / data.length;
    
    return math.sqrt(variance);
  }
  
  /// Calculates Minimal Detectable Change (MDC) with ICC-based approach
  /// This is the gold standard method used in sports science
  static double calculateMDC(List<double> testRetestData, {double confidenceLevel = 0.95}) {
    // Test-retest reliability data is required (must be even number for pairs)
    if (testRetestData.length < 4 || testRetestData.length % 2 != 0) return 0;
    
    // Split into test and retest values
    List<double> testValues = [];
    List<double> retestValues = [];
    
    for (int i = 0; i < testRetestData.length; i += 2) {
      testValues.add(testRetestData[i]);
      retestValues.add(testRetestData[i + 1]);
    }
    
    // Calculate ICC (Intraclass Correlation Coefficient) using two-way mixed model
    final icc = _calculateICC(testValues, retestValues);
    
    // Calculate pooled standard deviation
    final pooledSD = _calculatePooledStandardDeviation(testValues, retestValues);
    
    // Calculate SEM (Standard Error of Measurement)
    final sem = pooledSD * math.sqrt(1 - icc);
    
    // Calculate MDC with appropriate z-score
    final zScore = confidenceLevel == 0.95 ? 1.96 : 
                  confidenceLevel == 0.90 ? 1.645 : 
                  confidenceLevel == 0.99 ? 2.576 : 1.96;
    
    // MDC95 = z-score × SEM × √2
    return zScore * sem * math.sqrt(2);
  }

  /// Helper method to calculate ICC (2,1) - Two-way mixed, absolute agreement, single measures
  static double _calculateICC(List<double> test, List<double> retest) {
    if (test.length != retest.length || test.length < 3) return 0;
    
    final n = test.length;
    final k = 2; // Number of measurements (test and retest)
    
    // Calculate means
    final allValues = [...test, ...retest];
    final grandMean = allValues.reduce((a, b) => a + b) / (n * k);
    
    // Calculate sum of squares
    double ssWithin = 0;
    double ssBetween = 0;
    
    // Between-subjects sum of squares
    for (int i = 0; i < n; i++) {
      final subjectMean = (test[i] + retest[i]) / k;
      ssBetween += k * math.pow(subjectMean - grandMean, 2);
    }
    
    // Within-subjects sum of squares  
    for (int i = 0; i < n; i++) {
      final subjectMean = (test[i] + retest[i]) / k;
      ssWithin += math.pow(test[i] - subjectMean, 2);
      ssWithin += math.pow(retest[i] - subjectMean, 2);
    }
    
    // Mean squares
    final msBetween = ssBetween / (n - 1);
    final msWithin = ssWithin / (n * (k - 1));
    
    // ICC calculation
    if (msBetween + (k - 1) * msWithin == 0) return 0;
    
    final icc = (msBetween - msWithin) / (msBetween + (k - 1) * msWithin);
    
    return math.max(0, math.min(1, icc)); // Clamp between 0 and 1
  }

  /// Helper method to calculate pooled standard deviation
  static double _calculatePooledStandardDeviation(List<double> group1, List<double> group2) {
    if (group1.length != group2.length || group1.length < 2) return 0;
    
    final n1 = group1.length;
    final n2 = group2.length;
    
    final var1 = math.pow(calculateStandardDeviation(group1), 2);
    final var2 = math.pow(calculateStandardDeviation(group2), 2);
    
    final pooledVariance = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2);
    
    return math.sqrt(pooledVariance);
  }
  
  /// Calculates Smallest Worthwhile Change (SWC) using sports science best practices
  /// Uses between-athlete variability as recommended by Hopkins et al.
  static double calculateSWC({
    required List<double> betweenAthleteData, // Different athletes' baseline values
    String method = 'cohen',
    double multiplier = 0.2,
    List<double>? withinAthleteData, // Same athlete's repeated measures (optional)
  }) {
    if (betweenAthleteData.length < 3) return 0;
    
    switch (method) {
      case 'cohen':
        // Cohen's d approach: 0.2 × between-athlete SD
        final betweenSD = calculateStandardDeviation(betweenAthleteData);
        return betweenSD * multiplier;
        
      case 'hopkins':
        // Will Hopkins approach: 0.3 × between-athlete SD
        final betweenSD = calculateStandardDeviation(betweenAthleteData);
        return betweenSD * 0.3;
        
      case 'cv_based':
        // CV-based approach: Use coefficient of variation
        final mean = calculateMean(betweenAthleteData);
        final cv = calculateCV(betweenAthleteData);
        return mean * (cv / 100) * multiplier;
        
      case 'effect_size':
        // Effect size approach using pooled SD if within-athlete data available
        if (withinAthleteData != null && withinAthleteData.length >= 3) {
          final pooledSD = _calculatePooledStandardDeviation(betweenAthleteData, withinAthleteData);
          return pooledSD * multiplier;
        } else {
          final betweenSD = calculateStandardDeviation(betweenAthleteData);
          return betweenSD * multiplier;
        }
        
      case 'percentile':
        // Percentile-based approach: difference between 75th and 25th percentile
        final q75 = calculatePercentile(betweenAthleteData, 75);
        final q25 = calculatePercentile(betweenAthleteData, 25);
        return (q75 - q25) * 0.5; // Half of IQR
        
      default:
        // Default: Cohen's small effect
        final betweenSD = calculateStandardDeviation(betweenAthleteData);
        return betweenSD * 0.2;
    }
  }

  /// Enhanced SWC calculation specifically for different test types
  static double calculateSWCForTestType({
    required List<double> populationData,
    required String testType,
    String? athleteLevel, // 'elite', 'trained', 'recreational'
  }) {
    if (populationData.length < 5) return 0;
    
    // Different multipliers based on test type and athlete level
    double multiplier = 0.2; // Default Cohen's small effect
    
    // Adjust multiplier based on test type
    switch (testType.toUpperCase()) {
      case 'CMJ':
      case 'SJ':
        multiplier = 0.15; // Jump tests are more sensitive
        break;
      case 'DJ':
        multiplier = 0.18; // Drop jumps have moderate sensitivity  
        break;
      case 'RJ':
        multiplier = 0.25; // Repeated jumps have higher variability
        break;
      case 'SPRINT':
        multiplier = 0.12; // Sprint times are very sensitive
        break;
    }
    
    // Adjust based on athlete level
    if (athleteLevel != null) {
      switch (athleteLevel.toLowerCase()) {
        case 'elite':
          multiplier *= 0.8; // Elite athletes have smaller meaningful changes
          break;
        case 'trained':
          multiplier *= 1.0; // Standard multiplier
          break;
        case 'recreational':
          multiplier *= 1.2; // Recreational athletes have larger meaningful changes
          break;
      }
    }
    
    final betweenSD = calculateStandardDeviation(populationData);
    return betweenSD * multiplier;
  }

  /// Calculates SWC with confidence intervals using bootstrap
  static Map<String, double> calculateSWCWithCI({
    required List<double> betweenAthleteData,
    double confidenceLevel = 0.90,
    String method = 'cohen',
  }) {
    if (betweenAthleteData.length < 5) {
      return {'swc': 0, 'lower_ci': 0, 'upper_ci': 0};
    }
    
    final swc = calculateSWC(betweenAthleteData: betweenAthleteData, method: method);
    
    // Bootstrap confidence intervals for SWC
    final List<double> bootstrapSWCs = [];
    final random = math.Random();
    
    for (int i = 0; i < 1000; i++) {
      // Bootstrap resample
      final resample = List.generate(betweenAthleteData.length, 
        (_) => betweenAthleteData[random.nextInt(betweenAthleteData.length)]);
      
      final bootstrapSWC = calculateSWC(betweenAthleteData: resample, method: method);
      bootstrapSWCs.add(bootstrapSWC);
    }
    
    bootstrapSWCs.sort();
    
    final alpha = (1 - confidenceLevel) / 2;
    final lowerIndex = (alpha * bootstrapSWCs.length).floor();
    final upperIndex = ((1 - alpha) * bootstrapSWCs.length).floor() - 1;
    
    return {
      'swc': swc,
      'lower_ci': bootstrapSWCs[lowerIndex],
      'upper_ci': bootstrapSWCs[upperIndex],
    };
  }
  
  /// Calculates Typicality Index - Evaluates the consistency of athlete performance
  static double calculateTypicalityIndex(List<double> performanceData) {
    if (performanceData.length < 5) return 0; // Insufficient data
    
    // Coefficient of Variation (CV)
    final mean = performanceData.reduce((a, b) => a + b) / performanceData.length;
    final stdDev = calculateStandardDeviation(performanceData);
    final cv = stdDev / mean;
    
    // Convert CV to a typicality score between 0-100
    // 100 = very consistent performance, 0 = very variable performance
    return math.max(0, math.min(100, 100 * (1 - cv)));
  }
  
  /// Calculates Reliable Change Index (RCI)
  /// Used to determine how much an athlete has changed relative to their own previous performance
  static double calculateRCI(double preScore, double postScore, double sem) {
    // SEM = Standard Error of Measurement
    // Standard error between two measurements
    final sediff = sem * math.sqrt(2);
    
    // RCI calculation
    return (postScore - preScore) / sediff;
    
    // RCI interpretation:
    // |RCI| > 1.96 => 95% confidence of significant change
    // |RCI| > 1.645 => 90% confidence of significant change
  }
  
  /// Calculates Intra-individual Coefficient of Variation - Measures the consistency of an athlete's own performance
  static double calculateIntraIndividualCV(List<double> performanceData) {
    if (performanceData.length < 3) return 0; // Insufficient data
    
    final mean = performanceData.reduce((a, b) => a + b) / performanceData.length;
    final stdDev = calculateStandardDeviation(performanceData);
    
    // Coefficient of variation (as percentage)
    return (stdDev / mean) * 100;
  }
  
  /// Calculates Performance Momentum - Detects trend changes in athlete's recent performances
  static double calculateMomentum(List<double> recentPerformances, {int window = 3}) {
    if (recentPerformances.length < window * 2) return 0; // Insufficient data
    
    // Compare last window performances with previous window
    final currentWindow = recentPerformances.sublist(recentPerformances.length - window);
    final previousWindow = recentPerformances.sublist(
      recentPerformances.length - (window * 2),
      recentPerformances.length - window
    );
    
    final currentMean = currentWindow.reduce((a, b) => a + b) / window;
    final previousMean = previousWindow.reduce((a, b) => a + b) / window;
    
    // Momentum: percentage change
    return previousMean != 0 ? ((currentMean - previousMean) / previousMean) * 100 : 0;
  }
  
  /// Calculates Z-scores - Normalized performance change relative to athlete's own historical standard deviation
  static List<double> calculateZScores(List<double> performanceData) {
    if (performanceData.length < 5) return []; // Insufficient data
    
    final mean = performanceData.reduce((a, b) => a + b) / performanceData.length;
    final stdDev = calculateStandardDeviation(performanceData);
    
    // If standard deviation is very small (data almost constant), z-scores can explode
    if (stdDev < 0.0001) return List.filled(performanceData.length, 0.0);
    
    // Calculate z-score for each value
    return performanceData.map((p) => (p - mean) / stdDev).toList();
  }
  
  /// Analyzes performance trend and stability with enhanced methodology
  static Map<String, double> analyzePerformanceTrend(List<double> performanceData, {int window = 5}) {
    if (performanceData.length < window) return {'trend': 0.0, 'stability': 0.0};
    
    // Get the last N performances
    final recent = performanceData.sublist(performanceData.length - window);
    
    // X values for linear regression (0, 1, 2, ...)
    final xValues = List.generate(window, (i) => i.toDouble());
    
    // Trend analysis (slope)
    final regression = _calculateLinearRegression(xValues, recent);
    final trend = regression['slope'] ?? 0.0;
    
    // Stability analysis (inverse of coefficient of variation)
    final mean = recent.reduce((a, b) => a + b) / window;
    final stdDev = calculateStandardDeviation(recent);
    final cv = mean != 0 ? stdDev / mean : 0;
    final stability = math.max(0.0, math.min(1.0, 1.0 - cv)); // Normalized stability between 0-1
    
    return {
      'trend': trend, 
      'stability': stability,
      'r_squared': regression['r2'] ?? 0.0,
      'trend_strength': _categorizeTrendStrength(trend, stdDev),
    };
  }

  /// Helper method to categorize trend strength
  static double _categorizeTrendStrength(double slope, double stdDev) {
    if (stdDev == 0) return 0;
    // Normalize slope by standard deviation to get relative trend strength
    final relativeSlope = (slope).abs() / stdDev;
    return math.min(1.0, relativeSlope); // Cap at 1.0
  }

  /// Comprehensive progress analysis for athlete performance
  static Map<String, dynamic> analyzeAthleteProgress({
    required List<double> performanceData,
    required List<DateTime> testDates,
    required String testType,
    double? smallestWorthwhileChange,
    double? minimalDetectableChange,
  }) {
    if (performanceData.length < 3 || performanceData.length != testDates.length) {
      return {'error': 'Insufficient data for analysis'};
    }
    
    Map<String, dynamic> analysis = {};
    
    // 1. Basic descriptive statistics
    analysis['descriptive'] = {
      'mean': calculateMean(performanceData),
      'median': calculateMedian(performanceData),
      'std_dev': calculateStandardDeviation(performanceData),
      'cv': calculateCV(performanceData),
      'range': calculateRange(performanceData),
      'sample_size': performanceData.length,
    };
    
    // 2. Trend analysis
    final daysSinceFirst = testDates.map((date) => 
      date.difference(testDates.first).inDays.toDouble()).toList();
    
    final trendAnalysis = calculateLinearRegression(daysSinceFirst, performanceData);
    analysis['trend'] = {
      'slope': trendAnalysis['slope'],
      'r_squared': trendAnalysis['r2'],
      'daily_change': trendAnalysis['slope'],
      'weekly_change': (trendAnalysis['slope'] ?? 0.0) * 7,
      'monthly_change': (trendAnalysis['slope'] ?? 0.0) * 30,
      'trend_classification': _classifyTrend(trendAnalysis['slope'] ?? 0.0, testType),
    };
    
    // 3. Recent vs baseline comparison
    final baselineN = math.min(3, performanceData.length ~/ 3);
    final recentN = math.min(3, performanceData.length ~/ 3);
    
    final baseline = performanceData.sublist(0, baselineN);
    final recent = performanceData.sublist(performanceData.length - recentN);
    
    final baselineMean = calculateMean(baseline);
    final recentMean = calculateMean(recent);
    final change = recentMean - baselineMean;
    final percentChange = baselineMean != 0 ? (change / baselineMean) * 100 : 0;
    
    analysis['change_analysis'] = {
      'baseline_mean': baselineMean,
      'recent_mean': recentMean,
      'absolute_change': change,
      'percent_change': percentChange,
      'effect_size': _calculateEffectSize(baseline, recent),
    };
    
    // 4. Clinical significance analysis
    if (smallestWorthwhileChange != null && minimalDetectableChange != null) {
      analysis['clinical_significance'] = _assessClinicalSignificance(
        change: change,
        swc: smallestWorthwhileChange,
        mdc: minimalDetectableChange,
      );
    }
    
    return analysis;
  }

  /// Classify trend based on slope and test type
  static String _classifyTrend(double slope, String testType) {
    // For time-based tests (lower is better), invert the interpretation
    final isTimeBased = ['sprint', 'time'].any((t) => 
      testType.toLowerCase().contains(t));
    
    final adjustedSlope = isTimeBased ? -slope : slope;
    
    if (adjustedSlope > 0.1) return 'Strong Improvement';
    if (adjustedSlope > 0.05) return 'Moderate Improvement';
    if (adjustedSlope > 0.01) return 'Slight Improvement';
    if (adjustedSlope > -0.01) return 'Stable';
    if (adjustedSlope > -0.05) return 'Slight Decline';
    if (adjustedSlope > -0.1) return 'Moderate Decline';
    return 'Strong Decline';
  }

  /// Calculate effect size (Cohen's d) between two groups
  static double _calculateEffectSize(List<double> group1, List<double> group2) {
    if (group1.length < 2 || group2.length < 2) return 0;
    
    final mean1 = calculateMean(group1);
    final mean2 = calculateMean(group2);
    final pooledSD = _calculatePooledStandardDeviation(group1, group2);
    
    return pooledSD != 0 ? (mean2 - mean1) / pooledSD : 0;
  }

  /// Assess clinical significance using magnitude-based inference
  static Map<String, dynamic> _assessClinicalSignificance({
    required double change,
    required double swc,
    required double mdc,
  }) {
    // Determine if change exceeds MDC (statistically significant)
    final exceedsMDC = change.abs() > mdc;
    
    // Determine magnitude relative to SWC
    final magnitude = change.abs() / swc;
    String magnitudeCategory;
    
    if (magnitude < 0.2) {
      magnitudeCategory = 'Trivial';
    } else if (magnitude < 0.6) {
      magnitudeCategory = 'Small';
    } else if (magnitude < 1.2) {
      magnitudeCategory = 'Moderate';
    } else if (magnitude < 2.0) {
      magnitudeCategory = 'Large';
    } else {
      magnitudeCategory = 'Very Large';
    }
    
    // Clinical inference
    String inference;
    if (!exceedsMDC) {
      inference = 'No Real Change (within measurement error)';
    } else if (magnitude < 0.2) {
      inference = 'Real but Trivial Change';
    } else {
      final direction = change > 0 ? 'Positive' : 'Negative';
      inference = '$direction $magnitudeCategory Change';
    }
    
    return {
      'exceeds_mdc': exceedsMDC,
      'magnitude': magnitude,
      'magnitude_category': magnitudeCategory,
      'clinical_inference': inference,
      'practically_significant': magnitude >= 0.2 && exceedsMDC,
    };
  }
  
  /// Calculates Coefficient of Variation (CV)
  static double calculateCV(List<double> data) {
    if (data.length < 2) return 0;
    
    final mean = data.reduce((a, b) => a + b) / data.length;
    final stdDev = calculateStandardDeviation(data);
    
    return mean != 0 ? (stdDev / mean) * 100 : 0;
  }
  
  /// Calculates the mean (average) of a dataset
  static double calculateMean(List<double> data) {
    if (data.isEmpty) return 0;
    return data.reduce((a, b) => a + b) / data.length;
  }
  
  /// Calculates the median of a dataset
  static double calculateMedian(List<double> data) {
    if (data.isEmpty) return 0;
    
    final sortedData = List<double>.from(data)..sort();
    final n = sortedData.length;
    
    if (n % 2 == 0) {
      return (sortedData[n ~/ 2 - 1] + sortedData[n ~/ 2]) / 2;
    } else {
      return sortedData[n ~/ 2];
    }
  }
  
  /// Calculates the range (max - min) of a dataset
  static double calculateRange(List<double> data) {
    if (data.isEmpty) return 0;
    
    final min = data.reduce(math.min);
    final max = data.reduce(math.max);
    
    return max - min;
  }
  
  /// Calculates percentiles of a dataset
  static double calculatePercentile(List<double> data, double percentile) {
    if (data.isEmpty || percentile < 0 || percentile > 100) return 0;
    
    final sortedData = List<double>.from(data)..sort();
    final n = sortedData.length;
    
    if (percentile == 0) return sortedData.first;
    if (percentile == 100) return sortedData.last;
    
    final index = (percentile / 100) * (n - 1);
    final lowerIndex = index.floor();
    final upperIndex = index.ceil();
    
    if (lowerIndex == upperIndex) {
      return sortedData[lowerIndex];
    } else {
      final lowerValue = sortedData[lowerIndex];
      final upperValue = sortedData[upperIndex];
      final fraction = index - lowerIndex;
      return lowerValue + fraction * (upperValue - lowerValue);
    }
  }
  
  /// Calculates correlation coefficient between two datasets
  static double calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0;
    
    final n = x.length;
    final meanX = calculateMean(x);
    final meanY = calculateMean(y);
    
    double numerator = 0;
    double sumXSquared = 0;
    double sumYSquared = 0;
    
    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      
      numerator += dx * dy;
      sumXSquared += dx * dx;
      sumYSquared += dy * dy;
    }
    
    final denominator = math.sqrt(sumXSquared * sumYSquared);
    
    return denominator != 0 ? numerator / denominator : 0;
  }
  
  /// Detects outliers using the IQR method
  static List<double> detectOutliers(List<double> data) {
    if (data.length < 4) return [];
    
    final q1 = calculatePercentile(data, 25);
    final q3 = calculatePercentile(data, 75);
    final iqr = q3 - q1;
    
    final lowerBound = q1 - 1.5 * iqr;
    final upperBound = q3 + 1.5 * iqr;
    
    return data.where((value) => value < lowerBound || value > upperBound).toList();
  }
  
  /// Removes outliers from a dataset
  static List<double> removeOutliers(List<double> data) {
    if (data.length < 4) return data;
    
    final outliers = detectOutliers(data).toSet();
    return data.where((value) => !outliers.contains(value)).toList();
  }
  
  /// Normalizes data to 0-1 range
  static List<double> normalizeData(List<double> data) {
    if (data.isEmpty) return [];
    
    final min = data.reduce(math.min);
    final max = data.reduce(math.max);
    final range = max - min;
    
    if (range == 0) return List.filled(data.length, 0.5);
    
    return data.map((value) => (value - min) / range).toList();
  }
  
  /// Standardizes data (z-score normalization)
  static List<double> standardizeData(List<double> data) {
    if (data.length < 2) return data;
    
    final mean = calculateMean(data);
    final stdDev = calculateStandardDeviation(data);
    
    if (stdDev == 0) return List.filled(data.length, 0.0);
    
    return data.map((value) => (value - mean) / stdDev).toList();
  }
  
  /// Calculates moving average
  static List<double> calculateMovingAverage(List<double> data, int window) {
    if (data.length < window || window <= 0) return [];
    
    List<double> movingAverages = [];
    
    for (int i = window - 1; i < data.length; i++) {
      final windowData = data.sublist(i - window + 1, i + 1);
      final average = calculateMean(windowData);
      movingAverages.add(average);
    }
    
    return movingAverages;
  }
  
  /// Calculates exponential moving average
  static List<double> calculateExponentialMovingAverage(List<double> data, double alpha) {
    if (data.isEmpty || alpha <= 0 || alpha > 1) return [];
    
    List<double> ema = [data.first];
    
    for (int i = 1; i < data.length; i++) {
      final emaValue = alpha * data[i] + (1 - alpha) * ema.last;
      ema.add(emaValue);
    }
    
    return ema;
  }
  
  /// Calculates linear regression parameters
  static Map<String, double> _calculateLinearRegression(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) {
      return {'slope': 0.0, 'intercept': 0.0, 'r2': 0.0};
    }
    
    final n = x.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    
    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
    }
    
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) {
      return {'slope': 0.0, 'intercept': 0.0, 'r2': 0.0};
    }
    
    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;
    
    // Coefficient of determination (R^2)
    double meanY = sumY / n;
    double totalSS = 0, residualSS = 0;
    
    for (int i = 0; i < n; i++) {
      totalSS += math.pow(y[i] - meanY, 2).toDouble();
      residualSS += math.pow(y[i] - (slope * x[i] + intercept), 2).toDouble();
    }
    
    final r2 = totalSS > 0 ? 1.0 - (residualSS / totalSS) : 0.0;
    
    return {'slope': slope, 'intercept': intercept, 'r2': r2};
  }
  
  /// Calculates linear regression (public method)
  static Map<String, double> calculateLinearRegression(List<double> x, List<double> y) {
    return _calculateLinearRegression(x, y);
  }
  
  /// Calculates performance classification based on percentiles
  static String classifyPerformance(double value, List<double> referenceData) {
    if (referenceData.isEmpty) return 'Veri Yok';
    
    final percentile = _calculatePercentileRank(value, referenceData);
    
    if (percentile >= 90) return 'Mükemmel';
    if (percentile >= 75) return 'İyi';
    if (percentile >= 50) return 'Ortalama';
    if (percentile >= 25) return 'Zayıf';
    return 'Çok Zayıf';
  }
  
  /// Helper method to calculate percentile rank
  static double _calculatePercentileRank(double value, List<double> data) {
    final sortedData = List<double>.from(data)..sort();
    int count = 0;
    
    for (final dataPoint in sortedData) {
      if (dataPoint <= value) count++;
    }
    
    return (count / sortedData.length) * 100;
  }

  // ==================== SPRINT ANALYSIS METHODS ====================

  /// Enhanced sprint analysis with proper velocity and acceleration calculations
  static Map<String, dynamic> calculateSprintKinematics(Map<int, double> kapiDegerler) {
    final kapiMesafeleri = [0, 5, 10, 15, 20, 30, 40]; // Standard gate distances
    
    // Sort gates by distance
    final sortedGates = kapiDegerler.keys.toList()..sort();
    
    List<double> times = [];
    List<double> distances = [];
    List<double> velocities = [];
    List<double> accelerations = [];
    
    // Prepare time-distance data
    for (final gate in sortedGates) {
      if (gate - 1 < kapiMesafeleri.length) {
        times.add(kapiDegerler[gate]!);
        distances.add(kapiMesafeleri[gate - 1].toDouble());
      }
    }
    
    if (times.length < 3) {
      return {'times': times, 'distances': distances, 'velocities': [], 'accelerations': []};
    }
    
    // Calculate instantaneous velocities using numerical differentiation
    velocities = _calculateInstantaneousVelocities(times, distances);
    
    // Calculate accelerations from velocity data
    accelerations = _calculateAccelerations(times, velocities);
    
    // Calculate split times and velocities
    Map<String, double> splitTimes = {};
    Map<String, double> splitVelocities = {};
    
    for (int i = 1; i < times.length; i++) {
      final splitDistance = distances[i] - distances[i-1];
      final splitTime = times[i] - times[i-1];
      final splitVelocity = splitDistance / splitTime;
      
      splitTimes['${distances[i-1].toInt()}-${distances[i].toInt()}m'] = splitTime;
      splitVelocities['${distances[i-1].toInt()}-${distances[i].toInt()}m'] = splitVelocity;
    }
    
    return {
      'times': times,
      'distances': distances,
      'velocities': velocities,
      'accelerations': accelerations,
      'split_times': splitTimes,
      'split_velocities': splitVelocities,
      'max_velocity': velocities.isNotEmpty ? velocities.reduce(math.max) : 0,
      'max_acceleration': accelerations.isNotEmpty ? accelerations.reduce(math.max) : 0,
    };
  }

  /// Calculate instantaneous velocities using numerical differentiation
  static List<double> _calculateInstantaneousVelocities(List<double> times, List<double> distances) {
    if (times.length < 3) return [];
    
    List<double> velocities = [];
    
    for (int i = 0; i < times.length; i++) {
      if (i == 0) {
        // Forward difference for first point
        final dt = times[i + 1] - times[i];
        final dd = distances[i + 1] - distances[i];
        velocities.add(dd / dt);
      } else if (i == times.length - 1) {
        // Backward difference for last point
        final dt = times[i] - times[i - 1];
        final dd = distances[i] - distances[i - 1];
        velocities.add(dd / dt);
      } else {
        // Central difference for middle points (more accurate)
        final dt = times[i + 1] - times[i - 1];
        final dd = distances[i + 1] - distances[i - 1];
        velocities.add(dd / dt);
      }
    }
    
    return velocities;
  }

  /// Calculate accelerations from velocity data
  static List<double> _calculateAccelerations(List<double> times, List<double> velocities) {
    if (times.length < 3 || velocities.length < 3) return [];
    
    List<double> accelerations = [];
    
    for (int i = 0; i < velocities.length; i++) {
      if (i == 0) {
        // Forward difference for first point
        final dt = times[i + 1] - times[i];
        final dv = velocities[i + 1] - velocities[i];
        accelerations.add(dv / dt);
      } else if (i == velocities.length - 1) {
        // Backward difference for last point
        final dt = times[i] - times[i - 1];
        final dv = velocities[i] - velocities[i - 1];
        accelerations.add(dv / dt);
      } else {
        // Central difference for middle points
        final dt = times[i + 1] - times[i - 1];
        final dv = velocities[i + 1] - velocities[i - 1];
        accelerations.add(dv / dt);
      }
    }
    
    return accelerations;
  }

  /// Calculate horizontal force-velocity profile for sprinting
  static Map<String, double> calculateHorizontalForceVelocityProfile({
    required Map<int, double> kapiDegerler,
    required double athleteMass, // kg
    required double bodyHeight, // m
  }) {
    final kinematics = calculateSprintKinematics(kapiDegerler);
    final velocities = kinematics['velocities'] as List<double>;
    final accelerations = kinematics['accelerations'] as List<double>;
    
    if (velocities.length < 3 || accelerations.length < 3) {
      return {'f0': 0, 'v0': 0, 'pmax': 0, 'drf': 0, 'efficiency': 0};
    }
    
    // Calculate horizontal forces (F = ma + air resistance)
    List<double> forces = [];
    final airResistanceCoeff = 0.2 * bodyHeight; // Simplified air resistance
    
    for (int i = 0; i < velocities.length && i < accelerations.length; i++) {
      final airResistance = airResistanceCoeff * math.pow(velocities[i], 2);
      final horizontalForce = athleteMass * accelerations[i] + airResistance;
      forces.add(horizontalForce);
    }
    
    // Linear regression to find F0 and V0
    final regression = calculateLinearRegression(velocities, forces);
    
    final f0 = regression['intercept']!; // Theoretical maximum force at v=0
    final v0 = regression['slope'] != 0 ? -regression['intercept']! / regression['slope']! : 0; // Theoretical maximum velocity at F=0
    final pmax = (f0 * v0) / 4; // Maximum power output
    final drf = -regression['slope']!; // Rate of force decrease
    
    // Calculate mechanical effectiveness
    final efficiency = regression['r2']!; // How well force-velocity relationship fits linear model
    
    return {
      'f0': f0.toDouble(),                      // Maximum horizontal force (N)
      'v0': v0.toDouble(),                      // Maximum theoretical velocity (m/s)
      'pmax': pmax.toDouble(),                  // Maximum power (W)
      'drf': drf.toDouble(),                    // Decrease rate of force (N⋅s/m)
      'efficiency': efficiency.toDouble(),      // Mechanical effectiveness (0-1)
    };
  }

  // ==================== RSI CALCULATION METHODS ====================

  /// Calculate RSI for Drop Jump tests
  static double calculateDropJumpRSI({
    required double jumpHeight,     // in centimeters
    required double contactTime,    // in seconds
    required double dropHeight,     // in centimeters (height of drop)
  }) {
    // Validation checks
    if (contactTime <= 0 || contactTime > 1.0) return 0; // Contact time should be reasonable
    if (jumpHeight <= 0 || jumpHeight > 150) return 0;   // Jump height should be reasonable
    if (dropHeight <= 0 || dropHeight > 100) return 0;   // Drop height should be reasonable
    
    // Convert jump height to meters for calculation
    final jumpHeightM = jumpHeight / 100;
    
    // RSI = Jump Height (m) / Contact Time (s)
    final rsi = jumpHeightM / contactTime;
    
    return rsi;
  }

  /// Calculate modified RSI using flight time instead of jump height
  static double calculateRSIFromFlightTime({
    required double flightTime,     // in seconds
    required double contactTime,    // in seconds
  }) {
    // Validation checks
    if (contactTime <= 0 || contactTime > 1.0) return 0;
    if (flightTime <= 0 || flightTime > 2.0) return 0;
    
    // RSI_mod = Flight Time / Contact Time
    final rsiMod = flightTime / contactTime;
    
    return rsiMod;
  }

  /// Calculate RSI for Repeated Jump tests (e.g., 10-second continuous jumps)
  static Map<String, double> calculateRepeatedJumpRSI({
    required List<double> flightTimes,   // List of flight times in seconds
    required List<double> contactTimes,  // List of contact times in seconds
  }) {
    if (flightTimes.length != contactTimes.length || flightTimes.length < 5) {
      return {'mean_rsi': 0, 'rsi_fatigue_index': 0, 'consistency': 0};
    }
    
    // Calculate RSI for each jump
    List<double> rsiValues = [];
    for (int i = 0; i < flightTimes.length; i++) {
      if (contactTimes[i] > 0 && flightTimes[i] > 0) {
        final rsi = flightTimes[i] / contactTimes[i];
        rsiValues.add(rsi);
      }
    }
    
    if (rsiValues.isEmpty) return {'mean_rsi': 0, 'rsi_fatigue_index': 0, 'consistency': 0};
    
    // Calculate mean RSI
    final meanRSI = calculateMean(rsiValues);
    
    // Calculate RSI fatigue index (% decline from best to worst)
    final maxRSI = rsiValues.reduce(math.max);
    final minRSI = rsiValues.reduce(math.min);
    final fatigueIndex = maxRSI > 0 ? ((maxRSI - minRSI) / maxRSI) * 100 : 0;
    
    // Calculate consistency (inverse of coefficient of variation)
    final cv = calculateCV(rsiValues);
    final consistency = math.max(0, 100 - cv); // Higher value = more consistent
    
    return {
      'mean_rsi': meanRSI.toDouble(),
      'rsi_fatigue_index': fatigueIndex.toDouble(),
      'consistency': consistency.toDouble(),
      'max_rsi': maxRSI.toDouble(),
      'min_rsi': minRSI.toDouble(),
    };
  }

  /// Calculate comprehensive reactive strength metrics
  static Map<String, dynamic> calculateReactiveStrengthMetrics({
    required double jumpHeight,      // cm
    required double flightTime,      // seconds
    required double contactTime,     // seconds
    double? dropHeight,              // cm (optional, for DJ tests)
    double? athleteMass,             // kg (optional, for power calculations)
  }) {
    Map<String, dynamic> metrics = {};
    
    // Basic validations
    if (contactTime <= 0 || flightTime <= 0 || jumpHeight <= 0) {
      return {'error': 'Invalid input values'};
    }
    
    // 1. Traditional RSI (height-based)
    final rsiHeight = (jumpHeight / 100) / contactTime;
    metrics['rsi_height'] = rsiHeight;
    
    // 2. Modified RSI (flight time-based)
    final rsiFlightTime = flightTime / contactTime;
    metrics['rsi_flight_time'] = rsiFlightTime;
    
    // 3. Reactive Strength Ratio (if drop height available)
    if (dropHeight != null && dropHeight > 0) {
      final reactiveStrengthRatio = jumpHeight / dropHeight;
      metrics['reactive_strength_ratio'] = reactiveStrengthRatio;
    }
    
    // 4. Contact Time Index
    metrics['contact_time_index'] = contactTime * 1000; // Convert to milliseconds
    
    // 5. Flight:Contact Ratio
    metrics['flight_contact_ratio'] = flightTime / contactTime;
    
    // 6. Reactive Power (if mass available)
    if (athleteMass != null && athleteMass > 0) {
      // Power = (mass × gravity × jump height) / contact time
      final gravity = 9.81;
      final jumpHeightM = jumpHeight / 100;
      final reactivePower = (athleteMass * gravity * jumpHeightM) / contactTime;
      metrics['reactive_power'] = reactivePower; // Watts
      
      // Relative power (per kg body weight)
      metrics['relative_reactive_power'] = reactivePower / athleteMass;
    }
    
    // 7. Performance classifications
    metrics['rsi_classification'] = _classifyRSI(rsiHeight);
    metrics['contact_time_classification'] = _classifyContactTime(contactTime * 1000);
    
    return metrics;
  }

  /// Classify RSI performance level
  static String _classifyRSI(double rsi) {
    if (rsi >= 2.5) return 'Excellent';
    if (rsi >= 2.0) return 'Very Good';
    if (rsi >= 1.5) return 'Good';
    if (rsi >= 1.0) return 'Average';
    if (rsi >= 0.5) return 'Below Average';
    return 'Poor';
  }

  /// Classify contact time performance
  static String _classifyContactTime(double contactTimeMs) {
    if (contactTimeMs <= 100) return 'Excellent';
    if (contactTimeMs <= 150) return 'Very Good';
    if (contactTimeMs <= 200) return 'Good';
    if (contactTimeMs <= 250) return 'Average';
    if (contactTimeMs <= 300) return 'Below Average';
    return 'Poor';
  }
}