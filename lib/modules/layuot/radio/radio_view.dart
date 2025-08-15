import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/modules/layuot/radio/radio_card.dart';
import 'package:islami1/modules/layuot/radio/radio_tab_bar.dart';

class RadioView extends StatefulWidget {
  const RadioView({super.key});

  @override
  State<RadioView> createState() => _RadioViewState();
}

class _RadioViewState extends State<RadioView> {
  int? playingIndex;
  bool isMuted = false;
  bool isRadioTab = true;

  final List<String> radioNames = [
    "Ibrahim Al-Akdar",
    "Al-Qaria Yassen",
    "Ahmed Al-trabulsi",
    "Addokali Mohammad Alalim"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(Assets.radioBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Image.asset(
              Assets.headerLogo,
              height: MediaQuery
                  .of(context)
                  .size
                  .height * 0.2,
            ),
            const SizedBox(height: 20),

            RadioTabBar(
              isRadioTab: isRadioTab,
              onRadioTap: () => setState(() => isRadioTab = true),
              onRecitersTap: () => setState(() => isRadioTab = false),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: radioNames.length,
                itemBuilder: (context, index) {
                  final title = isRadioTab
                      ? "Radio ${radioNames[index]}"
                      : radioNames[index];
                  final isPlaying = playingIndex == index;
                  final pattern = isPlaying
                      ? Assets.soundWave
                      : Assets.mosqueWave;
                  final playIcon =
                  isPlaying ? Icons.pause : Icons.play_arrow;
                  final volumeIcon = isMuted && isPlaying
                      ? Icons.volume_off
                      : Icons.volume_up;

                  return RadioCard(
                    title: title,
                    bgPattern: pattern,
                    playIcon: playIcon,
                    volumeIcon: volumeIcon,
                    onPlayPressed: () {
                      setState(() {
                        if (playingIndex == index) {
                          playingIndex = null;
                        } else {
                          playingIndex = index;
                          isMuted = false;
                        }
                      });
                    },
                    onVolumePressed: () {
                      if (isPlaying) {
                        setState(() {
                          isMuted = !isMuted;
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
