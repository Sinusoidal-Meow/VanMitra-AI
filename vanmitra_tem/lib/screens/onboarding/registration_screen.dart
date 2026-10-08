import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/localization_service.dart';
import '../../services/api_auth_service.dart';

class _VillageOption {
  final String id;
  final String nameEn;
  final String nameMr;
  const _VillageOption({required this.id, required this.nameEn, required this.nameMr});
}

/// VanMitra-AI — Phone / PIN Login and Registration Screen
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  bool _isLogin = true;
  bool _isLoadingVillages = false;

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  final _nameController = TextEditingController();

  String _selectedRole = 'villager';
  String? _selectedVillageId;
  bool _obscurePin = true;
  bool _obscurePinConfirm = true;

  List<_VillageOption> _villages = [];

  @override
  void initState() {
    super.initState();
    _fetchVillages();
  }

  Future<void> _fetchVillages() async {
    setState(() => _isLoadingVillages = true);
    try {
      final apiAuth = ApiAuthService();
      final data = await apiAuth.getVillages();
      setState(() {
        _villages = data.map((v) => _VillageOption(
          id: v['id'] ?? '',
          nameEn: v['name_en'] ?? '',
          nameMr: v['name_mr'] ?? '',
        )).toList();
        if (_villages.isNotEmpty) {
          _selectedVillageId = _villages.first.id;
        }
      });
    } catch (e) {
      // Fallback
      setState(() {
        _villages = const [
          _VillageOption(id: 'OZH-01', nameEn: 'Ozhar (Jawhar, Palghar)', nameMr: 'ओझर (जव्हार, पालघर)'),
        ];
        _selectedVillageId = 'OZH-01';
      });
    } finally {
      setState(() => _isLoadingVillages = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isLogin && _pinController.text != _pinConfirmController.text) {
      _showError('PINs do not match');
      return;
    }

    if (!_isLogin && _selectedVillageId == null) {
      _showError('Please select a village');
      return;
    }

    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    String? role;
    if (_isLogin) {
      role = await ref.read(authProvider.notifier).login(phone, pin);
    } else {
      final name = _nameController.text.trim();
      role = await ref.read(authProvider.notifier).register(
        phone, pin, name, _selectedRole, _selectedVillageId!,
      );
    }

    if (!mounted) return;

    if (role == null) {
      // Say why instead of doing nothing (wrong PIN, server not reachable, ...).
      _showError(ref.read(authProvider).errorMessage ?? 'Could not sign in. Please try again.');
      return;
    }

    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, AppRouter.adminHome);
    } else if (role == 'villager') {
      Navigator.pushReplacementNamed(context, AppRouter.villagerHome);
    } else if (role != null) {
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
    final isLoading = authState.isLoading || _isLoadingVillages;

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

                _buildLabel('Phone Number (10 digits)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: _inputDecoration('Enter your phone number', Icons.phone_outlined),
                  validator: (v) => v!.length != 10 ? 'Enter a valid 10-digit phone number' : null,
                ),
                const SizedBox(height: 10),

                _buildLabel('PIN (6 digits)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pinController,
                  enabled: !isLoading,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: _inputDecoration('Enter your 6-digit PIN', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  validator: (v) => v!.length != 6 ? 'PIN must be exactly 6 digits' : null,
                ),
                const SizedBox(height: 10),

                if (!_isLogin) ...[
                  _buildLabel('Confirm PIN (6 digits)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pinConfirmController,
                    enabled: !isLoading,
                    obscureText: _obscurePinConfirm,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _inputDecoration('Confirm your 6-digit PIN', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePinConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () => setState(() => _obscurePinConfirm = !_obscurePinConfirm),
                      ),
                    ),
                    validator: (v) => v!.length != 6 ? 'PIN must be exactly 6 digits' : null,
                  ),
                  const SizedBox(height: 10),

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
                        items: _villages.map((v) => DropdownMenuItem(
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
                  if (_selectedVillageId != null)
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
                        items: [
                          DropdownMenuItem<String>(
                            value: UserRole.villager.name,
                            child: Text(
                              'Villager',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: UserRole.frc.name,
                            child: Text(
                              'Village / GramSabha',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: UserRole.admin.name,
                            child: Text(
                              'System Administrator',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _selectedRole = value!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                if (_isLogin) const SizedBox(height: 12),

                // ── Demo Logins ─────────────────────────────────────────
                if (_isLogin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                         Text('Quick Demo Logins:', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                         const SizedBox(height: 8),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                           children: [
                             _demoLoginBtn('Villager', '9000000001'),
                             _demoLoginBtn('Gram Sabha', '9000000003'),
                             _demoLoginBtn('SDO', '9000000005'),
                           ],
                         ),
                      ],
                    ),
                  ),

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

  Widget _demoLoginBtn(String label, String phone) {
    final c = context.colors;
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600)),
      onPressed: () {
        _phoneController.text = phone;
        _pinController.text = '123456';
      },
      backgroundColor: AppColors.cardElevated,
      side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData prefixIcon) {
    final c = context.colors;
    return InputDecoration(
      hintText: hint,
      counterText: "",
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
