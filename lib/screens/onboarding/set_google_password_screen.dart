import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/ui_helpers.dart';
import 'path_screen.dart';
import '../../services/database_service.dart';

class SetGooglePasswordScreen extends StatefulWidget {
  final DatabaseService dbService;
  const SetGooglePasswordScreen({super.key, required this.dbService});

  @override
  State<SetGooglePasswordScreen> createState() =>
      _SetGooglePasswordScreenState();
}

class _SetGooglePasswordScreenState extends State<SetGooglePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText1 = true;
  bool _obscureText2 = true;

  Future<void> _savePassword() async {
    final pass = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // This links the new password to their Google Account
        await user.updatePassword(pass);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('App Password Set Successfully!'),
                backgroundColor: Colors.green),
          );
          // Navigate to PathScreen and pass the database service safely
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => PathScreen(dbService: widget.dbService)),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const TriggerLensLogo(size: 60, showText: false),
              const SizedBox(height: 30),
              const Text('Secure Your Account',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const SizedBox(height: 10),
              const Text(
                  'Since you signed in with Google, please set a backup password for TriggerLens. This allows you to log in via email and use password recovery in the future.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textGrey, height: 1.5)),
              const SizedBox(height: 40),
              CustomTextField(
                hint: 'Create Password',
                isPassword: true,
                hidePassword: _obscureText1,
                controller: _passwordController,
                onEyeTap: () => setState(() => _obscureText1 = !_obscureText1),
              ),
              CustomTextField(
                hint: 'Confirm Password',
                isPassword: true,
                hidePassword: _obscureText2,
                controller: _confirmController,
                onEyeTap: () => setState(() => _obscureText2 = !_obscureText2),
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : GradientButton(
                      text: 'Save & Continue', onPressed: _savePassword),
            ],
          ),
        ),
      ),
    );
  }
}
