import 'dart:ui';
import 'package:flutter/material.dart';
import 'main.dart';

class AdminLoginPage extends StatefulWidget {
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String errorMessage = "";
  bool isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  void login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => errorMessage = "Please enter both credentials");
      return;
    }

    setState(() => isLoading = true);

    try {
      final success = await AppState.instance.loginAdmin(username, password);
      setState(() => isLoading = false);
      if (success) {
        Navigator.pop(context);
      } else {
        setState(() => errorMessage = "Invalid credentials");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Server unreachable";
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Premium Background Layer
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E003E), Color(0xFF0F0B1E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // 2. Decorative Floating Blur Orbs (for depth)
          Positioned(
            top: -50,
            right: -50,
            child: _buildBlurOrb(180, Colors.deepPurple.withOpacity(0.3)),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _buildBlurOrb(220, Colors.indigo.withOpacity(0.2)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            // Branding Section
                            Hero(
                              tag: 'logo',
                              child: Image.asset(
                                'assets/logo.png',
                                height: 100,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.shield,
                                        size: 80, color: Colors.white70),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "ADMINISTRATION",
                              style: TextStyle(
                                color: jmcSunglow.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "TrackAccess Portal",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w200,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // 3. High-End Glassmorphic Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildModernTextField(
                                    controller: _usernameController,
                                    label: "Username",
                                    icon: Icons.person_rounded,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildModernTextField(
                                    controller: _passwordController,
                                    label: "Password",
                                    icon: Icons.lock_rounded,
                                    isPassword: true,
                                  ),
                                  const SizedBox(height: 40),
                                  _buildPremiumButton(),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => AdminRegisterPage()));
                                        },
                                        child: const Text("Register", style: TextStyle(color: jmcSunglow, fontSize: 12)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => AdminResetPasswordPage()));
                                        },
                                        child: const Text("Forgot Password?", style: TextStyle(color: jmcSunglow, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                  if (errorMessage.isNotEmpty) _buildErrorText(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.4),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontSize: 14, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            prefixIcon: Icon(icon, color: Colors.white54, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: jmcSunglow, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [jmcSunglow, Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: jmcSunglow.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF1E003E),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "LOGIN",
                style: TextStyle(
                  color: Color(0xFF1E003E),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorText() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Text(
        errorMessage,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class AdminRegisterPage extends StatefulWidget {
  @override
  State<AdminRegisterPage> createState() => _AdminRegisterPageState();
}

class _AdminRegisterPageState extends State<AdminRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _securityQController = TextEditingController(text: "What is your first pet's name?");
  final _securityAController = TextEditingController();

  String errorMessage = "";
  String successMessage = "";
  bool isLoading = false;

  void register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();
    final sq = _securityQController.text.trim();
    final sa = _securityAController.text.trim();

    if (username.isEmpty || password.isEmpty || email.isEmpty || sa.isEmpty) {
      setState(() => errorMessage = "Please fill all fields");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    final success = await AppState.instance.registerAdmin(username, password, email, sq, sa);
    setState(() => isLoading = false);

    if (success) {
      setState(() => successMessage = "Admin successfully registered!");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() => errorMessage = "Registration failed (username/email may exist)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Admin"), backgroundColor: const Color(0xFF1E003E)),
      backgroundColor: const Color(0xFF0F0B1E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Username", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _securityQController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Security Question", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _securityAController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Security Answer", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(color: Colors.redAccent)),
                  if (successMessage.isNotEmpty) Text(successMessage, style: const TextStyle(color: Colors.green)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isLoading ? null : register,
                    style: ElevatedButton.styleFrom(backgroundColor: jmcSunglow, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                    child: isLoading ? const CircularProgressIndicator() : const Text("Register"),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminResetPasswordPage extends StatefulWidget {
  @override
  State<AdminResetPasswordPage> createState() => _AdminResetPasswordPageState();
}

class _AdminResetPasswordPageState extends State<AdminResetPasswordPage> {
  final _emailController = TextEditingController();
  final _securityAController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String errorMessage = "";
  String successMessage = "";
  bool isLoading = false;

  void resetPassword() async {
    final email = _emailController.text.trim();
    final sa = _securityAController.text.trim();
    final np = _newPasswordController.text.trim();

    if (email.isEmpty || sa.isEmpty || np.isEmpty) {
      setState(() => errorMessage = "Please fill all fields");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    final success = await AppState.instance.resetAdminPassword(email, sa, np);
    setState(() => isLoading = false);

    if (success) {
      setState(() => successMessage = "Password successfully reset!");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() => errorMessage = "Reset failed. Invalid email or security answer.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password"), backgroundColor: const Color(0xFF1E003E)),
      backgroundColor: const Color(0xFF0F0B1E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Account Email", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _securityAController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Security Answer (What is your first pet's name?)", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "New Password", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                ),
                const SizedBox(height: 24),
                if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(color: Colors.redAccent)),
                if (successMessage.isNotEmpty) Text(successMessage, style: const TextStyle(color: Colors.green)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : resetPassword,
                  style: ElevatedButton.styleFrom(backgroundColor: jmcSunglow, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                  child: isLoading ? const CircularProgressIndicator() : const Text("Update Password"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}