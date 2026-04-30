import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import conditionnel : version web OU version fallback
import 'web_back.dart' if (dart.library.html) 'web_back_web.dart';

class UniversalBackButton extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const UniversalBackButton({
    super.key,
    this.icon = Icons.arrow_back,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      icon: Icon(icon, color: color),
      onPressed: () async {
        final router = GoRouter.of(context);

        // 1. Retour GoRouter si possible
        if (router.canPop()) {
          router.pop();
          return;
        }

        // 2. Retour Flutter classique (Windows, mobile…)
        final didPop = await Navigator.of(context).maybePop();
        if (didPop) return;

        // 3. Retour navigateur (Web uniquement)
        webHistoryBack();
      },
    );
  }
}
