import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/localization_service.dart';

/// Supported villages — display name → canonical Firestore ID.
/// Add new villages here to make them selectable during registration.
const _kVillages = [
  _VillageOption(id: 'OZH-01', nameEn: 'Ozhar (Jawhar, Palghar)', nameMr: 'ओझर (जव्हार, पालघर)'),
  _VillageOption(id: 'JWH-01', nameEn: 'Jawhar (Jawhar, Palghar)', nameMr: 'जव्हार (जव्हार, पालघर)'),
  _VillageOption(id: 'KKD-01', nameEn: 'Khokad (Mokhada, Palghar)', nameMr: 'खोकड (मोखाडा, पालघर)'),
];

class _VillageOption {
  final String id;
  final String nameEn;
  final String nameMr;
  const _VillageOption({required this.id, required this.nameEn, required this.nameMr});
}

/// VanMitra-AI — Email / Password Login and Registration Screen
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  bool _isLogin = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  String _selectedRole = 'villager';
  // Village is always selected from the list — never typed manually
  String _selectedVillageId = _kVillages.first.id;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? role;
    if (_isLogin) {
      role = await ref.read(authProvider.notifier).login(email, password);
    } else {
      final name = _nameController.text.trim();
      // villageId comes from the dropdown — never user-typed
      role = await ref.read(authProvider.notifier).register(
        email, password, name, _selectedRole, _selectedVillageId,
      );
    }

    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, AppRouter.adminHome);
    } else if (role == 'villager') {
      Navigator.pushReplacementNamed(context, AppRouter.villagerHome);
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.cfrRoleDashboard);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final localizations = AppLocalizations.of(context);
    final isLoading = authState.isLoading;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage &&
          mounted) {
        _showError(next.errorMessage!);
        ref.read(authProvider.notifier).clearError();
      }
    });

    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: c.scaffoldBg,
        elevation: 0,
        title: Text(
          'वनमित्र | VanMitra',
          style: TextStyle(
            fontSize: 16,
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Row(
            children: [
              Expanded(child: Container(height: 3, color: AppColors.secondary)),
              Expanded(child: Container(height: 3, color: c.border)),
              Expanded(child: Container(height: 3, color: AppColors.success)),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Heading ──────────────────────────────────────────────
                Text(
                  _isLogin ? localizations.loginTitle : 'Create Account',
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? localizations.loginSubtitle
                      : 'Sign up to join your Gram Panchayat on VanMitra',
                  style: TextStyle(
                    fontSize: 16,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Fields ────────────────────────────────────
                
                if (!_isLogin) ...[
                  _buildLabel('Full Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    enabled: !isLoading,
                    decoration: _inputDecoration('Enter your name', Icons.person_outline),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 20),
                ],

                _buildLabel('Email Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Enter your email', Icons.email_outlined),
                  validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 20),

                _buildLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration('Enter your password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 20),

                if (!_isLogin) ...[
                  // ── Village Selector ──────────────────────────────────
                  _buildLabel('Select Your Village / गाव निवडा'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated,
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedVillageId,
                        isExpanded: true,
                        icon: const Icon(Icons.location_on_outlined, color: AppColors.secondary),
                        items: _kVillages.map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(v.nameMr,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansDevanagari',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(v.nameEn,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _selectedVillageId = value!),
                      ),
                    ),
                  ),
                  // Show the assigned ID so user can verify
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Village ID: $_selectedVillageId',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Role Selector ─────────────────────────────────────
                  _buildLabel('Select Role', context),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: c.isDark ? c.sunkenBg : AppColors.cardElevated,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: c.dialogBg,
                        value: _selectedRole,
                        isExpanded: true,
                        items: UserRole.values.map((role) {
                          return DropdownMenuItem<String>(
                            value: role.name,
                            child: Text(
                              '${role.displayNameEn} (${role.displayNameMr})',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _selectedRole = value!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                if (_isLogin) const SizedBox(height: 12),

                // ── Submit Button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.5),
                      elevation: 4,
                      shadowColor: AppColors.secondary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Login' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // ── Toggle Login / Signup ───────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : 'Already have an account? Login',
                      style: TextStyle(
                        color: c.isDark ? AppColors.accentSaffron : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Legal Notice ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                    boxShadow: c.isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: c.isDark ? AppColors.accentSaffron : AppColors.primary.withValues(alpha: 0.6),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.legalNotice,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            height: 1.4,
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
      ),
    );
  }

  // ─── Widget Helpers ───────────────────────────────────────────────────

  Widget _buildLabel(String text, [BuildContext? ctx]) {
    final c = (ctx ?? context).colors;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'NotoSansDevanagari',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData prefixIcon) {
    final c = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textTertiary),
      prefixIcon: Icon(prefixIcon, color: c.textTertiary),
      filled: true,
      fillColor: c.isDark ? c.sunkenBg : AppColors.cardElevated,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border.withValues(alpha: 0.5)),
      ),
    );
  }
}
