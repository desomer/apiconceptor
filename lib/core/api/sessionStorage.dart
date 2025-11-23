import 'package:jsonschema/core/util.dart';

LruCache sessionStorage = LruCache(5);

class PageData {
  PageData({required this.data, required this.path});
  dynamic data;
  String path;

  dynamic findNearestValueByKey(String key) {
    Map<String, dynamic> currentRow = getValueFromPath(data, path);
    var val = findValueByKey(currentRow, key);
    if (val == null) {
      var pathParent = getParentPath(path);
      while (val == null && pathParent != null) {
        currentRow = getValueFromPath(data, pathParent);
        val = findValueByKey(currentRow, key);
        pathParent = getParentPath(pathParent);
      }
    }
    return val;
  }

  String? getParentPath(String path) {
    final index = path.lastIndexOf('/');
    if (index == -1) return null; // pas de parent
    return path.substring(0, index);
  }
}