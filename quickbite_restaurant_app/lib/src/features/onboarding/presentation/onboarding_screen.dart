import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/merchant_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _brandNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'restaurant';

  final List<String> _businessTypes = ['restaurant', 'grocery', 'meat', 'liquor'];

  void _submit() async {
    if (_brandNameController.text.isEmpty || _emailController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    final success = await ref.read(merchantProvider.notifier).submitOnboarding(
      brandName: _brandNameController.text,
      contactEmail: _emailController.text,
      contactPhone: _phoneController.text,
      businessType: _selectedType,
      description: _descriptionController.text,
    );

    if (success && mounted) {
      // Clear status cache and go to dashboard
      ref.invalidate(merchantStatusProvider);
      context.go('/');
    } else if (mounted) {
      final err = ref.read(merchantProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Onboarding failed')));
    }
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(merchantProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Business'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to QuickBite Manager!', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Tell us a bit about your business to get started.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            
            _buildTextField(controller: _brandNameController, label: 'Brand Name (Required)'),
            const SizedBox(height: 16),
            _buildTextField(controller: _emailController, label: 'Business Email (Required)', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(controller: _phoneController, label: 'Business Phone (Required)', keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            
            Text('Business Type', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: _businessTypes.map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase()))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            
            const SizedBox(height: 16),
            _buildTextField(controller: _descriptionController, label: 'Description', maxLines: 3),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                child: state.isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Complete Onboarding'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
