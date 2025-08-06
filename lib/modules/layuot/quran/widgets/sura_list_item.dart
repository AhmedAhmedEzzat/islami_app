import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/models/sura_data_model.dart';

class SuraListItem extends StatelessWidget {
  final SuraDataModel suraDataModel;
  final VoidCallback? onSurahTap;

  const SuraListItem({super.key, required this.suraDataModel, this.onSurahTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSurahTap,
      child: Row(
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
            child: Text(suraDataModel.suraID, style: Theme
                .of(context)
                .textTheme
                .bodySmall),
          ),
          SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(suraDataModel.suraNameEN, style: Theme
                  .of(context)
                  .textTheme
                  .titleLarge),
              Text(suraDataModel.suraVersesNumber, style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium),
            ],
          ),
          Spacer(),
          Text(suraDataModel.suraNameAR, style: Theme
              .of(context)
              .textTheme
              .titleLarge),
        ],
      ),
    );
  }
}
