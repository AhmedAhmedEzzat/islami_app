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
  const QuranView({super.key});

  @override
  State<QuranView> createState() => _QuranViewState();
}

class _QuranViewState extends State<QuranView> {
  String searchText = '';
  List<String> recentSuraIndexList = [];
  List<SuraDataModel> recentSuraList = [];
  List<SuraDataModel> suraList = [];
  List<SuraDataModel> filteredSuraList = [];

  @override
  void initState() {
    super.initState();
    loadRecentSura();
    // Initialize with all surahs
    filteredSuraList = List.from(Constants.suraDataLists);
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
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(Assets.headerLogo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextFormField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                    searchSura();
                  });
                },
                style: Theme.of(context).textTheme.bodyLarge,
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
            _buildContentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    if (searchText.isNotEmpty) {
      return SuraListWidget(
        onSurahTap: onSurahTap,
        suraDataModels: filteredSuraList,
      );
    } else {
      return Column(
        children: [
          if (recentSuraList.isNotEmpty)
            RecentlySuraWidget(suraDataModel: recentSuraList)
          else
            Center(
              child: Text(
                'No Recent Sura',
                style: TextStyle(
                  color: ColorsPallete.primaryColor,
                  fontSize: 18,
                ),
              ),
            ),
          SuraListWidget(
            onSurahTap: onSurahTap,
            suraDataModels: Constants.suraDataLists,
          ),
        ],
      );
    }
  }

  void onSurahTap(int index) {
    _cachingRecentSura(index);
    Navigator.pushNamed(
      context,
      QuranDetailsView.routeName,
      arguments: Constants.suraDataLists[index],
    );
  }

  void _cachingRecentSura(int index) {
    final indexString = index.toString();

    if (recentSuraIndexList.contains(indexString)) {
      recentSuraIndexList.remove(indexString);
    }

    recentSuraIndexList.insert(0, indexString);

    if (recentSuraIndexList.length > 5) {
      recentSuraIndexList = recentSuraIndexList.sublist(0, 5);
    }

    LocalStorageServices.setStringList(
      'recent-sura-index',
      recentSuraIndexList,
    );

    loadRecentSura();
  }

  void loadRecentSura() {
    recentSuraIndexList =
        LocalStorageServices.getStringList('recent-sura-index') ?? [];
    recentSuraList = recentSuraIndexList
        .map((index) => Constants.suraDataLists[int.parse(index)])
        .toList();
    setState(() {});
  }

  void searchSura() {
    filteredSuraList = Constants.suraDataLists.where((sura) {
      return sura.suraNameEN.toLowerCase().contains(searchText.toLowerCase()) ||
          sura.suraNameAR.contains(searchText);
    }).toList();
  }
}