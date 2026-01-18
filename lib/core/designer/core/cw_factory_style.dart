import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';

class CWFactoryStyle {
  List<CwWidgetProperties> initMargin(CwWidgetCtx ctx) {
    List<CwWidgetProperties> listStyle = [];
    listStyle.add(
      CwWidgetProperties(id: 'mtop', name: 'padding top')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.expand_less,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'mbottom', name: 'padding bottom')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.expand_more,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'mleft', name: 'padding left')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.chevron_left,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'mright', name: 'padding right')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.chevron_right,
        path: [cwStyle],
      ),
    );
    return listStyle;
  }

  List<CwWidgetProperties> initPadding(CwWidgetCtx ctx) {
    List<CwWidgetProperties> listStyle = [];
    listStyle.add(
      CwWidgetProperties(id: 'ptop', name: 'margin top')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.arrow_upward_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'pbottom', name: 'margin bottom')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.arrow_downward_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'pleft', name: 'margin left')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.west_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'pright', name: 'margin right')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.east_rounded,
        path: [cwStyle],
      ),
    );
    return listStyle;
  }

  List<CwWidgetProperties> initBorder(CwWidgetCtx ctx) {
    List<CwWidgetProperties> listStyle = [];
    listStyle.add(
      CwWidgetProperties(id: 'elevation', name: 'elevation')..isSlider(
        ctx,
        min: 0,
        max: 20,
        icon: Icons.copy_all_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'bSize', name: 'border size')..isSlider(
        ctx,
        min: 0,
        max: 20,
        icon: Icons.highlight_alt_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'bRadius', name: 'b. radius')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.panorama_wide_angle_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'bColor', name: 'border color')
        ..isColor(ctx, icon: Icons.border_color_rounded, path: [cwStyle]),
    );
    return listStyle;
  }

  List<CwWidgetProperties> initAlignment(CwWidgetCtx ctx) {
    List<CwWidgetProperties> listStyle = [];

    List listAxis = [
      {'icon': Icons.align_vertical_top, 'value': -1},
      {'icon': Icons.align_vertical_center, 'value': 0},
      {'icon': Icons.align_vertical_bottom, 'value': 1},
    ];

    List listCross = [
      {'icon': Icons.align_horizontal_left, 'value': -1},
      {'icon': Icons.align_horizontal_center, 'value': 0},
      {'icon': Icons.align_horizontal_right, 'value': 1},
    ];

    listStyle.add(
      CwWidgetProperties(id: 'boxAlignH', name: 'Box align H.')
        ..isToogle(ctx, path: [cwStyle], listCross),
    );
    listStyle.add(
      CwWidgetProperties(id: 'boxAlignV', name: 'Box align V.')
        ..isToogle(ctx, path: [cwStyle], listAxis),
    );
    return listStyle;
  }

  List<CwWidgetProperties> initBackground(CwWidgetCtx ctx) {
    List<CwWidgetProperties> listStyle = [];

    listStyle.add(
      CwWidgetProperties(id: 'bgColor', name: 'background color')
        ..isColor(ctx, icon: Icons.format_color_fill, path: [cwStyle]),
    );

    return listStyle;
  }

  List<CwWidgetProperties> initText(CwWidgetCtx ctx) {
    List<CwWidgetProperties> listStyle = [];

    List listTextAlign = [
      {'icon': Icons.align_horizontal_left, 'value': 'start'},
      {'icon': Icons.align_horizontal_center, 'value': 'center'},
      {'icon': Icons.align_horizontal_right, 'value': 'end'},
    ];

    listStyle.add(
      CwWidgetProperties(id: 'textalign', name: 'text align')
        ..isToogle(ctx, path: [cwStyle], listTextAlign),
    );

    listStyle.add(
      CwWidgetProperties(id: 'tColor', name: 'text color')
        ..isColor(ctx, icon: Icons.format_color_text_rounded, path: [cwStyle]),
    );

    listStyle.add(
      CwWidgetProperties(id: 'tSize', name: 'text size')
        ..isInt(ctx, path: [cwStyle]),
    );

    List listTextType = [
      {'icon': Icons.format_bold, 'value': 'bold'},
      {'icon': Icons.format_italic, 'value': 'italic'},
      {'icon': Icons.format_underline, 'value': 'underline'},
      {'icon': Icons.format_strikethrough, 'value': 'lineThrough'},
      {'icon': Icons.format_overline, 'value': 'overline'},
    ];

    listStyle.add(
      CwWidgetProperties(id: 'textstyle', name: 'text style')
        ..isToogle(ctx, path: [cwStyle], listTextType, isMultiple: true),
    );

    return listStyle;
  }
}
//     // Text('\$8.99',
//     //     style: TextStyle(
//     //         color: Colors.grey[800],
//     //         fontWeight: FontWeight.bold,
//     //         fontStyle: FontStyle.italic,
//     //         fontSize: 40,
//     //         decoration: TextDecoration.lineThrough));
//   }
// }

