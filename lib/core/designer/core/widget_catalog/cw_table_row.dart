import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwRow {
  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'row',
      config: (ctx) {
        return CwWidgetConfig().addProp(
          CwWidgetProperties(id: 'height', name: 'height')
            ..isSlider(ctx, min: 0, max: 100),
        );
      },
    );
  }
}
