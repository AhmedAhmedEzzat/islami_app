import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';

class SuraListItem extends StatelessWidget {
  const SuraListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(Assets.suraNumberIcn),
              fit: BoxFit.cover,
            ),
          ),
          child: Text('1', style: Theme.of(context).textTheme.bodySmall),
        ),
        SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AL-FATIHA', style: Theme.of(context).textTheme.titleLarge),
            Text('7 Verses', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Spacer(),
        Text('الفاتحه', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
