class HadethDataModel {
  HadethDataModel({required this.title, required this.content, this.number = 0});

  final String title;
  final List<String> content;

  /// The bundled file number (h1..h50), a stable id for favourites.
  final int number;

  String get fullText => '$title\n\n${content.join('\n')}';
}
