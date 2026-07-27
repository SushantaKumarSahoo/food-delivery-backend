import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../data/offers_repository.dart';

class GiftCardSheet extends ConsumerStatefulWidget {
  const GiftCardSheet({super.key});

  @override
  ConsumerState<GiftCardSheet> createState() => _GiftCardSheetState();
}

class _GiftCardSheetState extends ConsumerState<GiftCardSheet> {
  final _codeController = TextEditingController();
  bool _isRedeeming = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isRedeeming = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(offersRepositoryProvider).redeemGiftCard(code);
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _successMessage =
              'Gift card redeemed! ₹${result['discountAmount']?.toStringAsFixed(0) ?? ''} applied to your account.';
          _codeController.clear();
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _errorMessage =
              e.response?.data['message'] ?? 'Invalid or already used gift card.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gift Cards & Vouchers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Redeem a gift card or voucher code to add balance to your QuickBite wallet.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Gift card visual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.gift, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QuickBite Gift Card',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text('Valid on all orders',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Code input
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Enter Gift Card Code',
              hintText: 'e.g. GIFT4XK29A',
              prefixIcon: const Icon(LucideIcons.tag),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: _codeController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => setState(() => _codeController.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Success / error message
          if (_successMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.checkCircle2,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_successMessage!,
                        style: TextStyle(
                            color: Colors.green.shade800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!,
                        style:
                            TextStyle(color: Colors.red.shade800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_isRedeeming || _codeController.text.trim().isEmpty)
                  ? null
                  : _redeem,
              icon: _isRedeeming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.gift),
              label: Text(
                _isRedeeming ? 'Redeeming...' : 'Redeem Gift Card',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Gift cards are added to your QuickBite wallet instantly.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
