import 'package:flutter/material.dart';
import '../service/collector_rating_service.dart';

/// A compact widget to display a collector's rating summary
class CollectorRatingDisplay extends StatelessWidget {
  final String collectorId;
  final bool showCategories;
  final bool compact;

  const CollectorRatingDisplay({
    super.key,
    required this.collectorId,
    this.showCategories = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: CollectorRatingService().getCollectorRatingSummary(collectorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return compact
              ? const SizedBox(
                  width: 60,
                  height: 16,
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : const SizedBox.shrink();
        }

        final data = snapshot.data;
        final averageRating =
            (data?['averageRating'] as num?)?.toDouble() ?? 0.0;
        final totalRatings = data?['totalRatings'] as int? ?? 0;
        final categoryRatings =
            data?['categoryRatings'] as Map<String, dynamic>? ?? {};

        if (totalRatings == 0) {
          return compact
              ? const Text(
                  'No ratings yet',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_outline,
                        color: Colors.grey[400],
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'No ratings yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                );
        }

        if (compact) {
          return _buildCompactRating(averageRating, totalRatings);
        }

        return showCategories
            ? _buildDetailedRating(averageRating, totalRatings, categoryRatings)
            : _buildStandardRating(averageRating, totalRatings);
      },
    );
  }

  Widget _buildCompactRating(double rating, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Text(
          ' ($count)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStandardRating(double rating, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(5, (index) {
            return Icon(
              index < rating.round()
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: const Color(0xFFFFC107),
              size: 18,
            );
          }),
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            ' ($count reviews)',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedRating(
    double rating,
    int count,
    Map<String, dynamic> categories,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC107), Color(0xFFFFD54F)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFC107),
                        size: 18,
                      );
                    }),
                  ),
                  Text(
                    '$count reviews',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildCategoryBar(
              'Punctuality',
              Icons.access_time_rounded,
              (categories['punctuality'] as num?)?.toDouble() ?? 0,
            ),
            const SizedBox(height: 8),
            _buildCategoryBar(
              'Professionalism',
              Icons.handshake_rounded,
              (categories['professionalism'] as num?)?.toDouble() ?? 0,
            ),
            const SizedBox(height: 8),
            _buildCategoryBar(
              'Waste Handling',
              Icons.recycling_rounded,
              (categories['handling'] as num?)?.toDouble() ?? 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String label, IconData icon, double rating) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rating / 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getRatingColor(rating),
              ),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.lightGreen;
    if (rating >= 2.5) return Colors.amber;
    if (rating >= 1.5) return Colors.orange;
    return Colors.red;
  }
}
