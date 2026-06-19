import 'package:flutter/material.dart';

/// Fait défiler jusqu'au premier [FormField] invalide du formulaire.
Future<void> scrollToFirstFormError(
  BuildContext formContext, {
  Duration duration = const Duration(milliseconds: 350),
  double alignment = 0.12,
}) async {
  await Future<void>.delayed(Duration.zero);

  FormFieldState<dynamic>? firstError;
  void visit(Element element) {
    if (firstError != null) return;
    if (element is StatefulElement) {
      final state = element.state;
      if (state is FormFieldState && state.hasError) {
        firstError = state;
        return;
      }
    }
    element.visitChildren(visit);
  }

  formContext.visitChildElements(visit);
  if (firstError == null || !firstError!.context.mounted) return;

  await Scrollable.ensureVisible(
    firstError!.context,
    duration: duration,
    curve: Curves.easeInOut,
    alignment: alignment,
    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
  );
}
