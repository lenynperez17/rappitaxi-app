import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminNavigationScreen extends StatefulWidget {
  final Widget child;
  
  const AdminNavigationScreen({
    super.key,
    required this.child,
  });
  
  @override
  State<AdminNavigationScreen> createState() => _AdminNavigationScreenState();
}

class _AdminNavigationScreenState extends State<AdminNavigationScreen> {
  int _selectedIndex = 0;
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    switch (index) {
      case 0:
        context.go('/admin/dashboard');
        break;
      case 1:
        context.go('/admin/drivers');
        break;
      case 2:
        context.go('/admin/passengers');
        break;
      case 3:
        context.go('/admin/reports');
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Determinar el índice basado en la ruta actual
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/admin/dashboard')) {
      _selectedIndex = 0;
    } else if (location.startsWith('/admin/drivers')) {
      _selectedIndex = 1;
    } else if (location.startsWith('/admin/passengers')) {
      _selectedIndex = 2;
    } else if (location.startsWith('/admin/reports')) {
      _selectedIndex = 3;
    }
    
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Conductores',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pasajeros',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}