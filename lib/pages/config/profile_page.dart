import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';

class ProfilePage extends GenericPageStateless {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = currentCompany.user;
    final profil = currentCompany.userProfil;
    final companyId = profil?['company_id']?.toString() ?? '-';
    final rules = (profil?['data']?['rule'] as List?)?.join(', ') ?? '-';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Profil',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _row('Email', user?.email ?? '-'),
                  _row('Identifiant', currentCompany.shortUserId),
                  _row('UID', user?.id ?? '-'),
                  _row('Company', companyId),
                  _row('Roles', rules),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _logOut(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Deconnexion'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<void> _logOut(BuildContext context) async {
    try {
      await bddStorage.getAuthClient().auth.signOut();
    } catch (_) {
      // Keep local logout flow even if remote sign-out fails.
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');


    autoLoging = false;
    showLoginDialog = true;
    currentCompany.user = null;
    currentCompany.userProfil = null;

    if (!context.mounted) return;
    await PageLayoutState.showLogin(context);
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    return NavigationInfo();
  }
}
