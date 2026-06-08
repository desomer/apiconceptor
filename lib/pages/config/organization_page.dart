import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';

class OrganizationPage extends GenericPageStateful {
  const OrganizationPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _OrganizationPageState();
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

class _OrganizationPageState extends GenericPageState<OrganizationPage> {
  late Future<Map<String, dynamic>?> _subscriptionFuture;

  @override
  void initState() {
    super.initState();
    _subscriptionFuture = _loadSubscription();
  }

  Future<Map<String, dynamic>?> _loadSubscription() async {
    return bddStorage.getCurrentUserSubscription();
  }

  String _safeValue(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final v = value.toString().trim();
    return v.isEmpty ? fallback : v;
  }

  String _dateValue(dynamic raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return dt.toLocal().toString().split('.').first;
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
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

  Widget _buildSubscriptionCard(Map<String, dynamic>? subscription) {
    final user = currentCompany.user;
    final userMetaPlan = _safeValue(
      user?.userMetadata?['plan'],
      fallback: 'free',
    );

    final plan = _safeValue(subscription?['plan'], fallback: userMetaPlan);
    final status = _safeValue(subscription?['status'], fallback: 'unknown');
    final email = _safeValue(
      subscription?['email'],
      fallback: user?.email ?? '-',
    );
    final companyId = _safeValue(
      subscription?['company_id'],
      fallback: currentCompany.companyId,
    );
    final companyName = _safeValue(subscription?['company_name']);
    final stripeCustomerId = _safeValue(subscription?['stripe_customer_id']);
    final stripeSubscriptionId = _safeValue(
      subscription?['stripe_subscription_id'],
    );
    final createdAt = _dateValue(subscription?['created_at']);
    final updatedAt = _dateValue(subscription?['updated_at']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Subscription',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _kv('Plan', plan),
            _kv('Status', status),
            _kv('Email', email),
            _kv('Company ID', companyId),
            _kv('Company name', companyName),
            _kv('Stripe customer', stripeCustomerId),
            _kv('Stripe subscription', stripeSubscriptionId),
            _kv('Created at', createdAt),
            _kv('Updated at', updatedAt),
            if (subscription == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Aucune ligne customer_subscriptions trouvee pour cet utilisateur. '
                'Les infos ci-dessus utilisent les metadonnees de session.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _subscriptionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organization',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          'Erreur lors du chargement de la subscription: ${snapshot.error}',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _subscriptionFuture = _loadSubscription();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reessayer'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubscriptionCard(snapshot.data),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _subscriptionFuture = _loadSubscription();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Rafraichir'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
