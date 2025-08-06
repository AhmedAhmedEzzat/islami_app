import 'package:flutter/material.dart';
import 'package:islami1/core/constants/colors.dart';
import 'package:islami1/core/constants/constants.dart';
import 'package:islami1/core/services/shared_prefs_helper.dart';
import 'package:islami1/models/sura_data_model.dart';
import 'package:islami1/modules/layuot/quran/quran_details_view.dart';
import 'package:islami1/modules/layuot/quran/widgets/recentily_sura_widget.dart';
import 'package:islami1/modules/layuot/quran/widgets/sura_list_widget.dart';

import '../../../core/constants/assets.dart';

class QuranView extends StatefulWidget {
  QuranView({super.key});

  @override
  State<QuranView> createState() => _QuranViewState();
}

class _QuranViewState extends State<QuranView> {
  @override
  void initState() {
    super.initState();
    loadRecentSura();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(Assets.quranBackground),
          fit: BoxFit.cover,
        ),
      ),
      child: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        child: Column(
          spacing: 20,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(Assets.headerLogo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextFormField(
                cursorColor: ColorsPallete.primaryColor,
                decoration: InputDecoration(
                  hintText: 'Sura Name',
                  hintStyle: Theme.of(context).textTheme.bodyLarge,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: ColorsPallete.primaryColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: ColorsPallete.primaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: ColorsPallete.primaryColor),
                  ),

                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ImageIcon(
                      AssetImage(Assets.quranIcon),
                      color: ColorsPallete.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            recentSuraList.isNotEmpty
                ? RecentlySuraWidget(suraDataModel: recentSuraList)
                : Center(
                    child: Text(
                      'No Recent Sura',
                      style: TextStyle(
                        color: ColorsPallete.primaryColor,
                        fontSize: 18,
                      ),
                    ),
                  ),
            SuraListWidget(onSurahTap: onSurahTap),
          ],
        ),
      ),
    );
  }

  List<String> recentSuraIndexList = [];

  List<SuraDataModel> recentSuraList = [];

  onSurahTap(int index) {
    _cachingRecentSura(index);
    Navigator.pushNamed(
      context,
      QuranDetailsView.routeName,
      arguments: Constants.suraDataLists[index],
    );
  }

  _cachingRecentSura(int index) {
    var indexString = index.toString();
    if (recentSuraIndexList.contains(indexString)) {
      return;
    }
    if (recentSuraIndexList.length == 5) {
      recentSuraIndexList.removeLast();
    }
    recentSuraIndexList.insert(0, indexString);
    LocalStorageServices.setStringList(
      'recent-sura-index',
      recentSuraIndexList,
    );
    loadRecentSura();
    setState(() {});
  }

  loadRecentSura() {
    recentSuraIndexList = [];
    recentSuraList = [];
    recentSuraIndexList =
        LocalStorageServices.getStringList('recent-sura-index') ?? [];
    for (var index in recentSuraIndexList) {
      int indexInt = int.parse(index);
      recentSuraList.add(Constants.suraDataLists[indexInt]);
    }
  }
}
