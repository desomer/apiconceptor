import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore: must_be_immutable
class LoginCard extends StatefulWidget {
  LoginCard({super.key, required this.email, required this.pwd});

  String email;
  String pwd;
  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  static final Uri _subscriptionUri = Uri.parse(
    'https://apiarchitec.com/en/subscription',
  );

  final _mailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _secureText = true;
  bool _canContinue = false;

  Future<void> _openSubscriptionPage() async {
    final opened = await launchUrl(
      _subscriptionUri,
      mode: LaunchMode.platformDefault,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open subscription page.')),
      );
    }
  }

  @override
  void initState() {
    _mailController.text = widget.email;
    _passwordController.text = widget.pwd;
    _canContinue = widget.pwd.trim().isNotEmpty;

    _mailController.addListener(() {
      widget.email = _mailController.text;
    });
    _passwordController.addListener(() {
      widget.pwd = _passwordController.text;
      final nextCanContinue = _passwordController.text.trim().isNotEmpty;
      if (mounted && nextCanContinue != _canContinue) {
        _canContinue = nextCanContinue;
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant LoginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email != widget.email &&
        _mailController.text != widget.email) {
      _mailController.text = widget.email;
    }
    if (oldWidget.pwd != widget.pwd && _passwordController.text != widget.pwd) {
      _passwordController.text = widget.pwd;
      _canContinue = widget.pwd.trim().isNotEmpty;
    }
  }

  Widget getMailWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _mailController,
        style: TextStyle(color: Colors.black),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 13,
          ),
          hintText: "mail",
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color.fromARGB(235, 255, 123, 0),
              width: 3,
            ),
          ),
        ),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget getPasswordWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        style: TextStyle(color: Colors.black),
        controller: _passwordController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 13,
          ),
          hintText: "password",
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color.fromARGB(235, 255, 123, 0),
              width: 3,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _secureText == false ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _secureText = !_secureText;
              });
            },
          ),
        ),
        textInputAction: TextInputAction.next,
        obscuringCharacter: '●',
        obscureText: _secureText,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    var accessToken = prefs.getString("access_token");
    var refreshToken = prefs.getString("refresh_token");

    bool autoLogingByToken = accessToken != null && refreshToken != null;
    if (autoLoging && autoLogingWithToken && autoLogingByToken) {
      autoLoging = false;
      Future.delayed(Duration(seconds: 1), () {
        // ignore: use_build_context_synchronously
        UserAuthentication().logIn(context, widget.email, widget.pwd, true);
      });
    }

    if (autoLoging && widget.email.isNotEmpty && widget.pwd.isNotEmpty) {
      autoLoging = false;
      Future.delayed(Duration(seconds: 1), () {
        final email = _mailController.text;
        final password = _passwordController.text;

        // ignore: use_build_context_synchronously
        UserAuthentication().logIn(context, email, password, false);
      });
    }

    autoLoging = false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            height: 360,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  getAvatar(),
                  const SizedBox(height: 20),
                  getMailWidget(),
                  const SizedBox(height: 10),
                  getPasswordWidget(),
                  const SizedBox(height: 10),
                  Row(
                    spacing: 20,
                    children: [
                      Expanded(
                        child: getWidgetDoLogin(context, enabled: _canContinue),
                      ),
                      Expanded(child: getWidgetCreateAccount()),
                    ],
                  ),
                  const SizedBox(height: 30),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        final email = _mailController.text;
                        UserAuthentication().sendPasswordReset(context, email);
                      },
                      child: const Text(
                        "Forgot your password?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(235, 255, 123, 0),
                        ),
                      ),
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

  MouseRegion getWidgetCreateAccount() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _openSubscriptionPage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromARGB(235, 255, 123, 0),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Text(
              'Create an account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  MouseRegion getWidgetDoLogin(BuildContext context, {required bool enabled}) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: enabled
            ? () {
                // logIn(_scaffoldKey.currentContext);
                final email = _mailController.text;
                final password = _passwordController.text;

                UserAuthentication().logIn(context, email, password, false);
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          width: double.infinity,
          decoration: BoxDecoration(
            color: enabled
                ? const Color.fromARGB(235, 255, 123, 0)
                : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              "Continue",
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Row getAvatar() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 35,
          backgroundImage: NetworkImage(
            'https://media.istockphoto.com/id/503641910/fr/photo/circinus-sur-le-tirage.webp?a=1&s=612x612&w=0&k=20&c=oEetXjIzH3Vk2xoWh7kX_PvyeGEcjOHPLT7CPxjHjJU=',
            //'https://images.unsplash.com/photo-1615358630075-ba2bbe783521?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=687&q=80',
          ),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.email,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}
