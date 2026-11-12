import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_localizations.dart';
import 'sign_up_screen.dart';
import 'log_in_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final DatabaseService dbService;
  const WelcomeScreen({super.key, required this.dbService});

  Widget _buildValueProp(
      IconData icon, String title, String desc, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: colors.textDark)),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(
                        fontSize: 11, color: colors.textGrey, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            const TriggerLensLogo(
                size: 140, showText: true, isHorizontal: false),
            const SizedBox(height: 30),

            // VALUE PROPOSITION SECTION
            _buildValueProp(Icons.security_outlined, loc.loc('val_secure_sync'),
                loc.loc('val_secure_sync_desc'), colors),
            _buildValueProp(
                Icons.color_lens_outlined,
                loc.loc('val_personalize'),
                loc.loc('val_personalize_desc'),
                colors),
            _buildValueProp(Icons.analytics_outlined, loc.loc('val_analytics'),
                loc.loc('val_analytics_desc'), colors),

            const Spacer(flex: 2),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: colors.primary.withOpacity(0.4),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SignUpScreen(dbService: dbService)),
                    );
                  },
                  child: Text(
                    loc.loc('create_account'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            LogInScreen(dbService: dbService)),
                  );
                },
                child: Text(
                  loc.loc('already_have_account'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryDark,
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
