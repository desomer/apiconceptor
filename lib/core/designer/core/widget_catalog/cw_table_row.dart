import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwRow {
  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'row',
      config: (ctx) {
        return CwWidgetConfig();
      },
    );
  }
}
