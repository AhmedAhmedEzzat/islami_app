import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/models/hadeth_data_model.dart';
import 'package:islami1/modules/layuot/hadeth/widgets/hadeth_item_widget.dart';

class HadethView extends StatefulWidget {
  const HadethView({super.key});

  @override
  State<HadethView> createState() => _HadethViewState();
}

class _HadethViewState extends State<HadethView> {
  List<HadethDataModel> allHadeth = [];
  bool isLoading = true;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    loadHadeth();
  }

  Future<void> loadHadeth() async {
    try {
      for (int i = 1; i <= 50; i++) {
        String fileName = 'assets/hadeth/h$i.txt';
        String fileContent = await rootBundle.loadString(fileName);
        List<String> lines = fileContent.trim().split('\n');
        String title = lines.first;
        List<String> content = lines.sublist(1);

        allHadeth.add(HadethDataModel(title: title, content: content));
      }
    } catch (e) {
      debugPrint("خطأ في تحميل الأحاديث: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

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
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: CarouselSlider.builder(
                          itemCount: allHadeth.length,
                          itemBuilder: (context, index, realIndex) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: HadethItemWidget(hadeth: allHadeth[index]),
                            );
                          },
                          options: CarouselOptions(
                            height: MediaQuery.of(context).size.height * 0.75,
                            viewportFraction: 0.75,
                            initialPage: currentIndex,
                            enableInfiniteScroll: true,
                            autoPlay: false,
                            enlargeCenterPage: true,
                            enlargeFactor: 0.25,
                            scrollDirection: Axis.horizontal,
                            onPageChanged: (index, reason) {
                              setState(() {
                                currentIndex = index;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}