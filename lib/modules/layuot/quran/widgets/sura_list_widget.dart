import 'package:flutter/material.dart';
import 'package:islami1/core/constants/constants.dart';
import 'package:islami1/modules/layuot/quran/widgets/sura_list_item.dart';

class SuraListWidget extends StatelessWidget {
  const SuraListWidget({super.key, required this.onSurahTap});

  final void Function(int) onSurahTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sura List', style: Theme.of(context).textTheme.bodyLarge),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              return SuraListItem(
                onSurahTap: () => onSurahTap(index),
                suraDataModel: Constants.suraDataLists[index],
              );
            },
            separatorBuilder: (context, index) {
              return Divider(indent: 40, endIndent: 40);
            },
            itemCount: Constants.suraDataLists.length,
          ),
        ],
      ),
    );
  }
}
