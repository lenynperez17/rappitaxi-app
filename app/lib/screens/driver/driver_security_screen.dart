// ignore_for_file: deprecated_member_use, unused_field, unused_element, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/driver_strings.dart';
import '../../providers/emergency_provider.dart';
import 'package:intl/intl.dart';

class DriverSecurityScreen extends StatefulWidget {
  const DriverSecurityScreen({super.key});

  @override
  State<DriverSecurityScreen> createState() => _DriverSecurityScreenState();
}

class _DriverSecurityScreenState extends State<DriverSecurityScreen> {
  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, size: 28, color: AppColors.getTextPrimary(context)),
                  ),
                  Expanded(
                    child: Center(child: Text(ds.security, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action cards row
                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.chat_bubble_outline,
                            label: ds.support,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSupportChatScreen()));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.people_outline,
                            label: ds.emergencyContacts,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const _EmergencyContactsScreen()));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Emergency call button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('tel:105');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        icon: const Icon(Icons.local_police, color: Colors.white),
                        label: Text(ds.call105, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section title
                    Text(
                      ds.howYouAreProtected,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                    ),
                    const SizedBox(height: 16),

                    // Protection features - tappable grid
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.3,
                      children: [
                        _ProtectionCard(
                          icon: Icons.route,
                          label: ds.tripReview,
                          color: AppColors.rappiRed.withValues(alpha:0.2),
                          onTap: () => _openSafetyCarousel(0),
                        ),
                        _ProtectionCard(
                          icon: Icons.badge,
                          label: ds.passengerVerification,
                          color: AppColors.rappiRed.withValues(alpha:0.2),
                          onTap: () => _openSafetyCarousel(1),
                        ),
                        _ProtectionCard(
                          icon: Icons.phone_locked,
                          label: ds.protectPrivacy,
                          color: AppColors.rappiRed.withValues(alpha:0.2),
                          onTap: () => _openSafetyCarousel(2),
                        ),
                        _ProtectionCard(
                          icon: Icons.security,
                          label: ds.safetyAllTrips,
                          color: AppColors.rappiRed.withValues(alpha:0.2),
                          onTap: () => _openSafetyCarousel(3),
                        ),
                        _ProtectionCard(
                          icon: Icons.warning_amber,
                          label: ds.accidentsSteps,
                          color: const Color(0xFFFFF3CD),
                          onTap: () => _openSafetyCarousel(4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSafetyCarousel(int initialPage) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _SafetyFeaturesCarousel(initialPage: initialPage)),
    );
  }
}

// ─────────────────────────────────────────────────
// ACTION CARD
// ─────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context).withValues(alpha:0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.getTextPrimary(context)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// PROTECTION CARD (tappable)
// ─────────────────────────────────────────────────

