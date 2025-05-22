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
  
  /// Calculates Minimal Detectable Change (MDC)
  /// Based on test-retest reliability data, this is the smallest amount of change
  /// that we can confidently say represents a true change beyond measurement error
  static double calculateMDC(List<double> testRetestData, {double confidenceLevel = 0.95}) {
    // Test-retest reliability data is required
    if (testRetestData.length < 4) return 0; // Insufficient data
    
    // Must have an even number of values (test-retest pairs)
    if (testRetestData.length % 2 != 0) return 0;
    
    // Test-retest differences
    List<double> differences = [];
    for (int i = 0; i < testRetestData.length; i += 2) {
      differences.add(testRetestData[i] - testRetestData[i + 1]);
    }
    
    // Standard deviation of differences
    final stdDev = calculateStandardDeviation(differences);
    
    // SEM (Measurement Standard Error)
    final sem = stdDev / math.sqrt(2);
    
    // MDC calculation (1.96 is used for 95% confidence interval)
    final zScore = confidenceLevel == 0.95 ? 1.96 : 
                  confidenceLevel == 0.90 ? 1.645 : 
                  confidenceLevel == 0.99 ? 2.576 : 1.96;
    
    return zScore * sem * math.sqrt(2);
  }
  
  /// Calculates Smallest Worthwhile Change (SWC)
  /// Represents the smallest meaningful change in performance that is practically important
  static double calculateSWC(List<double> performanceData, {String method = 'cohen', double coefficient = 0.2}) {
    if (performanceData.length < 3) return 0; // Insufficient data
    
    // Mean and standard deviation
    final mean = performanceData.reduce((a, b) => a + b) / performanceData.length;
    final stdDev = calculateStandardDeviation(performanceData);
    
    if (method == 'cohen') {
      // Cohen's d approach: multiply standard deviation by coefficient
      return stdDev * coefficient; // typically 0.2 (small effect)
    } else if (method == 'cv') {
      // Coefficient of Variation (CV) approach
      final cv = stdDev / mean;
      return mean * cv * coefficient; // typically 0.5 or 1.0
    } else {
      // Default: Cohen's d
      return stdDev * 0.2;
    }
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
    return ((currentMean - previousMean) / previousMean) * 100;
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
  
  /// Analyzes performance trend and stability
  static Map<String, double> analyzePerformanceTrend(List<double> performanceData, {int window = 5}) {
    if (performanceData.length < window) return {'trend': 0.0, 'stability': 0.0};
    
    // Get the last N performances
    final recent = performanceData.sublist(performanceData.length - window);
    
    // X values for linear regression (0, 1, 2, ...)
    final xValues = List.generate(window, (i) => i.toDouble());
    
    // Trend analysis (slope)
    final trend = _calculateLinearRegression(xValues, recent)['slope'] ?? 0.0;
    
    // Stability analysis (inverse of coefficient of variation)
    final mean = recent.reduce((a, b) => a + b) / window;
    final stdDev = calculateStandardDeviation(recent);
    final cv = stdDev / mean;
    final stability = math.max(0.0, math.min(1.0, 1.0 - cv)); // Normalized stability between 0-1
    
    return {'trend': trend, 'stability': stability};
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
}