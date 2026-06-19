import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Utilitaires pour fermer le clavier lorsqu'on tape en dehors d'un champ.
abstract final class KeyboardDismiss {
  static void unfocus(BuildContext context) {
    final current = FocusManager.instance.primaryFocus;
    if (current != null && current.hasFocus) {
      current.unfocus();
    }
  }
}

/// Enveloppe l'app : ferme le clavier si le tap n'est pas sur un champ ou un contrôle interactif.
class KeyboardDismissOnTap extends StatelessWidget {
  const KeyboardDismissOnTap({super.key, required this.child});

  final Widget child;

  static bool _shouldDismissForHit(HitTestResult result) {
    for (final HitTestEntry entry in result.path) {
      final target = entry.target;
      if (target is RenderEditable) return false;
      if (target is RenderSemanticsGestureHandler) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null || !focus.hasFocus) return;

        final hitTest = HitTestResult();
        final view = View.of(context);
        WidgetsBinding.instance.hitTestInView(hitTest, event.position, view.viewId);
        if (_shouldDismissForHit(hitTest)) {
          focus.unfocus();
        }
      },
      child: child,
    );
  }
}

/// [SingleChildScrollView] avec fermeture du clavier au tap sur la zone vide.
class KeyboardDismissScrollView extends StatelessWidget {
  const KeyboardDismissScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.physics,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      controller: controller,
      physics: physics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: GestureDetector(
        onTap: () => KeyboardDismiss.unfocus(context),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}
