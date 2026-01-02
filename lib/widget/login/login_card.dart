import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jsonschema/pages/router_layout.dart';

class LoginCard extends StatefulWidget {
  const LoginCard({super.key, required this.email, required this.pwd});

  final String email;
  final String pwd;
  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final _mailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _secureText = true;

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
    _mailController.text = widget.email;
    _passwordController.text = widget.pwd;

    if (autoLoging && widget.email.isNotEmpty && widget.pwd.isNotEmpty) {
      Future.delayed(Duration(seconds: 1), () {
        final email = _mailController.text;
        final password = _passwordController.text;

        // ignore: use_build_context_synchronously
        UserAuthentication().logIn(context, email, password);
      });
    }

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
                  Row(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  getMailWidget(),
                  const SizedBox(height: 10),
                  getPasswordWidget(),
                  const SizedBox(height: 10),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        // logIn(_scaffoldKey.currentContext);
                        final email = _mailController.text;
                        final password = _passwordController.text;

                        UserAuthentication().logIn(context, email, password);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(235, 255, 123, 0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            "Continue",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    child: const Text(
                      "Forgot your password?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(235, 255, 123, 0),
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
}
