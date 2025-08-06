import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/core/constants/colors.dart';
import 'package:islami1/models/hadeth_data_model.dart';
import 'package:islami1/modules/layuot/hadeth/hadeth_details_view.dart';

class HadethItemWidget extends StatelessWidget {
  final HadethDataModel hadeth;

  const HadethItemWidget({super.key, required this.hadeth});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HadethDetailsView(hadeth: hadeth)),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: ColorsPallete.primaryColor,
          image: DecorationImage(
            image: AssetImage(Assets.hadethBackgroundCard),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        Assets.leftCornerHadith,
                        width: 90,
                        height: 90,
                      ),
                      Image.asset(
                        Assets.rightCornerHadith,
                        width: 90,
                        height: 90,
                      ),
                    ],
                  ),
                ),
                Image.asset(Assets.mosque),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    hadeth.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'Janna',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(thickness: 1, color: Colors.black),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemBuilder: (context, index) => Text(
                        hadeth.content[index],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontFamily: 'Janna',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemCount: hadeth.content.length,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
