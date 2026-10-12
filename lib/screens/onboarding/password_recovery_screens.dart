import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';

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
      // TODO: Firebase - await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => OtpScreen(dbService: widget.dbService)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                      icon: Image.asset('assets/images/back_1.png', width: 24),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () => Navigator.pop(context)),
                  const SizedBox(height: 20),
                  const Text('Forgot Password',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  const Text(
                      'Please enter your Email Address to reset the password',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                          height: 1.5)),
                  const SizedBox(height: 30),
                  CustomTextField(
                    hint: 'Email Address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || !val.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  GradientButton(
                    text: 'Reset Password',
                    onPressed: _sendResetEmail,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 2. OTP SCREEN (4 BOXES WITH AUTO-FOCUS)
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
    // TODO: Verify Firebase OTP logic if using Phone Auth, else this is just mock UI for Email link flows.
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
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                    icon: Image.asset('assets/images/back_1.png', width: 24),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(height: 20),
                const Text('Enter OTP',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
                const SizedBox(height: 10),
                const Text(
                    'Please enter the OTP sent to your registered Email Address',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textGrey, height: 1.5)),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) => _buildOtpBox(index)),
                ),
                const SizedBox(height: 30),
                GradientButton(text: 'Verify Code', onPressed: _verifyOtp),
                const SizedBox(height: 20),
                Center(
                  child: RichText(
                      text: const TextSpan(
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textGrey),
                          children: [
                        TextSpan(text: "Haven't got the OTP yet? "),
                        TextSpan(
                            text: "Resend OTP",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                                decoration: TextDecoration.underline)),
                      ])),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 5)
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.primary),
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
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                    icon: Image.asset('assets/images/back_1.png', width: 24),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(height: 20),
                const Text('Password Reset',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
                const SizedBox(height: 10),
                const Text(
                    'Your password has been successfully reset. Click confirm to set a new password.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textGrey, height: 1.5)),
                const SizedBox(height: 30),
                GradientButton(
                    text: 'Confirm',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                SetNewPasswordScreen(dbService: dbService)))),
              ],
            ),
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
      // TODO: Firebase - await user.updatePassword(_passwordController.text);
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SuccessResetScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                      icon: Image.asset('assets/images/back_1.png', width: 24),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () => Navigator.pop(context)),
                  const SizedBox(height: 20),
                  const Text('Set a New Password',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  const Text(
                      'Create a new password. Ensure it is differs from previous ones for security.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                          height: 1.5)),
                  const SizedBox(height: 30),
                  const Text('Password',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  CustomTextField(
                    hint: 'Enter your New Password',
                    isPassword: true,
                    hidePassword: hide1,
                    controller: _passwordController,
                    onEyeTap: () => setState(() => hide1 = !hide1),
                    validator: (val) => val == null || val.length < 6
                        ? 'Min 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  const Text('Confirm Password',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  CustomTextField(
                    hint: 'Re-enter Password',
                    isPassword: true,
                    hidePassword: hide2,
                    controller: _confirmController,
                    onEyeTap: () => setState(() => hide2 = !hide2),
                    validator: (val) => val != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  GradientButton(text: 'Confirm', onPressed: _updatePassword),
                ],
              ),
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                      icon: Image.asset('assets/images/back_1.png', width: 24),
                      onPressed: () => Navigator.pop(context)),
                ),
                const Spacer(),

                // Gradient Checkmark Circle
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 20)
                      ]),
                  child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 50)),
                ),
                const SizedBox(height: 30),

                const Text('Successful',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
                const SizedBox(height: 15),
                const Text(
                    'Congratulations Your password has been\nsuccessfully updated. Click continue to Log In.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textGrey, height: 1.5)),

                const SizedBox(height: 40),
                GradientButton(
                    text: 'Continue',
                    onPressed: () {
                      // Pops everything off the stack and returns to the very first Log In screen
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
