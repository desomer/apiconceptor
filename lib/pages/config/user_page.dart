import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:supabase/supabase.dart';

class UserPage extends GenericPageStateful {
  const UserPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return UserPageState();
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

class UserPageState extends GenericPageState<UserPage> {
  var name = TextEditingController();
  var password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.all(10),
      child: Column(
        children: [
          Text('User management'),
          SizedBox(height: 20),
          Text('Create a new user'),
          SizedBox(height: 10),
          TextField(
            controller: name,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Email',
            ),
          ),
          SizedBox(height: 10),
          TextField(
            obscureText: false,
            controller: password,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
            ),
          ),

          ElevatedButton(
            onPressed: () {
              signUpNewUser();
            },
            child: Text('Create user'),
          ),
        ],
      ),
    );
  }

  Future<void> signUpNewUser() async {
    try {
      final AuthResponse res = await bddStorage.supabase.auth.signUp(
        email: name.text,
        password: password.text,
      );

      print('res $res');

      await bddStorage.supabase.from('user_profil').upsert([
        {
          'uid': res.user!.id,
          'namedId': name.text,
          'data': {
            'rule': ['invit'],
          },
          'company_id': currentCompany.companyId,
        },
      ]);

      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("User created successfully")));
    } on Exception catch (e) {
      print('Error signing up: $e');
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Error signing up: $e")));
    }
  }
}
