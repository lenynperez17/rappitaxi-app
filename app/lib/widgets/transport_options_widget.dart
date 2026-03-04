// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TransportOptionsWidget extends StatefulWidget {
  final String selectedOption;
  final Function(String) onOptionSelected;
  final Map<String, Map<String, dynamic>> transportOptions;

  const TransportOptionsWidget({
    super.key,
    required this.selectedOption,
    required this.onOptionSelected,
    required this.transportOptions,
  });

  @override
  _TransportOptionsWidgetState createState() => _TransportOptionsWidgetState();
}

class _TransportOptionsWidgetState extends State<TransportOptionsWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 100,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Container(
            height: 160,
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Elige tu transporte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '20% OFF',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.transportOptions.length,
                    itemBuilder: (context, index) {
                      String key = widget.transportOptions.keys.elementAt(index);
                      var option = widget.transportOptions[key]!;
                      bool isSelected = widget.selectedOption == key;
                      
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onOptionSelected(key);
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 140,
                          margin: EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              // Tarjeta principal
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? option['color'].withValues(alpha: 0.1)
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? option['color']
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? option['color'].withValues(alpha: 0.2)
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                      blurRadius: isSelected ? 15 : 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Icono del vehículo
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: option['color'].withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        option['icon'],
                                        color: option['color'],
                                        size: 28,
                                      ),
                                    ),
                                    // Nombre
                                    Text(
                                      option['name'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? option['color']
                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    // Precio y tiempo
                                    Column(
                                      children: [
                                        Text(
                                          option['price'],
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? option['color']
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          option['time'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Badge de selección
                              if (isSelected)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: option['color'],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              
                              // Badge de promoción (solo para premium)
                              if (key == 'premium')
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.tertiary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'VIP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}