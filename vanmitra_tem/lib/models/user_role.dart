import 'package:flutter/material.dart';

/// Role-Based Access Control (RBAC) User Roles in VanMitra-AI
/// Supporting complete Community Forest Resource (CFR) claim workflow under FRA
enum UserRole {
  /// Role 1: Gram Sabha / Village User / Claimant
  villager,

  /// Role 2: Forest Rights Committee (FRC)
  frc,

  /// Role 3: Forest Department Field Officer
  forestOfficer,

  /// Role 4: Revenue Department Field Officer
  revenueOfficer,

  /// Role 5: Sub-Divisional Level Committee (SDLC)
  sdlc,

  /// Role 6: District Level Committee (DLC)
  dlc,

  /// Role 7: Divisional Forest Officer / Deputy Conservator of Forests (DFO)
  dfo,

  /// Role 8: District Tribal Welfare Officer (DTWO)
  dtwo,

  /// Role 9: District Collector / Deputy Commissioner
  collector,

  /// Role 10: Record Incorporation Officer
  recordOfficer,

  /// Role 11: State Level Monitoring Committee (SLMC)
  slmc,

  /// Role 12: System Administrator
  admin,
}

/// Extension for display names, descriptions, and metadata across all 12 roles
extension UserRoleExtension on UserRole {
  String get displayNameEn {
    switch (this) {
      case UserRole.villager:
        return 'Village / Gram Sabha User';
      case UserRole.frc:
        return 'Forest Rights Committee (FRC)';
      case UserRole.forestOfficer:
        return 'Forest Department Field Officer';
      case UserRole.revenueOfficer:
        return 'Revenue Department Field Officer';
      case UserRole.sdlc:
        return 'Sub-Divisional Level Committee (SDLC)';
      case UserRole.dlc:
        return 'District Level Committee (DLC)';
      case UserRole.dfo:
        return 'Divisional Forest Officer (DFO/DCF)';
      case UserRole.dtwo:
        return 'District Tribal Welfare Officer';
      case UserRole.collector:
        return 'District Collector / Deputy Commissioner';
      case UserRole.recordOfficer:
        return 'Record Incorporation Officer';
      case UserRole.slmc:
        return 'State Level Monitoring Committee';
      case UserRole.admin:
        return 'System Administrator';
    }
  }

  String get displayNameMr {
    switch (this) {
      case UserRole.villager:
        return 'ग्रामस्थ / ग्रामसभा वापरकर्ता';
      case UserRole.frc:
        return 'वन हक्क समिती (FRC)';
      case UserRole.forestOfficer:
        return 'वन विभाग क्षेत्र अधिकारी';
      case UserRole.revenueOfficer:
        return 'महसूल विभाग क्षेत्र अधिकारी';
      case UserRole.sdlc:
        return 'उपविभागीय स्तर समिती (SDLC)';
      case UserRole.dlc:
        return 'जिल्हा स्तर समिती (DLC)';
      case UserRole.dfo:
        return 'उपवनसंरक्षक अधिकारी (DFO)';
      case UserRole.dtwo:
        return 'जिल्हा आदिवासी विकास अधिकारी';
      case UserRole.collector:
        return 'जिल्हाधिकारी / उपआयुक्त';
      case UserRole.recordOfficer:
        return 'अभिलेख नोंदणी अधिकारी';
      case UserRole.slmc:
        return 'राज्यस्तरीय देखरेख समिती';
      case UserRole.admin:
        return 'प्रणाली प्रशासक';
    }
  }

  String get descriptionEn {
    switch (this) {
      case UserRole.villager:
        return 'File CFR claims, attend Gram Sabha meetings, view village records';
      case UserRole.frc:
        return 'Inspect claims, upload evidence, delineate customary boundaries, submit findings';
      case UserRole.forestOfficer:
        return 'Conduct joint field verification and submit forest proceedings';
      case UserRole.revenueOfficer:
        return 'Conduct joint field verification and submit revenue proceedings';
      case UserRole.sdlc:
        return 'Review Gram Sabha submissions, consolidate maps, prepare draft records';
      case UserRole.dlc:
        return 'Review SDLC submissions, pass final orders (Approve/Remand/Modify/Reject)';
      case UserRole.dfo:
        return 'Sign Annexure IV title documents as Forest Department authority';
      case UserRole.dtwo:
        return 'Sign Annexure IV title documents as Tribal Welfare authority';
      case UserRole.collector:
        return 'Sign Annexure IV title documents as District Collector authority';
      case UserRole.recordOfficer:
        return 'Incorporate final titles into revenue and forest land records';
      case UserRole.slmc:
        return 'Oversight, state-wide analytics, workflow monitoring & bottleneck analysis';
      case UserRole.admin:
        return 'User management, role assignments, system settings, and audit logs';
    }
  }

  String get demoEmail {
    switch (this) {
      case UserRole.villager:
        return 'village.demo@vanmitra.gov.in';
      case UserRole.frc:
        return 'frc.demo@vanmitra.gov.in';
      case UserRole.forestOfficer:
        return 'forest.demo@vanmitra.gov.in';
      case UserRole.revenueOfficer:
        return 'revenue.demo@vanmitra.gov.in';
      case UserRole.sdlc:
        return 'sdlc.demo@vanmitra.gov.in';
      case UserRole.dlc:
        return 'dlc.demo@vanmitra.gov.in';
      case UserRole.dfo:
        return 'dfo.demo@vanmitra.gov.in';
      case UserRole.dtwo:
        return 'dtwo.demo@vanmitra.gov.in';
      case UserRole.collector:
        return 'collector.demo@vanmitra.gov.in';
      case UserRole.recordOfficer:
        return 'records.demo@vanmitra.gov.in';
      case UserRole.slmc:
        return 'slmc.demo@vanmitra.gov.in';
      case UserRole.admin:
        return 'admin.demo@vanmitra.gov.in';
    }
  }

  Color get roleColor {
    switch (this) {
      case UserRole.villager:
        return const Color(0xFF2E7D32); // Leaf green
      case UserRole.frc:
        return const Color(0xFFE65100); // Deep orange
      case UserRole.forestOfficer:
        return const Color(0xFF1B5E20); // Forest green
      case UserRole.revenueOfficer:
        return const Color(0xFF0D47A1); // Deep blue
      case UserRole.sdlc:
        return const Color(0xFF00695C); // Teal
      case UserRole.dlc:
        return const Color(0xFF4A148C); // Purple
      case UserRole.dfo:
        return const Color(0xFF2E7D32);
      case UserRole.dtwo:
        return const Color(0xFFC2185B); // Pink/Rose
      case UserRole.collector:
        return const Color(0xFFB71C1C); // Crimson
      case UserRole.recordOfficer:
        return const Color(0xFF37474F); // Blue grey
      case UserRole.slmc:
        return const Color(0xFF1565C0); // Royal blue
      case UserRole.admin:
        return const Color(0xFFD84315); // Burnt orange
    }
  }

  /// Helper to safely parse string into UserRole enum (supports legacy strings like 'admin', 'villager')
  static UserRole parse(String? roleStr) {
    if (roleStr == null || roleStr.isEmpty) return UserRole.villager;
    try {
      return UserRole.values.firstWhere(
        (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
        orElse: () => UserRole.villager,
      );
    } catch (_) {
      return UserRole.villager;
    }
  }
}
