import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class BrowseAPI<T extends Map> extends JsonBrowser<T> {
  @override
  void doTree(NodeAttribut aNodeAttribut, r) {
    if (aNodeAttribut.info.type == 'api') {
      initVersion(aNodeAttribut, r);
    }
    super.doTree(aNodeAttribut, r);
  }

  @override
  T? getRoot(NodeAttribut node) {
    return {} as T;
  }

  @override
  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    return {};
  }

  void initVersion(NodeAttribut aNodeAttribut, r) {
    print(aNodeAttribut.info.name);
  }
}

//************************************************************************* */
class InfoManagerAPI extends InfoManager with WidgetModelHelper {
  @override
  String getTypeTitle(String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      typeStr = 'Path';
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
    if (child.info.name == '\$url') {
      // affecte l'url sur le parent
      parent!.info.properties!['\$url'] = child.info.type;
    }
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    var type = typeTitle.toLowerCase();
    bool valid = ['path', 'server', 'api'].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getAttributHeader(TreeNode<NodeAttribut> node) {
    Widget icon = Container();
    var isRoot = node.isRoot;
    var type = node.data!.info.type;
    var isPath = type == 'Path';
    String name = node.data!.yamlNode.key.toString().toLowerCase();

    if (isRoot && name == 'api') {
      icon = Icon(Icons.business);
    } else if (isPath) {
      if (node.data!.info.properties!['\$url'] != null) {
        icon = Icon(Icons.dns_outlined);
      } else {
        icon = Icon(Icons.lan_outlined);
      }
    } else if (name == ('\$url')) {
      icon = Icon(Icons.http_outlined);
      name = 'URL';
    }

    bool isAPI = node.data!.info.type == 'api';
    late Widget w;
    if (name == 'get') {
      w = getChip(Text('GET'), color: Colors.green, height: 27);
    } else if (name == 'post') {
      w = getChip(
        Text('POST', style: TextStyle(color: Colors.black)),
        color: Colors.yellow,
        height: 27,
      );
    } else if (name == 'put') {
      w = getChip(Text('PUT'), color: Colors.blue, height: 27);
    } else if (name == 'delete') {
      w = getChip(
        Text('DELETE', style: TextStyle(color: Colors.black)),
        color: Colors.redAccent.shade100,
        height: 27,
      );
    } else {
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
      var n = nd.yamlNode.key.toString().toLowerCase();
      var isServer = nd.info.properties?['\$url'];
      if (isServer != null) {
        n = '<$isServer>';
      }
      if (!n.endsWith('/') && !bufPath.startsWith('/')) sep = '/';
      bufPath = n + sep + bufPath;
      if (nd.info.properties?['\$url'] != null) {
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
}
