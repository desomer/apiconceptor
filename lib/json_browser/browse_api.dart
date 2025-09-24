import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class BrowseAPI<T extends Map> extends JsonBrowser<T> {
  @override
  void doTree(ModelSchema model, NodeAttribut aNodeAttribut, r) {
    if (aNodeAttribut.info.type == 'ope') {
      initVersion(aNodeAttribut, r);
    }
    super.doTree(model, aNodeAttribut, r);
  }

  @override
  T? getRoot(NodeAttribut node) {
    return {} as T;
  }

  @override
  dynamic getChild(ModelSchema model, NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    return {};
  }

  void initVersion(NodeAttribut aNodeAttribut, r) {
    print(aNodeAttribut.info.name);
  }
}

//************************************************************************* */
class InfoManagerAPI extends InfoManager with WidgetHelper {
  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      if (name == '\$server') {
        typeStr = "{${type.keys.firstOrNull}}";
      }
      // {var} ou param
      else {
        typeStr = node.level == 1 ? 'Service' : 'Path';
        node.info.error = null;
      }
    } else if (type is List) {
      // if (name.endsWith('[]')) {
      //   typeStr = 'Array';
      // } else {
      //   typeStr = 'Object';
      // }
    } else if (type is int) {
      typeStr = '?';
    } else if (type is double) {
      typeStr = '?';
    } else if (type is String) {
      if (type.startsWith('\$')) {
        typeStr = type.substring(1);
      }
    }
    typeStr ??= '$type';
    return typeStr;
  }

  @override
  void onNode(NodeAttribut? parent, NodeAttribut child) {
    if (child.info.name == '\$server') {
      // affecte l'url sur le parent
      parent!.info.properties!['\$server'] = child.info.type;
    }
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    if (name == '\$server') {
      if (nodeAttribut.yamlNode.value is Map) {
        //Map a = nodeAttribut.yamlNode.value;
        return null;
      } else {
        if (!UtilDart().isURL(typeTitle)) {
          return InvalidInfo(color: Colors.red);
        } else {
          return null;
        }
      }
    }
    var typel = typeTitle.toLowerCase();
    bool valid = ['service', 'path', 'server', 'ope', 'graph'].contains(typel);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    Widget icon = Container();
    var isRoot = node.isRoot;
    var type = node.data!.info.type;
    var isPath = type == 'Path';

    var key = getKeyParamFromYaml(node.data!.yamlNode.key);
    String name = key.toLowerCase();

    if (isRoot && name == 'api') {
      icon = Icon(Icons.business);
    } else if (isPath) {
      if (node.data!.info.properties!['\$server'] != null) {
        icon = Icon(Icons.dns_outlined);
      } else {
        icon = Icon(Icons.lan_outlined);
      }
    } else if (name == ('\$server')) {
      icon = Icon(Icons.http_outlined);
      name = 'Server';
    }

    bool isAPI = node.data!.info.type == 'ope';
    Widget? w = getHttpOpe(name);

    if (w == null) {
      List<String> path = name.split('/');
      List<Widget> wpath = [];
      int i = 0;
      for (var element in path) {
        bool isLast = i == path.length - 1;
        if (element.startsWith('{')) {
          String v = element.substring(1, element.length - 1);
          wpath.add(getChip(Text(v), color: null));
          if (!isLast) {
            wpath.add(Text('/'));
          }
        } else {
          wpath.add(Text(element + (!isLast ? '/' : '')));
        }
        i++;
      }
      w = Row(children: wpath);
    }

    String bufPath = '';
    NodeAttribut? nd = node.data!;

    if (isAPI) {
      nd = nd.parent;
    }
    while (nd != null) {
      var sep = '';
      var n = getKeyParamFromYaml(nd.yamlNode.key).toLowerCase();
      var isServer = nd.info.properties?['\$server'];
      if (isServer != null) {
        n = '$isServer';
      }
      if (!n.endsWith('/') && !bufPath.startsWith('/')) sep = '/';
      bufPath = n + sep + bufPath;
      if (nd.info.properties?['\$server'] != null) {
        break;
      }
      nd = nd.parent;
    }
    if (isAPI) {
      bufPath = '[${name.toUpperCase()}] $bufPath';
    }

    return Tooltip(
      message: bufPath.toString(),
      child: IntrinsicWidth(
        //width: 180,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: Row(
            children: [
              Padding(padding: EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),
              w,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node) {
    Widget icon = Container();
    var isRoot = node.isRoot;
    var type = node.data.info.type;
    var isPath = type == 'Path';
    var isService = type == 'Service';

    var key = getKeyParamFromYaml(node.data.yamlNode.key);

    String name = key.toLowerCase();

    if (isRoot) {
      icon = Icon(Icons.business);
    } else if (isService) {
      icon = Icon(Icons.dns_outlined);
    } else if (isPath) {
      if (node.data.info.properties!['\$server'] != null) {
        icon = Icon(Icons.dns_outlined);
      } else {
        icon = Icon(Icons.lan_outlined);
      }
    } else if (name == ('\$server')) {
      icon = Icon(Icons.http_outlined);
      name = 'Server';
    }

    bool isAPI = node.data.info.type == 'ope';
    Widget? header = getHttpOpe(name);

    if (header == null) {
      List<Widget> wpath = getHeaderPath(name, null);
      header = Row(children: wpath);
    }

    String bufPath = getTooltipUrl(node, isAPI, name);

    return Tooltip(
      message: bufPath.toString(),
      child: Row(
        spacing: 5,
        children: [
          icon,
          Expanded(
            child: InkWell(
              onTap: () {
                node.doTapHeader();
              },
              child: Row(
                children: [
                  header,
                  Spacer(),
                  getWidgetType(node.data, isAPI, isRoot),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getTooltipUrl(
    TreeNodeData<NodeAttribut> node,
    bool isAPI,
    String name,
  ) {
    String bufPath = '';
    NodeAttribut? nd = node.data;

    if (isAPI) {
      nd = nd.parent;
    }
    while (nd != null) {
      var sep = '';
      var n = getKeyParamFromYaml(nd.yamlNode.key).toLowerCase();
      var isServer = nd.info.properties?['\$server'];
      if (isServer != null) {
        n = '$isServer';
      }
      if (!n.endsWith('/') && !bufPath.startsWith('/')) sep = '/';
      bufPath = n + sep + bufPath;
      if (nd.info.properties?['\$server'] != null) {
        break;
      }
      nd = nd.parent;
    }
    if (isAPI) {
      bufPath = '[${name.toUpperCase()}] $bufPath';
    }
    return bufPath;
  }

  Widget getWidgetType(NodeAttribut attr, bool isAPI, bool isRoot) {
    if (isRoot) return Container();

    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;
    String msg = hasError ? 'string\nnumber\nboolean\n\$type' : '';

    return Tooltip(
      message: msg,
      child: getChip(
        isAPI
            ? Row(
              spacing: 5,
              children: [
                Text(attr.info.type),
                Icon(Icons.arrow_forward_ios, size: 10),
              ],
            )
            : Text(attr.info.type),
        color: hasError ? Colors.redAccent : (isAPI ? Colors.blue : null),
      ),
    );
  }


}

class InfoManagerTrashAPI extends InfoManager with WidgetHelper {
  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    return getChip(Text(node.data!.info.name), color: null);
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, type) {
    if (type is Map) {
      return node.level == 1 ? 'Service' : 'Path';
    } else {
      return '$type';
    }
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null;
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }
}