//     attr = CoreDataAttribut('imagebg')
//         .init(CDAttributType.text,
//             tName: CWSelectorType.image.name, aLabel: 'bg image')
//         .addCustomValue('icon', Icons.image);
//     loader.addAttr(attr);

//     //-----------------------------------------------------
//     CWAppLoaderCtx ctxLoader2 = CWAppLoaderCtx().from(ctx.loader);
//     ctxLoader2.addRepository(provider, isEntity: false);

//     AttrFormLoader loader2 = AttrFormLoader(
//         'rootBody0', ctxLoader2, 'Gradient Background', provider,
//         config: FormConfig(typeForm: ModeForm.expand, isEntity: false)
//           ..isRoot = true);

//     List listGradiant = [
//       {'icon': Icons.gradient, 'value': 'lin'},
//       {'icon': Icons.circle, 'value': 'rad'},
//     ];

//     attr = CoreDataAttribut('gradient')
//         .init(CDAttributType.text, tName: 'toogle', aLabel: 'type')
//         .addCustomValue('bindValue', listGradiant);
//     loader2.addAttr(attr);

//     attr = CoreDataAttribut('bgColor1')
//         .init(CDAttributType.one,
//             tName: CWSelectorType.color.name, aLabel: 'color 1')
//         .addCustomValue('icon', Icons.format_color_fill);
//     loader2.addAttr(attr);

//     attr = CoreDataAttribut('gEnter1')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'enter in %')
//         .addCustomValue('icon', Icons.percent)
//         .addCustomValue('min', 0)
//         .addCustomValue('max', 100);
//     loader2.addAttr(attr);

//     attr = CoreDataAttribut('gAlignX1')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'align x')
//         .addCustomValue('icon', Icons.percent)
//         .addCustomValue('min', -100)
//         .addCustomValue('max', 100);
//     loader2.addAttr(attr);
//     attr = CoreDataAttribut('gAlignY1')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'align y')
//         .addCustomValue('icon', Icons.percent)
//         .addCustomValue('min', -100)
//         .addCustomValue('max', 100);
//     loader2.addAttr(attr);

//     attr = CoreDataAttribut('bgColor2')
//         .init(CDAttributType.one,
//             tName: CWSelectorType.color.name, aLabel: 'color 2')
//         .addCustomValue('icon', Icons.format_color_fill);
//     loader2.addAttr(attr);

//     attr = CoreDataAttribut('gEnter2')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'enter in %')
//         .addCustomValue('icon', Icons.percent)
//         .addCustomValue('min', 0)
//         .addCustomValue('max', 100);
//     loader2.addAttr(attr);

//     attr = CoreDataAttribut('gAlignX2')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'align x')
//         .addCustomValue('icon', Icons.percent)
//         .addCustomValue('min', -100)
//         .addCustomValue('max', 100);
//     loader2.addAttr(attr);
//     attr = CoreDataAttribut('gAlignY2')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'align y')
//         .addCustomValue('icon', Icons.percent)
//         .addCustomValue('min', -100)
//         .addCustomValue('max', 100);
//     loader2.addAttr(attr);

//     //-----------------------------------------------------

//     var tab = WidgetTab(heightContent: true, heightTab: 40, listTab: const [
//       Tab(text: 'Background'),
//       Tab(text: 'Gradient'),
//     ], listTabCont: [
//       loader.getWidget('root', 'root', prepareChange: false),
//       loader2.getWidget('root', 'root', prepareChange: false),
//     ]);

//     listStyle.add(tab);
//   }
