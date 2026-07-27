import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/api/api_client.dart';

class ReviewSheet extends ConsumerStatefulWidget {
  final String orderId;
  final String storeId;
  final String storeName;

  const ReviewSheet({
    super.key,
    required this.orderId,
    required this.storeId,
    required this.storeName,
  });

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  int _overallRating = 0;
  int _foodRating = 0;
  int _deliveryRating = 0;
  final _bodyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give an overall rating')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/reviews', data: {
        'orderId': widget.orderId,
        'entityId': widget.storeId,
        'reviewType': 'store',
        'overallRating': _overallRating,
        'foodRating': _foodRating > 0 ? _foodRating : null,
        'deliveryRating': _deliveryRating > 0 ? _deliveryRating : null,
        'body': _bodyController.text.trim().isNotEmpty ? _bodyController.text.trim() : null,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your review! 🙏'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data['message'] ?? 'Failed to submit review')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Rate your order from\n${widget.storeName}',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
            ],
          ),
          const SizedBox(height: 20),

          // Overall rating
          Text('Overall Experience', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _StarRow(rating: _overallRating, size: 40, onChanged: (v) => setState(() => _overallRating = v)),
          const SizedBox(height: 20),

          // Food rating
          Text('Food Quality', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          _StarRow(rating: _foodRating, size: 28, onChanged: (v) => setState(() => _foodRating = v)),
          const SizedBox(height: 16),

          // Delivery rating
          Text('Delivery Experience', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          _StarRow(rating: _deliveryRating, size: 28, onChanged: (v) => setState(() => _deliveryRating = v)),
          const SizedBox(height: 20),

          // Comment
          TextField(
            controller: _bodyController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tell us more about your experience (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int> onChanged;

  const _StarRow({required this.rating, required this.size, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              color: filled ? Colors.amber : Colors.grey.shade400,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}
