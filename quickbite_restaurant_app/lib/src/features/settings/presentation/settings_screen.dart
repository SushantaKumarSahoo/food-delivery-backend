import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import 'store_profile_screen.dart';
import '../../menu/presentation/ai_import_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Store Profile'),
            subtitle: const Text('Manage name, description, and location'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreProfileScreen()));
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.access_time),
            title: Text('Operating Hours'),
            subtitle: Text('Manage when your store is open'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.blue),
            title: const Text('AI Menu Wizard', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            subtitle: const Text('Import your printed menu with AI'),
            trailing: const Icon(Icons.chevron_right, color: Colors.blue),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AIImportScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