class _ProtectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ProtectionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context).withValues(alpha:0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 28, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SAFETY FEATURES CAROUSEL (PageView like inDrive)
// ─────────────────────────────────────────────────

class _SafetyFeaturesCarousel extends StatefulWidget {
  final int initialPage;
  const _SafetyFeaturesCarousel({required this.initialPage});

  @override
  State<_SafetyFeaturesCarousel> createState() => _SafetyFeaturesCarouselState();
}

class _SafetyFeaturesCarouselState extends State<_SafetyFeaturesCarousel> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _controller = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_SafetyPage> _buildPages(DriverStrings ds) {
    return [
      _SafetyPage(
        title: ds.tripReviewTitle,
        description: ds.tripReviewDesc,
        icon: Icons.navigation,
        secondaryIcon: Icons.error_outline,
        bgColor: AppColors.rappiRed,
      ),
      _SafetyPage(
        title: ds.passengerVerificationTitle,
        description: ds.passengerVerificationDesc,
        icon: Icons.verified_user,
        secondaryIcon: Icons.person_search,
        bgColor: AppColors.rappiRed,
      ),
      _SafetyPage(
        title: ds.protectPrivacyTitle,
        description: ds.protectPrivacyDesc,
        icon: Icons.phone_locked,
        secondaryIcon: Icons.shield,
        bgColor: AppColors.rappiRed,
      ),
      _SafetyPage(
        title: ds.safetyAllTripsTitle,
        description: ds.safetyAllTripsDesc,
        icon: Icons.gps_fixed,
        secondaryIcon: Icons.security,
        bgColor: AppColors.rappiRed,
      ),
      _SafetyPage(
        title: ds.accidentsTitle,
        description: ds.accidentsDesc,
        icon: Icons.car_crash,
        secondaryIcon: Icons.medical_services,
        bgColor: const Color(0xFFFF9800),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final pages = _buildPages(ds);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bars
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: List.generate(pages.length, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < pages.length - 1 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? AppColors.rappiRed
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 20, color: Colors.black54),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  final page = pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration with pink/orange shield background
                        SizedBox(
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Shield background
                              CustomPaint(
                                size: const Size(220, 240),
                                painter: _ShieldPainter(color: page.bgColor.withValues(alpha:0.3)),
                              ),
                              // Phone outline
                              Container(
                                width: 120,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black87, width: 3),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble, size: 40, color: page.bgColor),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 60,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 80,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Top right icon circle
                              Positioned(
                                top: 20,
                                right: 30,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black87, width: 2.5),
                                  ),
                                  child: Icon(page.icon, size: 28, color: Colors.black87),
                                ),
                              ),
                              // Bottom right icon circle
                              Positioned(
                                bottom: 30,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black87, width: 2.5),
                                  ),
                                  child: Icon(page.secondaryIcon, size: 24, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Title
                        Text(
                          page.title,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.getTextPrimary(context)),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 16),
                        // Description
                        Text(
                          page.description,
                          style: TextStyle(fontSize: 17, color: Colors.grey.shade700, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < pages.length - 1) {
                      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentPage < pages.length - 1 ? ds.next : ds.understood,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyPage {
  final String title;
  final String description;
  final IconData icon;
  final IconData secondaryIcon;
  final Color bgColor;
  const _SafetyPage({required this.title, required this.description, required this.icon, required this.secondaryIcon, required this.bgColor});
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  _ShieldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.05, size.width, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.75, size.width * 0.5, size.height);
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.75, 0, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.05, size.width * 0.5, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────
// EMERGENCY CONTACTS SCREEN
// ─────────────────────────────────────────────────

class _EmergencyContactsScreen extends StatelessWidget {
  const _EmergencyContactsScreen();

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      body: SafeArea(
        child: Consumer<EmergencyProvider>(
          builder: (context, provider, _) {
            final contacts = provider.contacts;
            return Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(ds.emergencyContactsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, size: 28),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: contacts.isEmpty
                      ? _buildEmptyState(context, provider, ds)
                      : _buildContactsList(context, contacts, provider, ds),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, EmergencyProvider provider, DriverStrings ds) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Illustration
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pink shapes background
                Positioned(
                  left: 40,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      width: 120,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.rappiRed.withValues(alpha:0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 50,
                  top: 10,
                  child: Transform.rotate(
                    angle: 0.15,
                    child: Container(
                      width: 100,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.rappiRed.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Phone with contacts
                Container(
                  width: 140,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black87, width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(height: 4, width: 50, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(height: 3),
                                    Container(height: 3, width: 35, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Alert bubble
                Positioned(
                  right: 40,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black87, width: 2.5),
                    ),
                    child: const Icon(Icons.priority_high, size: 28, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            ds.addUpTo5Contacts,
            style: TextStyle(fontSize: 17, color: Colors.grey.shade700, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
          // Add contact button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showAddContactSheet(context, provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rappiRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(ds.addContact, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList(BuildContext context, List<EmergencyContact> contacts, EmergencyProvider provider, DriverStrings ds) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = contacts[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.rappiRed.withValues(alpha:0.15),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.rappiRed),
                  ),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(c.phone, style: TextStyle(color: Colors.grey.shade600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.rappiRed.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(ds.primary, style: const TextStyle(fontSize: 11, color: AppColors.rappiRed, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showDeleteConfirmation(context, provider, c, ds),
                      child: const Icon(Icons.delete_outline, color: Colors.grey, size: 22),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Add more button (max 5)
        if (contacts.length < 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showAddContactSheet(context, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rappiRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(ds.addContact, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, EmergencyProvider provider, EmergencyContact contact, DriverStrings ds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ds.deleteContact),
        content: Text(ds.deleteContactConfirm(contact.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ds.cancel)),
          TextButton(
            onPressed: () {
              provider.removeEmergencyContact(contact.id);
              Navigator.pop(ctx);
            },
            child: Text(ds.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddContactSheet(BuildContext context, EmergencyProvider provider) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _AddContactScreen(provider: provider)));
  }
}

// ─────────────────────────────────────────────────
// ADD CONTACT SCREEN (Nuevo contacto)
// ─────────────────────────────────────────────────

class _AddContactScreen extends StatefulWidget {
  final EmergencyProvider provider;
  const _AddContactScreen({required this.provider});

  @override
  State<_AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<_AddContactScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Center(child: Text(ds.newContact, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 28),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ds.changesOnlySavedInApp,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context), height: 1.4),
                    ),
                    const SizedBox(height: 24),

                    // Name field
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: ds.contactNameHint,
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phone field with Peru flag
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Peru flag + code
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Row(
                              children: [
                                // Peru flag emoji
                                const Text('🇵🇪', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                                const SizedBox(width: 4),
                                Text('+51', style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          // Phone input
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '912 345 678',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(ds.save, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ds.enterContactName)));
      return;
    }
    if (phone.isEmpty || phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ds.enterValidPhone)));
      return;
    }

    setState(() => _saving = true);

    final fullPhone = '+51$phone';
    final isFirst = widget.provider.contacts.isEmpty;

    final success = await widget.provider.addEmergencyContact(
      name: name,
      phone: fullPhone,
      isPrimary: isFirst,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ds.contactAdded(name))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ds.errorSavingContact)),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────
// SUPPORT CHAT SCREEN (Soporte chatbot style)
// ─────────────────────────────────────────────────

enum _MsgType { bot, user, options, dateSeparator }

class _ChatMsg {
  final _MsgType type;
  final String text;
  final List<String> options;
  final DateTime time;
  final bool read;
  _ChatMsg({required this.type, this.text = '', this.options = const [], DateTime? time, this.read = false})
      : time = time ?? DateTime.now();
}

class DriverSupportChatScreen extends StatefulWidget {
  const DriverSupportChatScreen({super.key});
  @override
  State<DriverSupportChatScreen> createState() => DriverSupportChatScreenState();
}

class DriverSupportChatScreenState extends State<DriverSupportChatScreen> {
  final _messages = <_ChatMsg>[];
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  String _currentStep = 'initial';
  String? _selectedService;
  String? _selectedRole;
  late DriverStrings ds;
  bool _initialized = false;

  // Color for user bubbles and option borders (lime-yellow like inDrive)
  static const _optionBorderColor = Color(0xFFD4E157);
  static const _userBubbleColor = Color(0xFFE6EE9C);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ds = DriverStrings(Localizations.localeOf(context).languageCode);
    if (!_initialized) {
      _initialized = true;
      // Start the conversation
      Future.delayed(const Duration(milliseconds: 400), () {
        _addBotMessage(ds.selectService);
        _addOptions([
          ds.cityTrips,
          ds.intercityTrips,
          ds.freightDelivery,
          ds.courierDelivery,
        ]);
        _addOptionsRow([ds.creditOptions, ds.marketplace]);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(_ChatMsg(type: _MsgType.bot, text: text));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMsg(type: _MsgType.user, text: text, read: true));
    });
    _scrollToBottom();
  }

  void _addOptions(List<String> options) {
    setState(() {
      _messages.add(_ChatMsg(type: _MsgType.options, options: options));
    });
    _scrollToBottom();
  }

  void _addOptionsRow(List<String> options) {
    setState(() {
      _messages.add(_ChatMsg(type: _MsgType.options, options: options));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onOptionSelected(String option) {
    // Remove the options message
    setState(() {
      _messages.removeWhere((m) => m.type == _MsgType.options);
    });

    _addUserMessage(option);

    switch (_currentStep) {
      case 'initial':
        _selectedService = option;
        _currentStep = 'role';
        Future.delayed(const Duration(milliseconds: 500), () {
          _addBotMessage(ds.selectYourRole);
          _addOptions([ds.passenger, ds.driverRole]);
        });
        break;

      case 'role':
        _selectedRole = option;
        _currentStep = 'topic';
        Future.delayed(const Duration(milliseconds: 500), () {
          _addBotMessage(ds.howCanWeHelp);
          _addOptions([
            ds.tripProblem,
            ds.paymentProblem,
            ds.reportIncident,
            ds.accountAndProfile,
            ds.otherTopic,
          ]);
        });
        break;

      case 'topic':
        _currentStep = 'detail';
        Future.delayed(const Duration(milliseconds: 500), () {
          if (option == ds.tripProblem) {
            _addBotMessage(ds.selectProblemType);
            _addOptions([
              ds.incorrectCharge,
              ds.incorrectRoute,
              ds.noShow,
              ds.lostItem,
              ds.other,
            ]);
          } else if (option == ds.paymentProblem) {
            _addBotMessage(ds.selectProblemType);
            _addOptions([
              ds.paymentNotProcessed,
              ds.doubleCharge,
              ds.requestRefund,
              ds.walletProblem,
              ds.other,
            ]);
          } else if (option == ds.reportIncident) {
            _addBotMessage(ds.selectIncidentType);
            _addOptions([
              ds.inappropriateBehavior,
              ds.accident,
              ds.safetyProblem,
              ds.other,
            ]);
          } else if (option == ds.accountAndProfile) {
            _addBotMessage(ds.whatDoYouNeed);
            _addOptions([
              ds.changePersonalData,
              ds.verificationProblems,
              ds.deleteMyAccount,
              ds.other,
            ]);
          } else {
            _addBotMessage(ds.describeProblem);
            _currentStep = 'free';
          }
        });
        break;

      case 'detail':
        _currentStep = 'free';
        Future.delayed(const Duration(milliseconds: 500), () {
          _addBotMessage(ds.agentWillReview(option, _selectedService ?? '', _selectedRole ?? ''));
        });
        break;
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _addUserMessage(text);

    if (_currentStep == 'initial') {
      // Auto-start the flow
      _currentStep = 'role';
      Future.delayed(const Duration(milliseconds: 500), () {
        _addBotMessage(ds.selectYourRole);
        _addOptions([ds.passenger, ds.driverRole]);
      });
    } else if (_currentStep == 'free') {
      Future.delayed(const Duration(milliseconds: 800), () {
        _addBotMessage(ds.thankYouInfo);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(child: Text(ds.support, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  switch (msg.type) {
                    case _MsgType.bot:
                      return _buildBotBubble(msg);
                    case _MsgType.user:
                      return _buildUserBubble(msg);
                    case _MsgType.options:
                      return _buildOptionsBubbles(msg);
                    case _MsgType.dateSeparator:
                      return _buildDateSeparator(msg);
                  }
                },
              ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // Attachment icon
                  Icon(Icons.attach_file, color: Colors.grey.shade500, size: 24),
                  const SizedBox(width: 8),
                  // Text input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: ds.writeYourMessage,
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendTextMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: _sendTextMessage,
                    child: Icon(Icons.send, color: Colors.grey.shade400, size: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotBubble(_ChatMsg msg) {
    final timeStr = DateFormat('h:mm a', 'es').format(msg.time).toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(msg.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                  ),
                  const SizedBox(width: 8),
                  Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(_ChatMsg msg) {
    final timeStr = DateFormat('h:mm a', 'es').format(msg.time).toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                color: _userBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(msg.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                  const SizedBox(width: 8),
                  Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  const SizedBox(width: 4),
                  Icon(
                    msg.read ? Icons.done_all : Icons.done,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsBubbles(_ChatMsg msg) {
    // If options fit in a row (2 items, short text), show as row
    final isRow = msg.options.length == 2 && msg.options.every((o) => o.length < 22);

    if (isRow) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: msg.options.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildOptionChip(opt),
            );
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: msg.options.map((opt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildOptionChip(opt),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOptionChip(String text) {
    return GestureDetector(
      onTap: () => _onOptionSelected(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _optionBorderColor, width: 1.5),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildDateSeparator(_ChatMsg msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          msg.text,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ),
    );
  }
}
