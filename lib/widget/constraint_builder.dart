import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ConstraintBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;

  const ConstraintBuilder({super.key, required this.builder});

  @override
  State<ConstraintBuilder> createState() => _ConstraintBuilderState();
}

class _ConstraintBuilderState extends State<ConstraintBuilder> {
  BoxConstraints? _constraints;

  void _update(BoxConstraints c) {
    if (_constraints == c) return; // évite les boucles

    if (_constraints != null &&
        _constraints!.hasBoundedHeight == c.hasBoundedHeight &&
        _constraints!.hasBoundedWidth == c.hasBoundedWidth) {
      _constraints = c;
      // évite setState inutile = uniquement les contraintes de bornes changent
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // évite setState après dispose
      setState(() => _constraints = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ConstraintListener(
      onConstraints: _update,
      child:
          _constraints == null
              ? const SizedBox.shrink() // évite de builder avant d'avoir les contraintes
              : widget.builder(context, _constraints!),
    );
  }
}

class _ConstraintListener extends SingleChildRenderObjectWidget {
  final void Function(BoxConstraints constraints) onConstraints;

  const _ConstraintListener({
    required this.onConstraints,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _ConstraintRenderObject(onConstraints);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ConstraintRenderObject renderObject,
  ) {
    renderObject.onConstraints = onConstraints;
  }
}

class _ConstraintRenderObject extends RenderProxyBox {
  _ConstraintRenderObject(this.onConstraints);

  void Function(BoxConstraints constraints) onConstraints;

  @override
  void performLayout() {
    super.performLayout();
    onConstraints(constraints);
  }
}
