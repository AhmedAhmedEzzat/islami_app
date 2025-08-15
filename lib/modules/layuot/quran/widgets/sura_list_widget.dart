import 'package:flutter/material.dart';
import 'package:islami1/models/sura_data_model.dart';
import 'package:islami1/modules/layuot/quran/widgets/sura_list_item.dart';

class SuraListWidget extends StatelessWidget {
  const SuraListWidget(
      {super.key, required this.onSurahTap, required this.suraDataModels});

  final void Function(int) onSurahTap;
  final List<SuraDataModel> suraDataModels;

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
                onSurahTap: () =>
                    onSurahTap(int.parse(suraDataModels[index].suraID) - 1),
                suraDataModel: suraDataModels[index],
              );
            },
            separatorBuilder: (context, index) {
              return Divider(indent: 40, endIndent: 40);
            },
            itemCount: suraDataModels.length,
          ),
        ],
      ),
    );
  }
}
