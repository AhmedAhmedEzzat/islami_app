import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';

class PrayTimeHeader extends StatelessWidget {
  const PrayTimeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.35,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColorsPallete.cardTimeColor,
              borderRadius: BorderRadius.circular(40),
            ),
          ),

          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.asset(
              'assets/images/pray_header.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "16 Jul \n 2024",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Janna',
                      ),
                    ),
                    Text(
                      "Pray Time",
                      style: TextStyle(
                        fontSize: 20,
                        color: ColorsPallete.unselectedIcon,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Janna',
                      ),
                    ),
                    Text(
                      "09 Muh \n 1446",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Janna',
                      ),
                    ),
                  ],
                ),

                const Text(
                  "Tuesday",
                  style: TextStyle(
                    fontSize: 20,
                    color: ColorsPallete.unselectedIcon,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Janna',
                  ),
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPrayTime("Sunrise", "04:04 AM"),
                      _buildPrayTime("Duhr", "01:01 PM"),
                      _buildPrayTime("ASR", "04:38 PM"),
                      _buildPrayTime("Maghrib", "07:57 PM"),
                      _buildPrayTime("Isha", "09:13 PM"),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Next Pray - 02:32",
                        style: TextStyle(
                          color: ColorsPallete.unselectedIcon,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Janna',
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(
                        Icons.volume_off,
                        color: ColorsPallete.unselectedIcon,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPrayTime(String name, String time) {
    return Container(
      width: 110,
      height: 115,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.black87, Colors.black54],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Janna',
            ),
          ),
          Text(
            time.split(' ')[0],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: Colors.white,
              fontFamily: 'Janna',
            ),
          ),
          Text(
            time.split(' ')[1],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Janna',
            ),
          ),
        ],
      ),
    );
  }
}
