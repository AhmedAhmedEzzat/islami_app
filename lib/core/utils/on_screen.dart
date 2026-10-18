import 'package:flutter/widgets.dart';

/// Whether [context] is on the page in view: the top route of its navigator,
/// in the tab that is showing.
bool isOnScreen(BuildContext context) =>
    TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
