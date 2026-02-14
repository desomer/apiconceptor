import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/cw_repository_action.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwAdvancedPager extends CwWidget {
  const CwAdvancedPager({
    super.key,
    required super.ctx,
    required super.cacheWidget,
  });

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'pager',
      build:
          (ctx) => CwAdvancedPager(
            key: ctx.getKey(),
            ctx: ctx,
            cacheWidget: CachedWidget(),
          ),
      config: (ctx) {
        return CwWidgetConfig();
      },
    );
  }

  @override
  State<CwAdvancedPager> createState() => _AdvancedPagerState();
}

class _AdvancedPagerState extends CwWidgetState<CwAdvancedPager>
    with HelperEditor {
  int pageCount = 10;
  int currentPage = 0;
  CwRepository? repos;

  void goTo(BuildContext context, int page) {
    if (widget.ctx.aFactory.isModeDesigner()) return;

    setState(() {
      currentPage = page;
      CwRepositoryAction(ctx: widget.ctx, repo: repos!).goToPage(context, page);
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.layoutBuilder, (
      ctx,
      constraints,
      _,
    ) {
      repos =
          ctx.aFactory.mapRepositories[ctx
              .dataWidget?[cwProps]?['bind']?['repository']]!;

      // double height = 1;
      // var label = getStringProp(ctx, 'label');
      // var spacer = getStringProp(ctx, 'type') == 'spacer';
      return _getWidget(repos!, context);
    });
  }

  Widget _getWidget(CwRepository repos, BuildContext context) {
    // // --- Indicateur ---
    // var r = Row(
    //   mainAxisAlignment: MainAxisAlignment.center,
    //   children: List.generate(pageCount, (i) {
    //     final active = i == currentPage;
    //     return AnimatedContainer(
    //       duration: const Duration(milliseconds: 200),
    //       margin: const EdgeInsets.symmetric(horizontal: 3),
    //       width: active ? 14 : 8,
    //       height: 8,
    //       decoration: BoxDecoration(
    //         color:
    //             active
    //                 ? Theme.of(context).colorScheme.primary
    //                 : Theme.of(context).colorScheme.outlineVariant,
    //         borderRadius: BorderRadius.circular(4),
    //       ),
    //     );
    //   }),
    // );

    var bs = ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
      minimumSize: WidgetStateProperty.all(const Size(30, 0)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    // --- Navigation avancée ---
    var w = Wrap(
      spacing: 5,
      runSpacing: 0,
      alignment: WrapAlignment.center,
      children: [
        // Start
        FilledButton.tonal(
          style: bs,
          onPressed: currentPage > 0 ? () => goTo(context, 0) : null,
          child: const Text("<<"),
        ),

        // Previous
        FilledButton.tonal(
          style: bs,
          onPressed:
              currentPage > 0 ? () => goTo(context, currentPage - 1) : null,
          child: const Text("<"),
        ),

        // Pages -3 -2 -1
        ...List.generate(3, (offset) {
          final target = currentPage - (3 - offset);
          if (target < 0) return const SizedBox.shrink();
          return OutlinedButton(
            style: bs,
            onPressed: () => goTo(context, target),
            child: Text("${target + 1}"),
          );
        }),

        // Current page (désactivé)
        FilledButton.tonal(
          style: bs,
          onPressed: null,
          child: Text("${currentPage + 1}"),
        ),

        // Pages +1 +2 +3
        ...List.generate(3, (offset) {
          final target = currentPage + offset + 1;
          if (target >= pageCount) return const SizedBox.shrink();
          return OutlinedButton(
            style: bs,
            onPressed: () => goTo(context, target),
            child: Text("${target + 1}"),
          );
        }),

        // Next
        FilledButton.tonal(
          style: bs,
          onPressed:
              currentPage < pageCount - 1
                  ? () => goTo(context, currentPage + 1)
                  : null,
          child: const Text(">"),
        ),

        // End
        FilledButton.tonal(
          style: bs,
          onPressed:
              currentPage < pageCount - 1
                  ? () => goTo(context, pageCount - 1)
                  : null,
          child: const Text(">>"),
        ),
      ],
    );
    return w;
  }
}
