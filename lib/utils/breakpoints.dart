import 'package:flutter/widgets.dart';

/// 響應式佈局斷點：手機 / 平板 / 寬螢幕（桌面、Web）。
///
/// - 手機：< 600px
/// - 平板：600 ~ 900px
/// - 寬螢幕：≥ 900px
class AppBreakpoints {
  const AppBreakpoints._();

  static const double tablet = 600;
  static const double wide = 900;

  static bool isPhone(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < tablet;

  static bool isTablet(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    return w >= tablet && w < wide;
  }

  static bool isWide(BuildContext ctx) => MediaQuery.of(ctx).size.width >= wide;
}
