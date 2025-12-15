import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class SustainabilityAnalyticsService {
  static final SustainabilityAnalyticsService _instance =
      SustainabilityAnalyticsService._internal();
  factory SustainabilityAnalyticsService() => _instance;
  SustainabilityAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Environmental impact constants (approximate values)
  static const double kgCo2PerKgWasteRecycled =
      2.5; // kg CO2 saved per kg recycled
  static const double kgCo2PerKgWasteLandfill =
      0.5; // kg CO2 emitted per kg landfilled
  static const double kgCo2PerLiterFuel = 2.3; // kg CO2 per liter of fuel
  static const double avgFuelEfficiency = 8.5; // liters per 100km
  static const double treesSavedPerTonRecycled =
      17.0; // trees saved per ton of recycling

  /// Calculate environmental impact for a user
  Future<Map<String, dynamic>> calculateUserEnvironmentalImpact(
    String userId,
  ) async {
    try {
      // Get user's waste collection history
      final pickupsQuery = await _firestore
          .collection('waste_pickups')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalWasteCollected = 0;
      double totalRecycled = 0;
      double totalOrganic = 0;
      double totalHazardous = 0;
      double totalDistanceTraveled = 0;
      int totalPickups = pickupsQuery.docs.length;

      for (final doc in pickupsQuery.docs) {
        final data = doc.data();
        final weight = data['estimatedWeight'] as double? ?? 0;

        totalWasteCollected += weight;

        // Categorize waste types
        final wasteTypes = data['wasteTypes'] as List<dynamic>? ?? [];
        for (final type in wasteTypes) {
          final typeData = type as Map<String, dynamic>;
          final category = typeData['category'] as String? ?? '';
          final typeWeight = typeData['weight'] as double? ?? 0;

          switch (category.toLowerCase()) {
            case 'recyclable':
              totalRecycled += typeWeight;
              break;
            case 'organic':
              totalOrganic += typeWeight;
              break;
            case 'hazardous':
              totalHazardous += typeWeight;
              break;
          }
        }

        // Calculate distance (simplified - would use actual route distance)
        totalDistanceTraveled +=
            data['distanceKm'] as double? ?? 5.0; // Default 5km
      }

      // Calculate environmental metrics
      final co2SavedFromRecycling = totalRecycled * kgCo2PerKgWasteRecycled;
      final co2FromTransportation =
          (totalDistanceTraveled / 100) * avgFuelEfficiency * kgCo2PerLiterFuel;
      final netCo2Impact = co2SavedFromRecycling - co2FromTransportation;
      final treesSaved =
          (totalRecycled / 1000) *
          treesSavedPerTonRecycled; // Convert kg to tons

      // Calculate diversion rate (waste not going to landfill)
      final diversionRate = totalWasteCollected > 0
          ? (totalRecycled / totalWasteCollected) * 100
          : 0;

      return {
        'totalWasteCollected': totalWasteCollected,
        'totalRecycled': totalRecycled,
        'totalOrganic': totalOrganic,
        'totalHazardous': totalHazardous,
        'totalPickups': totalPickups,
        'totalDistanceTraveled': totalDistanceTraveled,
        'co2SavedFromRecycling': co2SavedFromRecycling,
        'co2FromTransportation': co2FromTransportation,
        'netCo2Impact': netCo2Impact,
        'treesSaved': treesSaved,
        'diversionRate': diversionRate,
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      debugPrint('Error calculating environmental impact: $e');
      return {};
    }
  }

  /// Get community-wide sustainability metrics
  Future<Map<String, dynamic>> getCommunitySustainabilityMetrics() async {
    try {
      // Get all completed pickups
      final pickupsQuery = await _firestore
          .collection('waste_pickups')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalWasteCollected = 0;
      double totalRecycled = 0;
      double totalDistanceTraveled = 0;
      int totalPickups = pickupsQuery.docs.length;
      int uniqueUsers = 0;

      final userIds = <String>{};

      for (final doc in pickupsQuery.docs) {
        final data = doc.data();
        final weight = data['estimatedWeight'] as double? ?? 0;
        final userId = data['userId'] as String? ?? '';

        totalWasteCollected += weight;
        userIds.add(userId);

        // Categorize waste types
        final wasteTypes = data['wasteTypes'] as List<dynamic>? ?? [];
        for (final type in wasteTypes) {
          final typeData = type as Map<String, dynamic>;
          final category = typeData['category'] as String? ?? '';
          if (category.toLowerCase() == 'recyclable') {
            totalRecycled += typeData['weight'] as double? ?? 0;
          }
        }

        totalDistanceTraveled += data['distanceKm'] as double? ?? 5.0;
      }

      uniqueUsers = userIds.length;

      // Calculate community metrics
      final co2SavedFromRecycling = totalRecycled * kgCo2PerKgWasteRecycled;
      final co2FromTransportation =
          (totalDistanceTraveled / 100) * avgFuelEfficiency * kgCo2PerLiterFuel;
      final netCo2Impact = co2SavedFromRecycling - co2FromTransportation;
      final treesSaved = (totalRecycled / 1000) * treesSavedPerTonRecycled;

      return {
        'totalWasteCollected': totalWasteCollected,
        'totalRecycled': totalRecycled,
        'totalPickups': totalPickups,
        'uniqueUsers': uniqueUsers,
        'totalDistanceTraveled': totalDistanceTraveled,
        'co2SavedFromRecycling': co2SavedFromRecycling,
        'co2FromTransportation': co2FromTransportation,
        'netCo2Impact': netCo2Impact,
        'treesSaved': treesSaved,
        'averageWastePerUser': uniqueUsers > 0
            ? totalWasteCollected / uniqueUsers
            : 0,
        'averagePickupsPerUser': uniqueUsers > 0
            ? totalPickups / uniqueUsers
            : 0,
      };
    } catch (e) {
      debugPrint('Error getting community metrics: $e');
      return {};
    }
  }

  /// Get sustainability trends over time
  Future<List<Map<String, dynamic>>> getSustainabilityTrends(
    String userId, {
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final pickupsQuery = await _firestore
          .collection('waste_pickups')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .orderBy('completedAt')
          .get();

      final trends = <Map<String, dynamic>>[];
      final dailyData = <DateTime, Map<String, double>>{};

      // Group by date
      for (final doc in pickupsQuery.docs) {
        final data = doc.data();
        final completedAt = (data['completedAt'] as Timestamp).toDate();
        final date = DateTime(
          completedAt.year,
          completedAt.month,
          completedAt.day,
        );

        final weight = data['estimatedWeight'] as double? ?? 0;
        double recycled = 0;

        final wasteTypes = data['wasteTypes'] as List<dynamic>? ?? [];
        for (final type in wasteTypes) {
          final typeData = type as Map<String, dynamic>;
          final category = typeData['category'] as String? ?? '';
          if (category.toLowerCase() == 'recyclable') {
            recycled += typeData['weight'] as double? ?? 0;
          }
        }

        if (dailyData.containsKey(date)) {
          dailyData[date]!['waste'] = (dailyData[date]!['waste'] ?? 0) + weight;
          dailyData[date]!['recycled'] =
              (dailyData[date]!['recycled'] ?? 0) + recycled;
        } else {
          dailyData[date] = {'waste': weight, 'recycled': recycled};
        }
      }

      // Convert to list format
      final sortedDates = dailyData.keys.toList()..sort();

      for (final date in sortedDates) {
        final data = dailyData[date]!;
        final co2Saved = data['recycled']! * kgCo2PerKgWasteRecycled;

        trends.add({
          'date': date,
          'wasteCollected': data['waste'],
          'wasteRecycled': data['recycled'],
          'co2Saved': co2Saved,
        });
      }

      return trends;
    } catch (e) {
      debugPrint('Error getting sustainability trends: $e');
      return [];
    }
  }

  /// Generate personalized sustainability recommendations
  Future<List<Map<String, dynamic>>> getPersonalizedRecommendations(
    String userId,
  ) async {
    try {
      final impact = await calculateUserEnvironmentalImpact(userId);
      final recommendations = <Map<String, dynamic>>[];

      final totalWaste = impact['totalWasteCollected'] as double? ?? 0;
      final recycled = impact['totalRecycled'] as double? ?? 0;
      final diversionRate = impact['diversionRate'] as double? ?? 0;
      final totalPickups = impact['totalPickups'] as int? ?? 0;

      // Diversion rate recommendations
      if (diversionRate < 50) {
        recommendations.add({
          'type': 'diversion',
          'title': 'Improve Recycling Rate',
          'description':
              'Your current diversion rate is ${diversionRate.toStringAsFixed(1)}%. Try to recycle more of your waste.',
          'impact':
              'Save up to ${(totalWaste * 0.3 * kgCo2PerKgWasteRecycled).toStringAsFixed(1)} kg CO2',
          'priority': 'high',
          'icon': '♻️',
        });
      }

      // Pickup frequency recommendations
      if (totalPickups < 5) {
        recommendations.add({
          'type': 'frequency',
          'title': 'Increase Pickup Frequency',
          'description':
              'Schedule more waste pickups to reduce landfill waste.',
          'impact':
              'Additional ${(5 - totalPickups) * 10} kg waste diverted monthly',
          'priority': 'medium',
          'icon': '📅',
        });
      }

      // Transportation efficiency
      final distance = impact['totalDistanceTraveled'] as double? ?? 0;
      if (distance > 50 && totalPickups > 0) {
        final avgDistance = distance / totalPickups;
        if (avgDistance > 10) {
          recommendations.add({
            'type': 'efficiency',
            'title': 'Optimize Routes',
            'description':
                'Your average pickup distance is ${avgDistance.toStringAsFixed(1)} km. Consider combining pickups.',
            'impact':
                'Reduce CO2 emissions by ${(avgDistance * 0.1 * kgCo2PerLiterFuel * avgFuelEfficiency / 100).toStringAsFixed(1)} kg per pickup',
            'priority': 'medium',
            'icon': '🚗',
          });
        }
      }

      // Seasonal recommendations
      final now = DateTime.now();
      if (now.month >= 11 || now.month <= 2) {
        // Winter
        recommendations.add({
          'type': 'seasonal',
          'title': 'Winter Waste Management',
          'description':
              'Winter often brings more household waste. Stay on top of your recycling!',
          'impact': 'Maintain high diversion rates during peak waste season',
          'priority': 'low',
          'icon': '❄️',
        });
      }

      // Community comparison
      final communityMetrics = await getCommunitySustainabilityMetrics();
      final communityAvgWaste =
          communityMetrics['averageWastePerUser'] as double? ?? 0;

      if (totalWaste > 0 && communityAvgWaste > 0) {
        final userVsCommunity = (totalWaste / communityAvgWaste - 1) * 100;
        if (userVsCommunity < -20) {
          recommendations.add({
            'type': 'community',
            'title': 'Community Leader',
            'description':
                'You\'re collecting ${userVsCommunity.abs().toStringAsFixed(0)}% more waste than the community average!',
            'impact': 'Consider mentoring other users',
            'priority': 'low',
            'icon': '🌟',
          });
        }
      }

      return recommendations;
    } catch (e) {
      debugPrint('Error getting personalized recommendations: $e');
      return [];
    }
  }

  /// Calculate carbon footprint for different activities
  Map<String, double> calculateActivityCarbonFootprint(
    String activity,
    double quantity,
  ) {
    switch (activity) {
      case 'driving':
        // quantity in km
        return {
          'co2_emitted':
              (quantity / 100) * avgFuelEfficiency * kgCo2PerLiterFuel,
        };
      case 'recycling':
        // quantity in kg
        return {'co2_saved': quantity * kgCo2PerKgWasteRecycled};
      case 'landfill':
        // quantity in kg
        return {'co2_emitted': quantity * kgCo2PerKgWasteLandfill};
      case 'composting':
        // quantity in kg
        return {
          'co2_saved': quantity * 0.5, // Approximate CO2 saved from composting
        };
      default:
        return {};
    }
  }

  /// Get sustainability goals and progress
  Future<Map<String, dynamic>> getSustainabilityGoals(String userId) async {
    try {
      final impact = await calculateUserEnvironmentalImpact(userId);

      final goals = {
        'monthly_waste_goal': 50.0, // kg
        'monthly_recycling_goal': 30.0, // kg
        'co2_savings_goal': 25.0, // kg
        'pickup_frequency_goal': 8, // pickups per month
      };

      final currentMonth = DateTime.now().month;
      final currentYear = DateTime.now().year;

      // Calculate current month progress
      final monthlyPickupsQuery = await _firestore
          .collection('waste_pickups')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(currentYear, currentMonth, 1),
            ),
          )
          .get();

      double monthlyWaste = 0;
      double monthlyRecycled = 0;
      double monthlyCo2Saved = 0;
      int monthlyPickups = monthlyPickupsQuery.docs.length;

      for (final doc in monthlyPickupsQuery.docs) {
        final data = doc.data();
        final weight = data['estimatedWeight'] as double? ?? 0;
        monthlyWaste += weight;

        final wasteTypes = data['wasteTypes'] as List<dynamic>? ?? [];
        for (final type in wasteTypes) {
          final typeData = type as Map<String, dynamic>;
          final category = typeData['category'] as String? ?? '';
          if (category.toLowerCase() == 'recyclable') {
            final typeWeight = typeData['weight'] as double? ?? 0;
            monthlyRecycled += typeWeight;
            monthlyCo2Saved += typeWeight * kgCo2PerKgWasteRecycled;
          }
        }
      }

      return {
        'goals': goals,
        'progress': {
          'monthly_waste': monthlyWaste,
          'monthly_recycled': monthlyRecycled,
          'monthly_co2_saved': monthlyCo2Saved,
          'monthly_pickups': monthlyPickups,
        },
        'percentages': {
          'waste_goal': (monthlyWaste / goals['monthly_waste_goal']! * 100)
              .clamp(0, 100),
          'recycling_goal':
              (monthlyRecycled / goals['monthly_recycling_goal']! * 100).clamp(
                0,
                100,
              ),
          'co2_goal': (monthlyCo2Saved / goals['co2_savings_goal']! * 100)
              .clamp(0, 100),
          'pickup_goal':
              (monthlyPickups / goals['pickup_frequency_goal']! * 100).clamp(
                0,
                100,
              ),
        },
      };
    } catch (e) {
      debugPrint('Error getting sustainability goals: $e');
      return {};
    }
  }

  /// Generate sustainability report
  Future<Map<String, dynamic>> generateSustainabilityReport(
    String userId, {
    int days = 30,
  }) async {
    try {
      final impact = await calculateUserEnvironmentalImpact(userId);
      final trends = await getSustainabilityTrends(userId, days: days);
      final goals = await getSustainabilityGoals(userId);
      final recommendations = await getPersonalizedRecommendations(userId);

      // Calculate summary statistics
      double totalWasteInPeriod = 0;
      double totalRecycledInPeriod = 0;
      double totalCo2SavedInPeriod = 0;

      for (final trend in trends) {
        totalWasteInPeriod += trend['wasteCollected'] as double? ?? 0;
        totalRecycledInPeriod += trend['wasteRecycled'] as double? ?? 0;
        totalCo2SavedInPeriod += trend['co2Saved'] as double? ?? 0;
      }

      final avgDailyWaste = totalWasteInPeriod / days;
      final avgDailyRecycled = totalRecycledInPeriod / days;
      final avgDailyCo2Saved = totalCo2SavedInPeriod / days;

      return {
        'period': {
          'days': days,
          'start_date': DateTime.now().subtract(Duration(days: days)),
        },
        'summary': {
          'total_waste_collected': totalWasteInPeriod,
          'total_recycled': totalRecycledInPeriod,
          'total_co2_saved': totalCo2SavedInPeriod,
          'average_daily_waste': avgDailyWaste,
          'average_daily_recycled': avgDailyRecycled,
          'average_daily_co2_saved': avgDailyCo2Saved,
          'recycling_rate': totalWasteInPeriod > 0
              ? (totalRecycledInPeriod / totalWasteInPeriod) * 100
              : 0,
        },
        'lifetime_impact': impact,
        'trends': trends,
        'goals': goals,
        'recommendations': recommendations,
        'generated_at': DateTime.now(),
      };
    } catch (e) {
      debugPrint('Error generating sustainability report: $e');
      return {};
    }
  }
}

