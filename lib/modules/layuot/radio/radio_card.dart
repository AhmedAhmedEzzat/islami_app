import 'package:flutter/material.dart';
import 'package:islami1/core/constants/colors.dart';

class RadioCard extends StatelessWidget {
  final String title;
  final String bgPattern;
  final IconData playIcon;
  final IconData volumeIcon;
  final VoidCallback onPlayPressed;
  final VoidCallback onVolumePressed;

  const RadioCard({
    super.key,
    required this.title,
    required this.bgPattern,
    required this.playIcon,
    required this.volumeIcon,
    required this.onPlayPressed,
    required this.onVolumePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorsPallete.primaryColor,
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(image: AssetImage(bgPattern), fit: BoxFit.cover),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black,
              fontFamily: 'Janna',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onPlayPressed,
                child: Icon(playIcon, size: 32, color: Colors.black),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: onVolumePressed,
                child: Icon(volumeIcon, size: 28, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
