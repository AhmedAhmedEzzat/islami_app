import 'package:material_ui/material_ui.dart';

/// A bottom sheet as tall as what it holds, which scrolls when the screen is
/// too short for that.
///
/// A plain modal sheet stops at nine sixteenths of the screen. A list of
/// options that fits under that on a tall phone runs off the bottom on a
/// short one, in landscape, or with a large font, and the last options
/// cannot be reached.
Future<T?> showFittedSheet<T>(BuildContext context, {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(child: builder(context)),
    );
