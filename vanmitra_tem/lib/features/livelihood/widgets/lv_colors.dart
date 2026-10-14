import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

extension LvColorsX on BuildContext {
  /// Saffron for TEXT and small icons that must stay readable on the surface.
  /// The brand saffron (#FF7A00) is only 2.6:1 on a white card, below the 4.5:1 WCAG AA bar,
  /// so on light surfaces this is a darker orange (about 5.8:1). On dark surfaces the brand
  /// saffron is fine (5.7:1). Big saffron fills (buttons, the analysis card's rule) keep the brand colour.
  Color get lvEmphasis =>
      colors.isDark ? AppColors.saffron : const Color(0xFFA64B00);
}
