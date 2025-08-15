import 'package:flutter/material.dart';
import 'package:islami1/core/constants/colors.dart';

class PrayTimeCard extends StatelessWidget {
  const PrayTimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorsPallete.primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // التاريخ واليوم
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Sunday, 14 Jan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "3 Rajab 1445",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // جدول مواقيت الصلاة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _PrayTimeItem("Fajr", "05:30 AM"),
              _PrayTimeItem("Dhuhr", "12:15 PM"),
              _PrayTimeItem("Asr", "03:45 PM"),
              _PrayTimeItem("Maghrib", "06:10 PM"),
              _PrayTimeItem("Isha", "07:45 PM"),
            ],
          ),
          const SizedBox(height: 20),

          // Next Prayer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Next: Dhuhr in 2h 45m",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayTimeItem extends StatelessWidget {
  final String name;
  final String time;

  const _PrayTimeItem(this.name, this.time);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(time),
      ],
    );
  }
}
