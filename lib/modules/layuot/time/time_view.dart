import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/modules/layuot/time/azkar_section.dart';
import 'package:islami1/modules/layuot/time/pray_time_header.dart';

class TimeView extends StatelessWidget {
  const TimeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(Assets.timeBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  Assets.headerLogo,
                  height: MediaQuery.of(context).size.height * 0.2,
                ),
              ),

              const PrayTimeHeader(),

              const SizedBox(height: 10),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Azkar",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Janna',
                  ),
                ),
              ),

              const SizedBox(height: 10),
              const AzkarSection(),
            ],
          ),
        ),
      ),
    );
  }
}
