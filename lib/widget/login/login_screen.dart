//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// import 'package:login_app/auth/user_authentication.dart';
// import 'package:login_app/view/login/login_card.dart';
// import 'package:login_app/view/main_page.dart';

import 'package:jsonschema/widget/login/background_screen.dart';
import 'package:jsonschema/widget/login/heading_text.dart';
import 'package:jsonschema/widget/login/login_card.dart';

// ignore: must_be_immutable

class LoginScreen extends StatelessWidget {
  final String email;
  const LoginScreen({super.key, required this.email});
  //final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Stack(
        children: [
          const BackgroundScreen(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                  child: MainHeading(title: "Log in"),
                ),
                LoginCard(email: email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// class LoginScreen extends StatefulWidget {
//   LoginScreen({Key? key, required this.email}) : super(key: key);
//   final String email;

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final _scaffoldKey = GlobalKey<ScaffoldState>();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       resizeToAvoidBottomInset: false,
//       body: SafeArea(
//         child: Stack(
//           children: [
//             const BackgroundScreen(),
//             const BackButtonWidget(),
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 100),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Padding(
//                     padding: EdgeInsets.symmetric(
//                       vertical: 20,
//                       horizontal: 30,
//                     ),
//                     child: MainHeading(
//                       title: "Log in",
//                     ),
//                   ),
//                   LoginCard(
//                     widget: widget,
//                   )
//                 ],
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }



// "Wrong password provided for that user.",