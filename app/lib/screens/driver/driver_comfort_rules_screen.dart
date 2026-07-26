import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/driver_strings.dart';

class ComfortRulePage {
  final IconData icon;
  final String title;
  final String description;
  final String? subtitle;
  final Color bgColor;

  const ComfortRulePage({
    required this.icon,
    required this.title,
    required this.description,
    this.subtitle,
    required this.bgColor,
  });
}

class DriverComfortRulesScreen extends StatefulWidget {
  final int initialPage;
  const DriverComfortRulesScreen({super.key, this.initialPage = 0});

  @override
  State<DriverComfortRulesScreen> createState() => _DriverComfortRulesScreenState();
}

class _DriverComfortRulesScreenState extends State<DriverComfortRulesScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  List<ComfortRulePage> _rulesPages(DriverStrings ds) => [
    ComfortRulePage(
      icon: Icons.emoji_events,
      title: ds.comfortWelcomeTitle,
      description: ds.comfortWelcomeDesc,
      subtitle: ds.comfortWelcomeSubtitle,
      bgColor: const Color(0xFFFFF8E1),
    ),
    ComfortRulePage(
      icon: Icons.ac_unit,
      title: ds.comfortAcTitle,
      description: ds.comfortAcDesc,
      bgColor: const Color(0xFFE8F5E9),
    ),
    ComfortRulePage(
      icon: Icons.cleaning_services,
      title: ds.comfortCleanTitle,
      description: ds.comfortCleanDesc,
      bgColor: const Color(0xFFE3F2FD),
    ),
    ComfortRulePage(
      icon: Icons.water_drop,
      title: ds.comfortWaterTitle,
      description: ds.comfortWaterDesc,
      bgColor: const Color(0xFFF3E5F5),
    ),
    ComfortRulePage(
      icon: Icons.music_note,
      title: ds.comfortMusicTitle,
      description: ds.comfortMusicDesc,
      bgColor: const Color(0xFFFCE4EC),
    ),
    ComfortRulePage(
      icon: Icons.star,
      title: ds.comfortRatingTitle,
      description: ds.comfortRatingDesc,
      bgColor: const Color(0xFFFFF3E0),
    ),
  ];

  List<ComfortRulePage> _requirementsPages(DriverStrings ds) => [
    ComfortRulePage(
      icon: Icons.directions_car,
      title: ds.comfortVehicleTitle,
      description: ds.comfortVehicleDesc,
      bgColor: const Color(0xFFFFF8E1),
    ),
    ComfortRulePage(
      icon: Icons.verified,
      title: ds.comfortDocsTitle,
      description: ds.comfortDocsDesc,
      bgColor: const Color(0xFFE8F5E9),
    ),
    ComfortRulePage(
      icon: Icons.person_pin,
      title: ds.comfortPresentationTitle,
      description: ds.comfortPresentationDesc,
      bgColor: const Color(0xFFE3F2FD),
    ),
    ComfortRulePage(
      icon: Icons.thumb_up,
      title: ds.comfortReadyTitle,
      description: ds.comfortReadyDesc,
      bgColor: const Color(0xFFFCE4EC),
    ),
  ];

  bool _isRequirements = false;

  @override
  void initState() {
    super.initState();
    _isRequirements = widget.initialPage == 1;
    _pageController = PageController();
    _currentPage = 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final pages = _isRequirements ? _requirementsPages(ds) : _rulesPages(ds);
    return Scaffold(
      body: Stack(
        children: [
          // Page content
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final page = pages[index];
              return Container(
                color: page.bgColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),
                        // Title
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.getTextPrimary(context),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Description
                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.getTextSecondary(context),
                            height: 1.5,
                          ),
                        ),
                        if (page.subtitle != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            page.subtitle!,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Illustration area
                        Center(
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              color: AppColors.rappiRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(130),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background shapes
                                Positioned(
                                  left: 20,
                                  top: 30,
                                  child: Transform.rotate(
                                    angle: -0.3,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: AppColors.rappiRed.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 30,
                                  bottom: 40,
                                  child: Transform.rotate(
                                    angle: 0.4,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.rappiRed.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                // Main icon
                                Icon(
                                  page.icon,
                                  size: 100,
                                  color: AppColors.rappiRed.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Top bar with dots and close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Page indicators
                    Expanded(
                      child: Row(
                        children: List.generate(pages.length, (index) {
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: index <= _currentPage
                                    ? Colors.black54
                                    : Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage < pages.length - 1 ? ds.next : ds.understood,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