// Sustainability Analytics UI Components
class EnvironmentalImpactCard extends StatelessWidget {
  final Map<String, dynamic> impact;

  const EnvironmentalImpactCard({super.key, required this.impact});

  @override
  Widget build(BuildContext context) {
    final netCo2Impact = impact['netCo2Impact'] as double? ?? 0;
    final treesSaved = impact['treesSaved'] as double? ?? 0;
    final diversionRate = impact['diversionRate'] as double? ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Environmental Impact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // CO2 Impact
            Row(
              children: [
                Icon(
                  netCo2Impact >= 0 ? Icons.eco : Icons.warning,
                  color: netCo2Impact >= 0 ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${netCo2Impact.abs().toStringAsFixed(1)} kg CO2',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        netCo2Impact >= 0
                            ? 'Saved from atmosphere'
                            : 'Added to atmosphere',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Trees Saved
            Row(
              children: [
                const Text('🌳', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${treesSaved.toStringAsFixed(1)} trees',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Equivalent saved',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Diversion Rate
            Row(
              children: [
                const Text('♻️', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${diversionRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Waste diversion rate',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SustainabilityGoalsWidget extends StatelessWidget {
  final Map<String, dynamic> goalsData;

  const SustainabilityGoalsWidget({super.key, required this.goalsData});

  @override
  Widget build(BuildContext context) {
    final goals = goalsData['goals'] as Map<String, dynamic>? ?? {};
    final progress = goalsData['progress'] as Map<String, dynamic>? ?? {};
    final percentages = goalsData['percentages'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildGoalProgress(
              'Waste Collected',
              progress['monthly_waste'] ?? 0,
              goals['monthly_waste_goal'] ?? 0,
              percentages['waste_goal'] ?? 0,
              'kg',
              Colors.blue,
            ),

            const SizedBox(height: 12),

            _buildGoalProgress(
              'Waste Recycled',
              progress['monthly_recycled'] ?? 0,
              goals['monthly_recycling_goal'] ?? 0,
              percentages['recycling_goal'] ?? 0,
              'kg',
              Colors.green,
            ),

            const SizedBox(height: 12),

            _buildGoalProgress(
              'CO2 Saved',
              progress['monthly_co2_saved'] ?? 0,
              goals['co2_savings_goal'] ?? 0,
              percentages['co2_goal'] ?? 0,
              'kg',
              Colors.purple,
            ),

            const SizedBox(height: 12),

            _buildGoalProgress(
              'Pickups Completed',
              progress['monthly_pickups'] ?? 0,
              goals['pickup_frequency_goal'] ?? 0,
              percentages['pickup_goal'] ?? 0,
              '',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgress(
    String label,
    double current,
    double target,
    double percentage,
    String unit,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              '${current.toStringAsFixed(1)}$unit / ${target.toStringAsFixed(1)}$unit',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (percentage / 100).clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 2),
        Text(
          '${percentage.toStringAsFixed(1)}% complete',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

class RecommendationsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> recommendations;

  const RecommendationsWidget({super.key, required this.recommendations});

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personalized Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ...recommendations.map((rec) => _buildRecommendationCard(rec)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    final priority = rec['priority'] as String? ?? 'low';
    final color = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rec['icon'] ?? '💡', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  rec['description'] ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Impact: ${rec['impact'] ?? ''}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}

class SustainabilityTrendsChart extends StatelessWidget {
  final List<Map<String, dynamic>> trends;

  const SustainabilityTrendsChart({super.key, required this.trends});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Sustainability Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: trends.length,
                itemBuilder: (context, index) {
                  final trend = trends[index];
                  final date = trend['date'] as DateTime;
                  final waste = trend['wasteCollected'] as double? ?? 0;
                  final recycled = trend['wasteRecycled'] as double? ?? 0;

                  return Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        // Recycled bar
                        Expanded(
                          flex: recycled.toInt(),
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Non-recycled waste bar
                        Expanded(
                          flex: max(0, (waste - recycled).toInt()),
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Date label
                        Text(
                          DateFormat('MM/dd').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Recycled', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 4),
                    const Text('Other Waste', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
