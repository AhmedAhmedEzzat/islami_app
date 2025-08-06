import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/core/constants/colors.dart';
import 'package:islami1/models/sura_data_model.dart';
import 'package:islami1/modules/layuot/quran/widgets/quran_verse_widget.dart';

class QuranDetailsView extends StatefulWidget {
  static const String routeName = 'QuranDetailsView';

  const QuranDetailsView({super.key});

  @override
  State<QuranDetailsView> createState() => _QuranDetailsViewState();
}

class _QuranDetailsViewState extends State<QuranDetailsView> {
  @override
  Widget build(BuildContext context) {
    final data = ModalRoute.of(context)!.settings.arguments as SuraDataModel;
    if (suraData.isEmpty) {
      loadSuraData(data.suraID);
    }

    return Scaffold(
      backgroundColor: ColorsPallete.quranDetailsColor,
      appBar: AppBar(title: Text(data.suraNameEN), centerTitle: true),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(Assets.vectorLeft, height: 90, width: 90),
                    Image.asset(Assets.vectorRight, height: 90, width: 90),
                  ],
                ),
              ),
              Image.asset(Assets.quranBottomDetails),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                data.suraNameAR,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ColorsPallete.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) => QuranVerseWidget(
                    verse: '${suraData[index]} [${index + 1}]',
                  ),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemCount: suraData.length,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> suraData = [];

  Future<void> loadSuraData(String suraID) async {
    String content = await rootBundle.loadString('assets/files/$suraID.txt');
    suraData = content.split('\n');
    setState(() {});
    print(suraData.length);
    print(content);
  }
}
