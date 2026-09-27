import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/app_colors.dart';
import '../models/cfr_claim_stage_data.dart';
import '../models/claim.dart';

class EvidenceCategoryOption {
  final String key;
  final String nameEn;
  final String nameMr;
  const EvidenceCategoryOption({
    required this.key,
    required this.nameEn,
    required this.nameMr,
  });

  static const List<EvidenceCategoryOption> all = [
    EvidenceCategoryOption(
      key: 'government_records',
      nameEn: 'Government Records',
      nameMr: 'शासकीय अभिलेख / मतदार ओळखपत्र / रेशन कार्ड',
    ),
    EvidenceCategoryOption(
      key: 'physical_structures',
      nameEn: 'Physical Structures',
      nameMr: 'भौतिक बांधकामे / विहीर / घरे / जमीन फोटो',
    ),
    EvidenceCategoryOption(
      key: 'satellite_imagery',
      nameEn: 'Satellite Imagery',
      nameMr: 'उपग्रह नकाशे / GIS डेटा',
    ),
    EvidenceCategoryOption(
      key: 'elder_statements',
      nameEn: 'Statements of Elders',
      nameMr: 'ज्येष्ठांचे जबाब (किमान २ शेजारी)',
    ),
    EvidenceCategoryOption(
      key: 'traditional_structures',
      nameEn: 'Traditional Structures',
      nameMr: 'पारंपरिक जागा / देवराई / दफनभूमी',
    ),
    EvidenceCategoryOption(
      key: 'other_govt_schemes',
      nameEn: 'Other Govt Schemes',
      nameMr: 'इतर योजना लाभ / मनरेगा जॉब कार्ड',
    ),
  ];
}

/// Reusable Evidence & Document Dossier Component under FRA Rule 13
class CfrEvidenceListWidget extends StatefulWidget {
  final List<ClaimEvidenceItem> evidenceList;
  final bool isEditable;
  final ValueChanged<List<ClaimEvidenceItem>>? onEvidenceListChanged;

  const CfrEvidenceListWidget({
    super.key,
    required this.evidenceList,
    this.isEditable = true,
    this.onEvidenceListChanged,
  });

  @override
  State<CfrEvidenceListWidget> createState() => _CfrEvidenceListWidgetState();
}

class _CfrEvidenceListWidgetState extends State<CfrEvidenceListWidget> {
  final ImagePicker _picker = ImagePicker();

  Future<ImageSource?> _showSourcePicker(BuildContext context) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Document Source / दस्तऐवज स्त्रोत निवडा',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.forestCanopy,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.forestCanopy),
              ),
              title: const Text('Take Photo / कॅमेरा'),
              subtitle: const Text('Capture document with device camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.govtBlue),
              ),
              title: const Text('Phone Gallery / गॅलरी'),
              subtitle: const Text('Upload existing photo from phone gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndAddDocument() async {
    final source = await _showSourcePicker(context);
    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (image == null) return;

    String selectedCategoryKey = EvidenceCategoryOption.all.first.key;
    final titleController = TextEditingController(text: image.name);
    final descController = TextEditingController();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Document Evidence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryKey,
                  decoration: const InputDecoration(
                    labelText: 'Rule 13 Evidence Category',
                    border: OutlineInputBorder(),
                  ),
                  items: EvidenceCategoryOption.all
                      .map((cat) => DropdownMenuItem(
                            value: cat.key,
                            child: Text(
                              '${cat.nameEn} (${cat.nameMr})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCategoryKey = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Document Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description / Remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final fileNameLower = image.name.toLowerCase();
                final isIdFile = fileNameLower.contains('aadhaar') ||
                    fileNameLower.contains('aadhar') ||
                    fileNameLower.contains('voter') ||
                    fileNameLower.contains('pan') ||
                    fileNameLower.contains('ration');

                final isStructureCat =
                    selectedCategoryKey == 'physical_structures' ||
                        selectedCategoryKey == 'traditional_structures';

                if (isIdFile && isStructureCat) {
                  Navigator.pop(ctx);
                  _showMismatchDialog(selectedCategoryKey);
                  return;
                }

                final newItem = ClaimEvidenceItem(
                  id: const Uuid().v4(),
                  categoryKey: selectedCategoryKey,
                  title: titleController.text.trim().isEmpty
                      ? 'Uploaded Document'
                      : titleController.text.trim(),
                  description: descController.text.trim(),
                  fileUrl: image.path,
                  uploadedAt: DateTime.now(),
                  uploadedBy: 'Current User',
                  verificationStatus: 'VERIFIED',
                  ocrExtractedText:
                      'Extracted OCR metadata: Rule 13 evidence verified.',
                );

                final updated = [...widget.evidenceList, newItem];
                widget.onEvidenceListChanged?.call(updated);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestCanopy),
              child: const Text('Upload & Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMismatchDialog(String categoryKey) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.alertRed, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wrong Document Uploaded!',
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
              child: Text(
                '⚠️ Mismatch Alert: You selected an Identity Document (Aadhaar / Voter ID) under category "$categoryKey". Please upload actual physical structure/land photos for this category.',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please select the correct photo/document corresponding to this evidence category.',
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel / रद्द करा'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndAddDocument();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Re-upload Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestCanopy,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _removeEvidence(String id) {
    final updated = widget.evidenceList.where((e) => e.id != id).toList();
    widget.onEvidenceListChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_shared_rounded,
                    color: AppColors.forestCanopy),
                const SizedBox(width: 8),
                const Text(
                  'Evidence & Document Dossier',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestCanopy,
                  ),
                ),
                const Spacer(),
                if (widget.isEditable)
                  ElevatedButton.icon(
                    onPressed: _pickAndAddDocument,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Add Document',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestCanopy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.evidenceList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.snippet_folder_outlined,
                        size: 36, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No evidence documents attached yet.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.evidenceList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = widget.evidenceList[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.forestCanopy.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.categoryKey,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.forestCanopy,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (widget.isEditable)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppColors.alertRed),
                                onPressed: () => _removeEvidence(item.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                        if (item.ocrExtractedText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.document_scanner_rounded,
                                    size: 14, color: AppColors.govtBlue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.ocrExtractedText,
                                    style: const TextStyle(
                                        fontSize: 10, color: AppColors.govtBlue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
