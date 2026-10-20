import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/assets/app_assets.dart';

class RecoveryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RecoveryAppBar({this.onBack, super.key});
  final VoidCallback? onBack;

  @override
  Size get preferredSize => Size.fromHeight(78.h);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: preferredSize.height,
    leadingWidth: 64.w,
    leading: Center(
      child: IconButton(
        tooltip: AppTexts.back,
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        icon: Image.asset(
          AppAssets.back,
          width: 30.r,
          height: 30.r,
          excludeFromSemantics: true,
        ),
      ),
    ),
  );
}
