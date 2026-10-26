import 'package:flutter/widgets.dart';

// Mobile Flutter does not unfocus a text field on a tap outside it (only web
// does), so the keyboard would stay open. Pass this to MaterialApp's `actions`.
final Map<Type, Action<Intent>> tapOutsideUnfocusActions = {
  ...WidgetsApp.defaultActions,
  EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
    onInvoke: (intent) {
      intent.focusNode.unfocus();
      return null;
    },
  ),
};
