import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/start_core.dart';

class User {
  final String id;
  final String name;

  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json["uid"].toString(), name: json["namedId"]);
  }
}

class UserApi {
  static Future<List<User>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final response = await bddStorage.supabase
        .from("user_profil")
        .select("*")
        .eq("company_id", currentCompany.companyId)
        .ilike("namedId", "%$query%")
        .limit(100);

    final data = response as List<dynamic>;
    return data.map((e) => User.fromJson(e)).toList();
  }
}

class UserSearchDelegate extends SearchDelegate<User?> {
  final Debouncer _debouncer = Debouncer(milliseconds: 400);
  Future<List<User>>? _futureResults;

  @override
  String? get searchFieldLabel => "search for a user";

  @override
  void close(BuildContext context, User? result) {
    _debouncer.dispose();
    super.close(context, result);
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: Icon(Icons.clear), onPressed: () => query = ""),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _debouncer.run(() {
      _futureResults = UserApi.searchUsers(query);
    });

    return _buildResults();
  }

  @override
  Widget buildResults(BuildContext context) {
    _debouncer.run(() {
      _futureResults = UserApi.searchUsers(query);
    });

    return _buildResults();
  }

  Widget _buildResults() {
    if (_futureResults == null) {
      return Center(child: Text("Type to search for a user"));
    }

    return FutureBuilder<List<User>>(
      future: _futureResults,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Center(child: Text("No users found"));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              title: Text(user.name),
              onTap: () => close(context, user),
            );
          },
        );
      },
    );
  }
}
