import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/menu_import_service.dart';
import '../domain/product.dart';
import '../../onboarding/data/merchant_repository.dart';

class AIImportScreen extends ConsumerStatefulWidget {
  const AIImportScreen({super.key});

  @override
  ConsumerState<AIImportScreen> createState() => _AIImportScreenState();
}

class _AIImportScreenState extends ConsumerState<AIImportScreen> {
  final ImagePicker _picker = ImagePicker();
  List<Product>? _parsedProducts;
  bool _isLoading = false;

  Future<void> _pickImageAndParse() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final service = ref.read(menuImportServiceProvider);
      final products = await service.parseMenuFromImage(base64Image);

      setState(() {
        _parsedProducts = products;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to parse: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _publishMenu() async {
    if (_parsedProducts == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final storeId = await ref.read(merchantRepositoryProvider).getMyStoreId();
      if (storeId == null) throw Exception('Store not found');
      
      final service = ref.read(menuImportServiceProvider);
      await service.batchSaveMenu(storeId, _parsedProducts!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menu Published Successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save menu: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Menu Wizard 🪄'),
        centerTitle: true,
      ),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.wand2, size: 64, color: Colors.blue)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(begin: -0.1, end: 0.1, duration: 1000.ms),
                const SizedBox(height: 16),
                const Text('AI is cooking up your menu... This takes a few seconds.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1500.ms),
              ],
            ),
          )
        : _parsedProducts == null
            ? _buildUploadState()
            : _buildReviewState(),
    );
  }

  Widget _buildUploadState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.wand2, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Upload a photo of your printed menu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Our AI will read the items, prices, and even generate professional food photos for you automatically!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(LucideIcons.camera),
                label: const Text('Select Menu Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: _pickImageAndParse,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Found ${_parsedProducts!.length} items! Review them below and tap Publish when ready.',
                  style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _parsedProducts!.length,
            itemBuilder: (context, index) {
              final p = _parsedProducts![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          image: p.imageUrl != null 
                            ? DecorationImage(image: NetworkImage(p.imageUrl!), fit: BoxFit.cover)
                            : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('₹${p.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _parsedProducts = null),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _publishMenu,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Publish Menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
