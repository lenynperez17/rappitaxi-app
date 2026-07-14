import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla legacy: la analítica admin se movió al panel web.
/// https://panel-rapi-team.nyneln8n.com
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const _panelUrl = 'https://panel-rapi-team.nyneln8n.com';

  Future<void> _openPanel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(_panelUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el panel web')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analitica')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 96,
                color: Color(0xFFFF6B00),
              ),
              const SizedBox(height: 24),
              const Text(
                'Panel admin movido a la web',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'https://panel-rapi-team.nyneln8n.com',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _openPanel(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir panel'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
