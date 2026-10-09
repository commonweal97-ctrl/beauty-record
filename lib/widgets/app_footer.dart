import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Column(
        children: [
          SvgPicture.asset('assets/LogoZapis.svg', height: 12, colorFilter: const ColorFilter.mode(Color(0xFFBBBBBB), BlendMode.srcIn)),
          const Text('Версия 1.0.0', style: TextStyle(fontSize: 10, color: Color(0xFFCCCCCC))),
        ],
      ),
    );
  }
}