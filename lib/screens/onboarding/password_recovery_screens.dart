import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_localizations.dart'; // NEW: Localization Engine

// ----------------------------------------------------------------------
// 1. FORGOT PASSWORD (EMAIL ENTRY)
// ----------------------------------------------------------------------
class ForgotPasswordScreen extends StatefulWidget {
  final DatabaseService dbService;
  const ForgotPasswordScreen({super.key, required this.dbService});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _sendResetEmail() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => OtpScreen(dbService: widget.dbService)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                    icon: Image.asset('assets/images/back_1.png',
                        width: 24, color: colors.textDark),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(height: 20),
                Text(loc.loc('forgot_password_title'),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colors.textDark)),
                const SizedBox(height: 10),
                Text(loc.loc('forgot_password_desc'),
                    style: TextStyle(
                        fontSize: 11, color: colors.textGrey, height: 1.5)),
                const SizedBox(height: 30),
                CustomTextField(
                  hint: loc.loc('email_address'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@')
                      ? loc.loc('invalid_email_format')
                      : null,
                ),
                const SizedBox(height: 10),
                GradientButton(
                  text: loc.loc('reset_password_btn'),
                  onPressed: _sendResetEmail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 2. OTP SCREEN
// ----------------------------------------------------------------------
class OtpScreen extends StatefulWidget {
  final DatabaseService dbService;
  const OtpScreen({super.key, required this.dbService});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());

  void _verifyOtp() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                PasswordResetConfirmScreen(dbService: widget.dbService)));
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                  icon: Image.asset('assets/images/back_1.png',
                      width: 24, color: colors.textDark),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 20),
              Text(loc.loc('enter_otp'),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colors.textDark)),
              const SizedBox(height: 10),
              Text(loc.loc('enter_otp_desc'),
                  style: TextStyle(
                      fontSize: 11, color: colors.textGrey, height: 1.5)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:
                    List.generate(4, (index) => _buildOtpBox(index, colors)),
              ),
              const SizedBox(height: 30),
              GradientButton(
                  text: loc.loc('verify_code'), onPressed: _verifyOtp),
              const SizedBox(height: 20),
              Center(
                child: RichText(
                    text: TextSpan(
                        style: TextStyle(fontSize: 10, color: colors.textGrey),
                        children: [
                      TextSpan(text: loc.loc('no_otp_yet')),
                      TextSpan(
                          text: loc.loc('resend_otp'),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.textDark,
                              decoration: TextDecoration.underline)),
                    ])),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index, AppColors colors) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.primary.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: colors.primary.withOpacity(0.1), blurRadius: 5)
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900, color: colors.primary),
          decoration:
              const InputDecoration(counterText: "", border: InputBorder.none),
          onChanged: (value) {
            if (value.isNotEmpty && index < 3) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else if (value.isEmpty && index > 0) {
              FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
            }
          },
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 3. MIDDLE CONFIRMATION SCREEN
// ----------------------------------------------------------------------
class PasswordResetConfirmScreen extends StatelessWidget {
  final DatabaseService dbService;
  const PasswordResetConfirmScreen({super.key, required this.dbService});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                  icon: Image.asset('assets/images/back_1.png',
                      width: 24, color: colors.textDark),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 20),
              Text(loc.loc('password_reset_title'),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colors.textDark)),
              const SizedBox(height: 10),
              Text(loc.loc('password_reset_success_desc'),
                  style: TextStyle(
                      fontSize: 11, color: colors.textGrey, height: 1.5)),
              const SizedBox(height: 30),
              GradientButton(
                  text: loc.loc('confirm_btn'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SetNewPasswordScreen(dbService: dbService)))),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 4. SET NEW PASSWORD SCREEN
// ----------------------------------------------------------------------
class SetNewPasswordScreen extends StatefulWidget {
  final DatabaseService dbService;
  const SetNewPasswordScreen({super.key, required this.dbService});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool hide1 = true;
  bool hide2 = true;

  void _updatePassword() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SuccessResetScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                    icon: Image.asset('assets/images/back_1.png',
                        width: 24, color: colors.textDark),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(height: 20),
                Text(loc.loc('set_new_password'),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colors.textDark)),
                const SizedBox(height: 10),
                Text(loc.loc('set_new_password_desc'),
                    style: TextStyle(
                        fontSize: 11, color: colors.textGrey, height: 1.5)),
                const SizedBox(height: 30),
                Text(loc.loc('password'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textDark)),
                const SizedBox(height: 8),
                CustomTextField(
                  hint: loc.loc('enter_new_password'),
                  isPassword: true,
                  hidePassword: hide1,
                  controller: _passwordController,
                  onEyeTap: () => setState(() => hide1 = !hide1),
                  validator: (val) => val == null || val.length < 6
                      ? loc.loc('min_6_chars')
                      : null,
                ),
                const SizedBox(height: 10),
                Text(loc.loc('confirm_password'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textDark)),
                const SizedBox(height: 8),
                CustomTextField(
                  hint: loc.loc('reenter_password'),
                  isPassword: true,
                  hidePassword: hide2,
                  controller: _confirmController,
                  onEyeTap: () => setState(() => hide2 = !hide2),
                  validator: (val) => val != _passwordController.text
                      ? loc.loc('mismatch')
                      : null,
                ),
                const SizedBox(height: 20),
                GradientButton(
                    text: loc.loc('confirm_btn'), onPressed: _updatePassword),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 5. SUCCESS SCREEN
// ----------------------------------------------------------------------
class SuccessResetScreen extends StatelessWidget {
  const SuccessResetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                    icon: Image.asset('assets/images/back_1.png',
                        width: 24, color: colors.textDark),
                    onPressed: () => Navigator.pop(context)),
              ),
              const Spacer(),

              // Gradient Checkmark Circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: colors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                          color: colors.primary.withOpacity(0.4),
                          blurRadius: 20)
                    ]),
                child: const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 50)),
              ),
              const SizedBox(height: 30),

              Text(loc.loc('successful_title'),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: colors.textDark)),
              const SizedBox(height: 15),
              Text(loc.loc('successful_reset_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: colors.textGrey, height: 1.5)),

              const SizedBox(height: 40),
              GradientButton(
                  text: loc.loc('continue_btn'),
                  onPressed: () {
                    // Pops everything off the stack and returns to the very first Log In screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
