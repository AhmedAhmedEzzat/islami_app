/// A live Quran radio station.
///
/// Every URL here was checked to return `audio/mpeg`; two of the originally
/// listed slugs returned 404 and were replaced.
class RadioChannel {
  const RadioChannel({required this.name, required this.streamUrl});

  final String name;
  final String streamUrl;

  static const List<RadioChannel> channels = [
    RadioChannel(
      name: 'Ibrahim Al-Akdar',
      streamUrl: 'https://Qurango.net/radio/ibrahim_alakdar',
    ),
    RadioChannel(
      name: 'Yasser Al-Dosari',
      streamUrl: 'https://Qurango.net/radio/yasser_aldosari',
    ),
    RadioChannel(
      name: 'Abdul Basit Abdul Samad',
      streamUrl: 'https://Qurango.net/radio/abdulbasit_abdulsamad_mujawwad',
    ),
    RadioChannel(
      name: 'Mahmoud Khalil Al-Hussary',
      streamUrl: 'https://Qurango.net/radio/mahmoud_khalil_alhussary',
    ),
    RadioChannel(
      name: 'Mishary Rashid Alafasy',
      streamUrl: 'https://Qurango.net/radio/mishary_alafasi',
    ),
    RadioChannel(
      name: 'Maher Al-Muaiqly',
      streamUrl: 'https://Qurango.net/radio/maher_almuaiqly',
    ),
    RadioChannel(
      name: 'Saud Al-Shuraim',
      streamUrl: 'https://Qurango.net/radio/saud_alshuraim',
    ),
    RadioChannel(
      name: 'Nasser Al-Qatami',
      streamUrl: 'https://Qurango.net/radio/nasser_alqatami',
    ),
    RadioChannel(
      name: 'Hani Ar-Rifai',
      streamUrl: 'https://Qurango.net/radio/hani_arrifai',
    ),
    RadioChannel(
      name: 'Khalifa Al-Tunaiji',
      streamUrl: 'https://Qurango.net/radio/khalifa_altunaiji',
    ),
  ];
}
