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
  var mail = TextEditingController();
  var password = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.all(10),
      child: Row(
        children: [
          SizedBox(width: 400, child: getUserWidget()),
          VerticalDivider(),
          Expanded(child: getListUserWidget()),
        ],
      ),
    );
  }

  Widget getListUserWidget() {
    return Column(
      children: [
        Text('List of users'),
        SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<List<Map>>(
            future: loadUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading users: ${snapshot.error}'),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No users found.'));
              } else {
                final users = snapshot.data!;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final rulesRaw = user['data']?['rule'];
                    final rules = rulesRaw is List
                        ? rulesRaw.map((e) => e.toString()).toList()
                        : <String>[];
                    final createdAt = DateTime.tryParse(
                      (user['created_at'] ?? '').toString(),
                    );
                    var createdAtLabel = createdAt == null
                        ? 'unknown'
                        : createdAt.toLocal().toString().split('.').first;

                    if (user['uid'] == user['namedId']) {
                      createdAtLabel += ' (invited but not signed up)';
                    }

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        isThreeLine: true,
                        title: SelectableText(user['namedId'] ?? 'Unknown'),
                        subtitle: Text(
                          '${rules.isEmpty ? 'Rules: none' : 'Rules: ${rules.join(', ')}'}\n'
                          'Invited at: $createdAtLabel',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete user',
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  deleteUser(user);
                                },
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Column getUserWidget() {
    return Column(
      children: [
        Text('User management'),
        SizedBox(height: 20),
        Text('Create a new user'),
        SizedBox(height: 10),
        TextField(
          controller: mail,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Email',
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  inviteUserByEmail();
                },
          child: Text('Invite user by email'),
        ),

        Divider(),
        SizedBox(height: 50),
        TextField(
          obscureText: false,
          controller: password,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Password',
          ),
        ),

        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  signUpNewUser();
                },
          child: Text('Create user with email and password'),
        ),
      ],
    );
  }

  Future<void> signUpNewUser() async {
    if (_isSubmitting) return;
    if (mail.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Email and password are required.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final AuthResponse res = await bddStorage.supabase.auth.signUp(
        email: mail.text.trim(),
        password: password.text,
      );

      print('res $res');

      await initProfil(res);

      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("User created successfully")));
    } on Exception catch (e) {
      print('Error signing up: $e');
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Error signing up: $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> initProfil(AuthResponse? res) async {
    var mailNormalized = mail.text.trim();
    await bddStorage.supabase.from('user_profil').upsert([
      {
        'uid': res?.user?.id ?? mailNormalized,
        'namedId': mailNormalized,
        'data': {
          'rule': ['invit'],
        },
        'company_id': currentCompany.companyId,
      },
    ]);
  }

  Future<void> inviteUserByEmail() async {
    if (_isSubmitting) return;

    final email = mail.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Email is required to send an invitation.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await bddStorage.supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );

      await initProfil(null);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invitation sent to $email.')));
    } on Exception catch (e) {
      print('Error sending invite: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error sending invitation: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<List<Map<dynamic, dynamic>>>? loadUsers() async {
    try {
      final response = await bddStorage.supabase
          .from('user_profil')
          .select()
          .eq('company_id', currentCompany.companyId);

      return List<Map<dynamic, dynamic>>.from(response as List);
    } catch (e) {
      print('Exception loading users: $e');
      return [];
    }
  }

  Future<void> deleteUser(Map<dynamic, dynamic> user) async {
    final namedId = (user['namedId'] ?? 'Unknown').toString();
    final uid = user['uid']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete user'),
          content: Text('Do you really want to delete $namedId?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? authDeleteWarning;
      if (uid != null && uid.isNotEmpty && _isUuid(uid)) {
        try {
          final result = await bddStorage.callDeleteUserApi(userId: uid);
          final success = result['success'] == true;
          if (!success) {
            authDeleteWarning =
                (result['message'] ?? result['error'] ?? 'Unknown error')
                    .toString();
            print(
              'Warning deleting auth user via cloud function: $authDeleteWarning',
            );
          }
        } on Exception catch (e) {
          authDeleteWarning = e.toString();
          print('Warning deleting auth user via cloud function: $e');
        }
      }

      var query = bddStorage.supabase
          .from('user_profil')
          .delete()
          .eq('company_id', currentCompany.companyId);

      if (uid != null && uid.isNotEmpty) {
        query = query.eq('uid', uid);
      } else {
        query = query.eq('namedId', namedId);
      }

      await query;

      if (!mounted) return;
      final message = authDeleteWarning == null
          ? 'User deleted: $namedId'
          : 'Profile deleted: $namedId (auth user not deleted: missing admin rights)';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      setState(() {});
    } on Exception catch (e) {
      print('Error deleting user: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error deleting user: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _isUuid(String value) {
    if (value.length != 36) return false;
    return RegExp(
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}',
    ).hasMatch(value);
  }
}
