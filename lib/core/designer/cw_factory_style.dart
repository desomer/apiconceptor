import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/core/designer/cw_widget_factory.dart';

class CWFactoryStyle {
  List<CwWidgetProperties> initMargin(CwWidgetCtx ctx) {
    List<CwWidgetProperties> listStyle = [];
    listStyle.add(
      CwWidgetProperties(id: 'mtop', name: 'margin top')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.expand_less,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'mbottom', name: 'margin bottom')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.expand_more,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'mleft', name: 'margin left')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.chevron_left,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'mright', name: 'margin right')..isSlider(
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
      CwWidgetProperties(id: 'ptop', name: 'padding top')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.arrow_upward_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'pbottom', name: 'padding bottom')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.arrow_downward_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'pleft', name: 'padding left')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.west_rounded,
        path: [cwStyle],
      ),
    );
    listStyle.add(
      CwWidgetProperties(id: 'pright', name: 'padding right')..isSlider(
        ctx,
        min: 0,
        max: 50,
        icon: Icons.east_rounded,
        path: [cwStyle],
      ),
    );
    return listStyle;
  }
}

//   void initBorder(CWWidgetCtx ctx, CWRepository provider) {
//     CWAppLoaderCtx ctxLoader = CWAppLoaderCtx().from(ctx.loader);
//     ctxLoader.addRepository(provider, isEntity: false);

//     AttrFormLoader loader = AttrFormLoader(
//         'rootBody0', ctxLoader, 'Border & Elevation', provider,
//         config: FormConfig(typeForm: ModeForm.expand, isEntity: false)
//           ..isRoot = true);

//     CoreDataAttribut attr = CoreDataAttribut('elevation')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'elevation')
//         .addCustomValue('icon', Icons.copy_all_rounded)
//         .addCustomValue('min', 0)
//         .addCustomValue('max', 20);
//     loader.addAttr(attr);

//     attr = CoreDataAttribut('bSize')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'border size')
//         .addCustomValue('icon', Icons.highlight_alt_rounded)
//         .addCustomValue('min', 0)
//         .addCustomValue('max', 20);
//     loader.addAttr(attr);

//     attr = CoreDataAttribut('bRadius')
//         .init(CDAttributType.int,
//             tName: CWSelectorType.slider.name, aLabel: 'b. radius')
//         .addCustomValue('icon', Icons.panorama_wide_angle_rounded)
//         .addCustomValue('min', 0)
//         .addCustomValue('max', 50);
//     loader.addAttr(attr);

//     attr = CoreDataAttribut('bColor')
//         .init(CDAttributType.one,
//             tName: CWSelectorType.color.name, aLabel: 'border color')
//         .addCustomValue('icon', Icons.border_color_rounded);
//     loader.addAttr(attr);

//     listStyle.add(loader.getWidget('root', 'root', prepareChange: false));
//   }

//   void initAlignment(CWWidgetCtx ctx, CWRepository provider) {
//     CWAppLoaderCtx ctxLoader = CWAppLoaderCtx().from(ctx.loader);
//     ctxLoader.addRepository(provider, isEntity: false);

//     AttrFormLoader loader = AttrFormLoader(
//         'rootBody0', ctxLoader, 'Alignment', provider,
//         config: FormConfig(typeForm: ModeForm.expand, isEntity: false)
//           ..isRoot = true);

//     List listAxis = [
//       {'icon': Icons.align_vertical_top, 'value': -1},
//       {'icon': Icons.align_vertical_center, 'value': 0},
//       {'icon': Icons.align_vertical_bottom, 'value': 1},
//     ];

//     List listCross = [
//       {'icon': Icons.align_horizontal_left, 'value': -1},
//       {'icon': Icons.align_horizontal_center, 'value': 0},
//       {'icon': Icons.align_horizontal_right, 'value': 1},
//     ];

//     CoreDataAttribut attr = CoreDataAttribut('boxAlignVertical')
//         .init(CDAttributType.text, tName: 'toogle', aLabel: 'Box align H.')
//         .addCustomValue('bindValue', listAxis);
//     loader.addAttr(attr);
//     attr = CoreDataAttribut('boxAlignHorizontal')
//         .init(CDAttributType.text, tName: 'toogle', aLabel: 'Box align V.')
//         .addCustomValue('bindValue', listCross);
//     loader.addAttr(attr);

//     listStyle.add(loader.getWidget('root', 'root', prepareChange: false));
//   }

//   void initBackground(CWWidgetCtx ctx, CWRepository provider) {
//     CWAppLoaderCtx ctxLoader = CWAppLoaderCtx().from(ctx.loader);
//     ctxLoader.addRepository(provider, isEntity: false);

//     AttrFormLoader loader = AttrFormLoader(
//         'rootBody0', ctxLoader, 'Background', provider,
//         config: FormConfig(typeForm: ModeForm.expand, isEntity: false)
//           ..isRoot = true);

//     CoreDataAttribut attr = CoreDataAttribut('bgColor')
//         .init(CDAttributType.one,
//             tName: CWSelectorType.color.name, aLabel: 'bg color')
//         .addCustomValue('icon', Icons.format_color_fill);
//     loader.addAttr(attr);

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

//   void initText(CWWidgetCtx ctx, CWRepository provider) {
//     CWAppLoaderCtx ctxLoader = CWAppLoaderCtx().from(ctx.loader);
//     ctxLoader.addRepository(provider, isEntity: false);

//     AttrFormLoader loader = AttrFormLoader(
//         'rootBody0', ctxLoader, 'Text', provider,
//         config: FormConfig(typeForm: ModeForm.expand, isEntity: false)
//           ..isRoot = true);

//     List listCross = [
//       {'icon': Icons.align_horizontal_left, 'value': 'start'},
//       {'icon': Icons.align_horizontal_center, 'value': 'center'},
//       {'icon': Icons.align_horizontal_right, 'value': 'end'},
//     ];

//     CoreDataAttribut attr = CoreDataAttribut('textalign')
//         .init(CDAttributType.text, tName: 'toogle', aLabel: 'text align')
//         .addCustomValue('bindValue', listCross);
//     loader.addAttr(attr);

//     attr = CoreDataAttribut('tColor')
//         .init(CDAttributType.one,
//             tName: CWSelectorType.color.name, aLabel: 'text color')
//         .addCustomValue('icon', Icons.format_color_text_rounded);
//     loader.addAttr(attr);

//     attr =
//         CoreDataAttribut('tSize').init(CDAttributType.int, aLabel: 'text size');
//     loader.addAttr(attr);

//     List listTextType = [
//       {'icon': Icons.format_bold, 'value': 'bold'},
//       {'icon': Icons.format_italic, 'value': 'italic'},
//       {'icon': Icons.format_underline, 'value': 'underline'},
//       {'icon': Icons.format_strikethrough, 'value': 'lineThrough'},
//       {'icon': Icons.format_overline, 'value': 'overline'},
//     ];
//     attr = CoreDataAttribut('textstyle')
//         .init(CDAttributType.text, tName: 'toogle', aLabel: 'text style')
//         .addCustomValue('bindValue', listTextType)
//         .addCustomValue('multiple', true);
//     loader.addAttr(attr);

//     listStyle.add(loader.getWidget('root', 'root', prepareChange: false));

//     // Text('\$8.99',
//     //     style: TextStyle(
//     //         color: Colors.grey[800],
//     //         fontWeight: FontWeight.bold,
//     //         fontStyle: FontStyle.italic,
//     //         fontSize: 40,
//     //         decoration: TextDecoration.lineThrough));
//   }
// }
