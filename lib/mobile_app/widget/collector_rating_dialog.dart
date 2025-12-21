import 'package:flutter/material.dart';
import '../service/collector_rating_service.dart';

/// A beautiful dialog for users to rate collectors after pickup completion
class CollectorRatingDialog extends StatefulWidget {
  final String collectorId;
  final String collectorName;
  final String userId;
  final String requestId;
  final VoidCallback? onRatingSubmitted;

  const CollectorRatingDialog({
    super.key,
    required this.collectorId,
    required this.collectorName,
    required this.userId,
    required this.requestId,
    this.onRatingSubmitted,
  });

  /// Show the rating dialog and return true if a rating was submitted
  static Future<bool> show({
    required BuildContext context,
    required String collectorId,
    required String collectorName,
    required String userId,
    required String requestId,
    VoidCallback? onRatingSubmitted,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CollectorRatingDialog(
        collectorId: collectorId,
        collectorName: collectorName,
        userId: userId,
        requestId: requestId,
        onRatingSubmitted: onRatingSubmitted,
      ),
    );
    return result ?? false;
  }

  @override
  State<CollectorRatingDialog> createState() => _CollectorRatingDialogState();
}

class _CollectorRatingDialogState extends State<CollectorRatingDialog>
    with SingleTickerProviderStateMixin {
  int _overallRating = 0;
  int _punctualityRating = 0;
  int _professionalismRating = 0;
  int _handlingRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildOverallRating(),
                const SizedBox(height: 20),
                _buildCategoryRatings(),
                const SizedBox(height: 20),
                _buildCommentField(),
                const SizedBox(height: 24),
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F7DD4), Color(0xFF4C9BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F7DD4).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.star_rounded, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'Rate Your Experience',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How was your pickup with ${widget.collectorName}?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildOverallRating() {
    return Column(
      children: [
        Text(
          'Overall Rating',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return GestureDetector(
              onTap: () => setState(() => _overallRating = starIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  starIndex <= _overallRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 44,
                  color: starIndex <= _overallRating
                      ? const Color(0xFFFFC107)
                      : Colors.grey[300],
                ),
              ),
            );
          }),
        ),
        if (_overallRating > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _getRatingLabel(_overallRating),
              style: TextStyle(
                color: _getRatingColor(_overallRating),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryRatings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate specific aspects (optional)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryRow(
            'Punctuality',
            Icons.access_time_rounded,
            _punctualityRating,
            (rating) => setState(() => _punctualityRating = rating),
          ),
          const SizedBox(height: 12),
          _buildCategoryRow(
            'Professionalism',
            Icons.handshake_rounded,
            _professionalismRating,
            (rating) => setState(() => _professionalismRating = rating),
          ),
          const SizedBox(height: 12),
          _buildCategoryRow(
            'Waste Handling',
            Icons.recycling_rounded,
            _handlingRating,
            (rating) => setState(() => _handlingRating = rating),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    String label,
    IconData icon,
    int rating,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return GestureDetector(
              onTap: () => onChanged(starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  starIndex <= rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 22,
                  color: starIndex <= rating
                      ? const Color(0xFFFFC107)
                      : Colors.grey[300],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCommentField() {
    return TextField(
      controller: _commentController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Add a comment (optional)',
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1F7DD4), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _overallRating == 0 || _isSubmitting
                ? null
                : _submitRating,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F7DD4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit Rating',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _submitRating() async {
    if (_overallRating == 0) return;

    setState(() => _isSubmitting = true);

    try {
      final ratingService = CollectorRatingService();

      final categories = <String, int>{};
      if (_punctualityRating > 0)
        categories['punctuality'] = _punctualityRating;
      if (_professionalismRating > 0)
        categories['professionalism'] = _professionalismRating;
      if (_handlingRating > 0) categories['handling'] = _handlingRating;

      await ratingService.submitRating(
        collectorId: widget.collectorId,
        userId: widget.userId,
        requestId: widget.requestId,
        rating: _overallRating,
        categories: categories,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      widget.onRatingSubmitted?.call();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Thank you for your feedback!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
