import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/core/constants/colors.dart';
import 'package:islami1/models/hadeth_data_model.dart';

class HadethDetailsView extends StatelessWidget {
  final HadethDataModel hadeth;

  const HadethDetailsView({super.key, required this.hadeth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsPallete.quranDetailsColor,
      appBar: AppBar(
        title: Text(
          hadeth.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
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
              const SizedBox(height: 20),
              Text(
                hadeth.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ColorsPallete.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: ListView.separated(
                    itemCount: hadeth.content.length,
                    itemBuilder: (context, index) {
                      return Text(
                        hadeth.content[index],
                        textAlign: TextAlign.justify,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: ColorsPallete.primaryColor,
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
