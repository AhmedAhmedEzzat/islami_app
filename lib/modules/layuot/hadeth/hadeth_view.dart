import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:islami1/modules/layuot/hadeth/widgets/hadeth_item_widget.dart';

import '../../../core/constants/assets.dart';

class HadethView extends StatelessWidget {
  const HadethView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(Assets.hadethBackground),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Image.asset(Assets.headerLogo),
          CarouselSlider(
              items: [
                HadethItemWidget()

              ],
              options: CarouselOptions(
                height: MediaQuery
                    .of(context)
                    .size
                    .height * .6,
                aspectRatio: 16 / 9,
                viewportFraction: 0.8,
                initialPage: 0,
                enableInfiniteScroll: true,
                reverse: false,
                autoPlay: false,
                autoPlayAnimationDuration: Duration(milliseconds: 800),
                autoPlayCurve: Curves.fastOutSlowIn,
                enlargeCenterPage: true,
                enlargeFactor: 0.3,
                scrollDirection: Axis.horizontal,
              )
          )
        ],
      ),
    );
  }
}
