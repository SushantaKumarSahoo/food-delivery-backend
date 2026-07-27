import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../data/payment_repository.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  String? _error;
  String? _cfOrderId;

  late final PaymentRepository _paymentRepository;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();

  @override
  void initState() {
    super.initState();
    _cfService.setCallback(_onPaymentVerify, _onPaymentError);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ProviderScope is accessible via context after first frame
    _paymentRepository =
        ProviderScope.containerOf(context).read(paymentRepositoryProvider);
  }

  // SDK calls this with the cfOrderId on success
  void _onPaymentVerify(String orderId) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await _paymentRepository.verifyPayment(orderId);
      final status = (result['order_status'] ?? '').toString().toUpperCase();
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showResult(success: status == 'PAID', message: status != 'PAID' ? 'Status: $status' : null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showResult(success: false, message: e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _onPaymentError(CFErrorResponse error, String orderId) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = error.getMessage() ?? 'Payment failed. Please try again.';
    });
  }

  void _showResult({required bool success, String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
              color: success ? Colors.green : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Payment Successful!' : 'Payment Failed',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (success) {
                  context.go('/home');
                }
              },
              child: Text(success ? 'Go to Home' : 'Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPayment(String methodType) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data =
          await _paymentRepository.initiatePayment(widget.orderId, methodType);

      _cfOrderId = data['cfOrderId'] as String;
      final sessionId = data['paymentSessionId'] as String;
      final env = (data['environment'] ?? 'sandbox') as String;

      final cfEnvironment =
          env == 'production' ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX;

      final session = CFSessionBuilder()
          .setEnvironment(cfEnvironment)
          .setOrderId(_cfOrderId!)
          .setPaymentSessionId(sessionId)
          .build();

      final payment =
          CFWebCheckoutPaymentBuilder().setSession(session).build();

      setState(() => _isLoading = false);
      _cfService.doPayment(payment);
    } on CFException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up payment...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Amount to Pay',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
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
                            child: Text(_error!,
                                style: TextStyle(
                                    color: Colors.red.shade800, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  Text('Pay with UPI',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  _PaymentOption(
                    fallbackIcon: LucideIcons.smartphone,
                    title: 'UPI (GPay / PhonePe / Paytm)',
                    subtitle: 'Pay directly from your bank account',
                    color: Colors.purple,
                    onTap: () => _startPayment('upi'),
                  ),

                  const SizedBox(height: 24),
                  Text('Cards & Net Banking',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  _PaymentOption(
                    fallbackIcon: LucideIcons.creditCard,
                    title: 'Credit / Debit Card',
                    subtitle: 'Visa, Mastercard, RuPay',
                    color: Colors.blue,
                    onTap: () => _startPayment('card'),
                  ),
                  const SizedBox(height: 12),
                  _PaymentOption(
                    fallbackIcon: LucideIcons.landmark,
                    title: 'Net Banking',
                    subtitle: 'All major banks supported',
                    color: Colors.teal,
                    onTap: () => _startPayment('netbanking'),
                  ),

                  const SizedBox(height: 24),
                  Text('Other',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  _PaymentOption(
                    fallbackIcon: LucideIcons.banknote,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay when your order arrives',
                    color: Colors.green,
                    onTap: () => _startPayment('cod'),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.shieldCheck,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Payments secured by Cashfree',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(fallbackIcon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}
