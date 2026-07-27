import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'ai_order_service.dart';
import '../cart/application/cart_provider.dart';

class AiOrderAssistantSheet extends ConsumerStatefulWidget {
  final String storeId;

  const AiOrderAssistantSheet({super.key, required this.storeId});

  @override
  ConsumerState<AiOrderAssistantSheet> createState() => _AiOrderAssistantSheetState();
}

class _AiOrderAssistantSheetState extends ConsumerState<AiOrderAssistantSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  List<AiOrderItem>? _result;
  String? _error;

  final List<String> _suggestions = [
    "2 butter chickens and garlic naan",
    "Add a pizza and coke",
    "One large biryani, extra spicy",
    "Veggie combo for 2 people",
  ];

  Future<void> _submit(String prompt) async {
    if (prompt.isEmpty) return;
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });
    try {
      final service = ref.read(aiOrderServiceProvider);
      final items = await service.parseOrder(prompt, widget.storeId);
      setState(() => _result = items);
    } catch (e) {
      setState(() => _error = 'Could not understand your order. Try rephrasing!');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAllToCart() async {
    if (_result == null || _result!.isEmpty) return;
    setState(() => _isLoading = true);
    final cart = ref.read(cartProvider.notifier);
    for (final item in _result!) {
      await cart.addItem(item.productId, item.quantity);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${_result!.length} item(s) to cart! 🛒'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Ordering Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("Just tell me what you're craving!", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Input Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _submit,
                        decoration: InputDecoration(
                          hintText: 'e.g. "2 butter chickens and naan"',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _submit(_controller.text),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Suggestion chips
              if (_result == null && !_isLoading)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ActionChip(
                      label: Text(_suggestions[i], style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey[100],
                      onPressed: () {
                        _controller.text = _suggestions[i];
                        _submit(_suggestions[i]);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Body
              Expanded(
                child: _isLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Reading the menu and matching your order...', style: TextStyle(color: Colors.grey[600])),
                        ],
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 48),
                                const SizedBox(height: 12),
                                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          )
                        : _result != null
                            ? _buildResult()
                            : const Center(child: Text('Type what you want to order above ☝️', style: TextStyle(color: Colors.grey))),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResult() {
    if (_result!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.searchX, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text("Hmm, I couldn't find those items on this menu.\nTry describing them differently!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(LucideIcons.checkCircle2, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Found ${_result!.length} item(s)! Review and add to cart.',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _result!.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final item = _result![i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                  child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                ),
                title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text('Qty: ${item.quantity}', style: TextStyle(color: Colors.grey[600])),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addAllToCart,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.shoppingCart),
                  SizedBox(width: 8),
                  Text('Add All to Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
