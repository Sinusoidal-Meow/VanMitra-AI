import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/claim.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claims_provider.dart';
import '../../widgets/portal_frame_scaffold.dart';

/// "Create CFR Claim" Flow
class CfrClaimCreateScreen extends ConsumerStatefulWidget {
  const CfrClaimCreateScreen({super.key});

  @override
  ConsumerState<CfrClaimCreateScreen> createState() =>
      _CfrClaimCreateScreenState();
}

class _CfrClaimCreateScreenState extends ConsumerState<CfrClaimCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _stateController;
  late TextEditingController _districtController;
  late TextEditingController _tehsilController;
  late TextEditingController _blockController;
  late TextEditingController _gpController;
  late TextEditingController _villageController;
  late TextEditingController _communityNameController;
  late TextEditingController _communityNameEnController;
  late TextEditingController _surveyNoController;
  late TextEditingController _areaController;
  late TextEditingController _descController;
  late TextEditingController _phoneController;

  ClaimType _selectedClaimType = ClaimType.formB; // Form B = CFRR
  final ClaimNature _selectedNature = ClaimNature.traditionalResource;

  @override
  void initState() {
    super.initState();
    _stateController = TextEditingController(text: 'महाराष्ट्र (Maharashtra)');
    _districtController = TextEditingController(text: 'पालघर (Palghar)');
    _tehsilController = TextEditingController(text: 'जव्हार (Jawhar)');
    _blockController = TextEditingController(text: 'जव्हार (Jawhar)');
    _gpController = TextEditingController(text: 'ओझर (Ozhar)');
    _villageController = TextEditingController(text: 'ओझर (Ozhar)');
    _communityNameController =
        TextEditingController(text: 'ओझर ग्रामसभा - वारली समुदाय');
    _communityNameEnController =
        TextEditingController(text: 'Ozhar Gram Sabha - Warli Community');
    _surveyNoController = TextEditingController(text: 'CFR-SURVEY-463/A');
    _areaController = TextEditingController(text: '125000'); // 12.5 Hectares
    _descController = TextEditingController(
        text: 'सामुदायिक वन संसाधन हक्क दावा - बांबू, गौण वनोपज, चराई आणि पारंपरिक जलस्रोत अधिकार.');
    _phoneController = TextEditingController(text: '+91 9823012345');
  }

  @override
  void dispose() {
    _stateController.dispose();
    _districtController.dispose();
    _tehsilController.dispose();
    _blockController.dispose();
    _gpController.dispose();
    _villageController.dispose();
    _communityNameController.dispose();
    _communityNameEnController.dispose();
    _surveyNoController.dispose();
    _areaController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showValidationPopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.alertRed, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Required Fields Empty! / माहिती अपूर्ण!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.alertRed,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.alertRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.alertRed.withOpacity(0.3)),
              ),
              child: const Text(
                '⚠️ Please fill in all required text boxes before proceeding to save or submit your CFR claim.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'कृपया पुढील टप्प्यावर जाण्यापूर्वी लाल रंगाने दर्शवलेली सर्व आवश्यक माहिती भरा.',
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
                fontFamily: 'NotoSansDevanagari',
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestCanopy,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK / समजले'),
          ),
        ],
      ),
    );
  }

  void _saveClaim({required bool submitImmediately}) async {
    if (!_formKey.currentState!.validate()) {
      _showValidationPopup();
      return;
    }

    final auth = ref.read(authProvider);
    final user = auth.currentUser;
    if (user == null) return;

    final timestamp = DateTime.now();
    final year = timestamp.year;
    final randomSuffix =
        (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
    final claimId = 'CFR-MH-PALGHAR-$year-$randomSuffix';

    final claim = Claim(
      id: claimId,
      claimantUserId: user.id,
      villageId: user.villageId,
      villageName: _villageController.text,
      gramPanchayat: _gpController.text,
      tehsil: _tehsilController.text,
      district: _districtController.text,
      state: _stateController.text,
      type: _selectedClaimType,
      status: submitImmediately
          ? ClaimStatus.submittedToFrc
          : ClaimStatus.draft,
      nature: _selectedNature,
      assignedAuthority:
          submitImmediately ? UserRole.frc : UserRole.villager,
      claimantName: _communityNameController.text,
      claimantNameEn: _communityNameEnController.text,
      surveyNumber: _surveyNoController.text,
      areaSqMeters: double.tryParse(_areaController.text) ?? 10000,
      contactPhone: _phoneController.text,
      claimDescription: _descController.text,
      createdAt: timestamp,
      submittedAt: submitImmediately ? timestamp : null,
    );

    await ref.read(claimsProvider.notifier).addClaim(claim);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submitImmediately
              ? 'CFR Claim $claimId successfully submitted to FRC!'
              : 'CFR Claim $claimId saved as Draft.',
        ),
        backgroundColor: AppColors.forestCanopy,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final primaryAccent = c.isDark ? AppColors.forestLight : AppColors.forestCanopy;

    return PortalFrameScaffold(
      breadcrumbs: const ['Create CFR Claim | नवीन दावा'],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: c.isDark ? AppColors.forestDarkSurface : AppColors.forestCanopy.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: c.isDark ? AppColors.forestLight.withOpacity(0.3) : AppColors.forestCanopy),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: primaryAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Community Forest Resource Right (CFRR) Claim under Section 3(1)(i) of Forest Rights Act (FRA), 2006.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Claim Type & Nature
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ClaimType>(
                      initialValue: _selectedClaimType,
                      decoration: const InputDecoration(
                        labelText: 'Claim Form Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ClaimType.formB,
                          child: Text('Form B — Community Resource (CFR)'),
                        ),
                        DropdownMenuItem(
                          value: ClaimType.formA,
                          child: Text('Form A — Individual Rights (IFR)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedClaimType = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location details
              Text(
                'Jurisdiction & Location Details',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                          labelText: 'State', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _districtController,
                      decoration: const InputDecoration(
                          labelText: 'District', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tehsilController,
                      decoration: const InputDecoration(
                          labelText: 'Tehsil / Sub-Division',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _gpController,
                      decoration: const InputDecoration(
                          labelText: 'Gram Panchayat',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Claimant / Community
              Text(
                'Community / Claimant Details',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _communityNameController,
                decoration: const InputDecoration(
                  labelText: 'Community Name (मराठी)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _communityNameEnController,
                decoration: const InputDecoration(
                  labelText: 'Community Name (English)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Land & Area
              Text(
                'Land & Resource Boundaries',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _surveyNoController,
                      decoration: const InputDecoration(
                        labelText: 'Compartment / Survey No.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Area (Sq. Meters)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Claim Description & Customary Rights',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _saveClaim(submitImmediately: false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: primaryAccent),
                        foregroundColor: primaryAccent,
                      ),
                      child: const Text('Save Draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _saveClaim(submitImmediately: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestCanopy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Submit to FRC'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
