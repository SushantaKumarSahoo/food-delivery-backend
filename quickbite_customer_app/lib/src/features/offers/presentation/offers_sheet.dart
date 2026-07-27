import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../data/offers_repository.dart';

class OffersSheet extends ConsumerWidget {
  const OffersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offersAsync = ref.watch(activeOffersProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Available Offers & Coupons',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 12),
          offersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Could not load offers',
                    style: TextStyle(color: Colors.grey.shade500)),
              ),
            ),
            data: (offers) {
              if (offers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.tag, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No active offers right now',
                            style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text('Check back soon for exclusive deals!',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: offers.map((offer) {
                  final codes = (offer['coupons'] as List?)
                      ?.map((c) => c['code']?.toString() ?? '')
                      .where((c) => c.isNotEmpty)
                      .toList() ?? [];
                  final primaryCode = codes.isNotEmpty ? codes.first : null;
                  final discountValue = offer['discountValue'];
                  final campaignType = (offer['campaignType'] ?? '').toString();
                  final discount = campaignType == 'percentage'
                      ? '$discountValue% OFF'
                      : '₹$discountValue OFF';
                  final minOrder = offer['minOrderValue'];
                  final endsAt = offer['endsAt'] != null
                      ? DateTime.tryParse(offer['endsAt'].toString())
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                              color: Colors.amber, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.tag,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(offer['name'] ?? 'Special Offer',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(discount,
                                  style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold)),
                              if (minOrder != null && double.tryParse(minOrder.toString())! > 0)
                                Text('Min order ₹$minOrder',
                                    style: TextStyle(
                                        color: Colors.grey.shade600, fontSize: 12)),
                              if (offer['description'] != null)
                                Text(offer['description'],
                                    style: TextStyle(
                                        color: Colors.grey.shade700, fontSize: 12)),
                              if (endsAt != null)
                                Text(
                                    'Expires ${endsAt.day}/${endsAt.month}/${endsAt.year}',
                                    style: TextStyle(
                                        color: Colors.grey.shade500, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (primaryCode != null)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: primaryCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Code "$primaryCode" copied!')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.shade300,
                                    style: BorderStyle.solid),
                              ),
                              child: Column(
                                children: [
                                  Text(primaryCode,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                          fontSize: 13)),
                                  Text('TAP TO COPY',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.orange.shade700)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
