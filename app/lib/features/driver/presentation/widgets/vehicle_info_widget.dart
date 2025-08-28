import 'package:flutter/material.dart';

class VehicleInfoWidget extends StatelessWidget {
  final String? plate;
  final String? model;
  final String? color;
  
  const VehicleInfoWidget({
    Key? key,
    this.plate,
    this.model,
    this.color,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información del Vehículo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Placa: ${plate ?? "No registrada"}'),
            Text('Modelo: ${model ?? "No registrado"}'),
            Text('Color: ${color ?? "No registrado"}'),
          ],
        ),
      ),
    );
  }
}
