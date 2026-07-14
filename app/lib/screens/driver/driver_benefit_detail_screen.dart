import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/driver_strings.dart';

class BenefitPage {
  final IconData icon;
  final String title;
  final String description;
  final String level; // 'Básico' or 'Platino'
  final bool locked;

  const BenefitPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.level,
    required this.locked,
  });
}

List<BenefitPage> getAllBenefits(DriverStrings ds) => [
  BenefitPage(
    icon: Icons.arrow_downward,
    title: ds.lowServicePayments,
    description: ds.lowServicePaymentsDetailDesc,
    level: ds.basic,
    locked: false,
  ),
  BenefitPage(
    icon: Icons.sort,
    title: ds.firstToGetRequests,
    description: ds.firstToGetRequestsDetailDesc,
    level: ds.platinum,
    locked: true,
  ),
  BenefitPage(
    icon: Icons.headset_mic_outlined,
    title: ds.highPrioritySupport,
    description: ds.highPrioritySupportDetailDesc,
    level: ds.platinum,
    locked: true,
  ),
  BenefitPage(
    icon: Icons.send,
    title: ds.autoAcceptRequests,
    description: ds.autoAcceptRequestsDetailDesc,
    level: ds.platinum,
    locked: true,
  ),
  BenefitPage(
    icon: Icons.star_border,
    title: ds.featuredProfile,
    description: ds.featuredProfileDetailDesc,
    level: ds.platinum,
    locked: true,
  ),
  BenefitPage(
    icon: Icons.local_offer_outlined,
    title: ds.partnerBonus,
    description: ds.partnerBonusDetailDesc,
    level: ds.platinum,
    locked: true,
  ),
];

class DriverBenefitDetailScreen extends StatefulWidget {
  final int initialIndex;

  const DriverBenefitDetailScreen({super.key, this.initialIndex = 0});

  @override
  State<DriverBenefitDetailScreen> createState() => _DriverBenefitDetailScreenState();
}

class _DriverBenefitDetailScreenState extends State<DriverBenefitDetailScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final benefits = getAllBenefits(ds);
    final isLastPage = _currentPage == benefits.length - 1;

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: 28, color: AppColors.getTextPrimary(context)),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: benefits.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final benefit = benefits[index];
                  return _buildBenefitPage(benefit, ds);
                },
              ),
            ),

            // Page indicator dots
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(benefits.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.getTextPrimary(context)
                          : AppColors.getTextSecondary(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (isLastPage) {
                      Navigator.pop(context);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isLastPage ? ds.accept : ds.next,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitPage(BenefitPage benefit, DriverStrings ds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration area
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: AppColors.rappiRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background accent shapes
                    Positioned(
                      top: 20,
                      right: 30,
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.rappiRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 30,
                      left: 20,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.rappiRed.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    // Main icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(benefit.icon, size: 56, color: AppColors.getTextPrimary(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tags
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Level tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: benefit.level == ds.basic
                            ? AppColors.rappiRed.withValues(alpha: 0.1)
                            : const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.diamond, size: 14,
                            color: benefit.level == ds.basic ? AppColors.rappiRed : const Color(0xFF7C4DFF),
                          ),
                          const SizedBox(width: 4),
                          Text(benefit.level, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: benefit.level == ds.basic ? AppColors.rappiRed : const Color(0xFF7C4DFF),
                          )),
                        ],
                      ),
                    ),
                    if (benefit.locked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: AppColors.getTextSecondary(context)),
                            const SizedBox(width: 4),
                            Text(ds.locked, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextSecondary(context))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  benefit.title,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context), height: 1.2),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  benefit.description,
                  style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
