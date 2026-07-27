import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dispute_service.dart';

class DisputeScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String orderNumber;
  final double orderAmount;

  const DisputeScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.orderAmount,
  });

  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
  String? _selectedIssue;
  final _descController = TextEditingController();
  bool _isLoading = false;
  DisputeResult? _result;

  static const _issues = [
    ('missing_item', 'Item was missing', LucideIcons.packageX),
    ('wrong_order', 'Wrong order delivered', LucideIcons.alertTriangle),
    ('cold_food', 'Food arrived cold', LucideIcons.thermometer),
    ('quality_issue', 'Poor food quality', LucideIcons.thumbsDown),
    ('late_delivery', 'Very late delivery', LucideIcons.clock),
  ];

  Future<void> _submitDispute() async {
    if (_selectedIssue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an issue type')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(disputeServiceProvider);
      final result = await service.submitDispute(
        orderId: widget.orderId,
        issueType: _selectedIssue!,
        description: _descController.text,
      );
      setState(() => _result = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
      ),
      body: _result != null ? _buildResultView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Order summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.receipt, color: Colors.grey),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order ${widget.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${widget.orderAmount.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('What went wrong?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        // Issue selector chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _issues.map((issue) {
            final isSelected = _selectedIssue == issue.$1;
            return FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(issue.$3, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
              label: Text(issue.$2),
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              onSelected: (_) => setState(() => _selectedIssue = issue.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text('Tell us more (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'E.g. "The paneer was missing from the order..."',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
        const SizedBox(height: 32),
        // AI disclaimer
        Row(
          children: [
            Icon(LucideIcons.bot, size: 16, color: Colors.blue.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Our AI agent will review your request and the order history instantly.',
                style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitDispute,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Submit to AI Agent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final isApproved = _result!.isApproved;
    final isPartial = _result!.isPartial;
    final isDenied = _result!.isDenied;

    Color bgColor;
    Color textColor;
    IconData icon;
    String title;

    if (isApproved) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      icon = LucideIcons.checkCircle2;
      title = 'Full Refund Approved! 🎉';
    } else if (isPartial) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      icon = LucideIcons.alertCircle;
      title = 'Partial Refund Approved';
    } else {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      icon = LucideIcons.xCircle;
      title = 'Refund Declined';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: textColor),
          ),
          const SizedBox(height: 24),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
            child: Text(_result!.reason, style: TextStyle(fontSize: 16, color: textColor, height: 1.5), textAlign: TextAlign.center),
          ),
          if (!isDenied) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.wallet, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '₹${_result!.refundAmount.toStringAsFixed(0)} credited to your wallet',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: const Text('Back to Orders', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
