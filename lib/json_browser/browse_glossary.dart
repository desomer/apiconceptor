import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/main.dart';
import 'package:lemmatizerx/lemmatizerx.dart';
//import 'package:text_analysis/text_analysis.dart';
//import 'package:text_analysis/extensions.dart';

List<String> autorizedGlossaryType = [
  'fact',
  'dim',
  'enum',
  'value',
  'bool',
  'prefix',
  'suffix',
  'everywhere',
];

class BrowseGlossary<T extends Map> extends JsonBrowser<T> {
  @override
  void doTree(ModelSchema model, NodeAttribut aNodeAttribut, r) {
    if (autorizedGlossaryType.contains(aNodeAttribut.info.type)) {
      initVersion(aNodeAttribut, r);
    }
    super.doTree(model, aNodeAttribut, r);
  }

  @override
  T? getRoot(NodeAttribut node) {
    return {} as T;
  }

  @override
  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    return parent;
  }

  void initVersion(NodeAttribut aNodeAttribut, r) {
    //print(aNodeAttribut.info.name);
    currentCompany.glossaryManager.add(aNodeAttribut);
  }
}

class StackElem<T> {
  List items;
  StackElem(this.items);
  @override
  String toString() => 'List :$items';

  void push(T item) {
    this.items.add(item);
  }

  T pull() {
    return this.items.removeLast();
  }

  bool isEmpty() {
    if (this.items == []) {
      return true;
    } else {
      return false;
    }
  }
}

class GlossaryManager {
  Map<String, NodeAttribut> dico = {};
  Lemmatizer lemmatizer = Lemmatizer();

  StackElem<AttributInfo> stack = StackElem([]);

  void add(NodeAttribut aNodeAttribut) {
    dico[aNodeAttribut.info.name.toLowerCase()] = aNodeAttribut;
  }

  final RegExp syllableRegex = RegExp(
    r'((^[a-z]+)|([0-9]+)|([A-Z]{1}[a-z]+)|([A-Z]+(?=([A-Z][a-z])|($)|([0-9]))))',
    caseSensitive: true,
  );

  Future<GlossaryInfo> isValid(AttributInfo attr) async {
    stack.push(attr);
    await Future.delayed(Duration(milliseconds: stack.items.length * 20));
    stack.pull();
    var ret = GlossaryInfo();

    var text = attr.name;
    //print(text);

    if (text == constRefOn) {
      // gestion des $ref
      text = attr.properties?[constRefOn] ?? '';
    }
    if (text == '') {
      ret.unexistWord ??= [];
      ret.unexistWord!.add('');
      return ret;
    }

    for (Match match in syllableRegex.allMatches(text)) {
      var word = match.group(0)!.toLowerCase();
      var validWord = dico[word];
      if (validWord == null) {
        List<Lemma> lemmas = lemmatizer.lemmas(word);
        if (lemmas.isEmpty) {
          //print('>$word<');
          ret.unexistWord ??= [];
          ret.unexistWord!.add(word);
        }
        //print(lemmas);
        for (var element in lemmas) {
          for (var w in element.lemmas) {
            validWord = dico[w];
            if (validWord != null) {
              ret.validWord ??= [];
              ret.validWord!.add(w);
              break;
            }
          }
          if (validWord != null) break;
        }

        if (validWord == null) {
          ret.existWord ??= [];
          ret.existWord!.add(word);
        }
      } else {
        ret.validWord ??= [];
        ret.validWord!.add(word);
      }
    }

    // final readabilityExample =
    //     'The Australian platypus is seemingly a hybrid of a mammal and reptilian creature.';

    // final tokens = await English.analyzer.tokenizer(readabilityExample);
    // print(tokens);

    // // hydrate the TextDocument
    // final textDoc = await TextDocument.analyze(
    //   sourceText: readabilityExample,
    //   analyzer: English.analyzer,
    //   nGramRange: NGramRange(1, 3),
    // );

    // // print the `Flesch reading ease score`
    // print(
    //   'Flesch Reading Ease: ${textDoc.fleschReadingEaseScore().toStringAsFixed(1)}',
    // );

    //similarityExamples('boredr', candidates);

    return ret;
  }

  // void similarityExamples(String term, Iterable<String> candidates) {
  //   // iterate over candidates
  //   for (final other in candidates) {
  //     //
  //     // print the terms
  //     print('($term: $other)');

  //     // print the editDistance
  //     print(
  //       '- Edit Distance:       ${term.editDistance(other).toStringAsFixed(3)}',
  //     );
  //     // print the lengthDistance
  //     print(
  //       '- Length Distance:     ${term.lengthDistance(other).toStringAsFixed(3)}',
  //     );
  //     // print the lengthSimilarity
  //     print(
  //       '- Length Similarity:   ${term.lengthSimilarity(other).toStringAsFixed(3)}',
  //     );
  //     // print the jaccardSimilarity
  //     print(
  //       '- Jaccard Similarity:  ${term.jaccardSimilarity(other).toStringAsFixed(3)}',
  //     );
  //     // print the editSimilarity
  //     print(
  //       '- Edit Similarity:     ${term.editSimilarity(other).toStringAsFixed(3)}',
  //     );
  //     // print the characterSimilarity
  //     print(
  //       '- Character Similarity:     ${term.characterSimilarity(other).toStringAsFixed(3)}',
  //     );
  //     // print the termSimilarity
  //     // print(
  //     //     '- String Similarity:     ${term.termSimilarity(other).toStringAsFixed(3)}');
  //   }

  //   // get a list of the terms orderd by descending similarity
  //   // final matches = term.matches(candidates);
  //   // print('Ranked matches: $matches');
  // }

  // final candidates = [
  //   'bodrer',
  //   'bord',
  //   'board',
  //   'broad',
  //   'boarder',
  //   'border',
  //   'brother',
  //   'bored',
  // ];
}

class GlossaryInfo {
  bool isValid = false;
  bool isPartial = false;
  List<String>? unexistWord;
  List<String>? existWord;
  List<String>? validWord;
}

//************************************************************************* */
class InfoManagerGlossary extends InfoManager {
  InfoManagerGlossary();

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      if (name.startsWith(constRefOn)) {
        typeStr = '\$ref';
      } else if (name.startsWith(constTypeAnyof)) {
        typeStr = '\$anyOf';
      } else if (name.endsWith('[]')) {
        node.bgcolor = Colors.blue.withAlpha(50);
        typeStr = 'Array';
      } else {
        node.bgcolor = Colors.blueGrey.withAlpha(50);
        typeStr = 'Category';
      }
    } else if (type is List) {
      if (name.endsWith('[]')) {
        typeStr = 'Array';
        node.bgcolor = Colors.blue.withAlpha(50);
      } else {
        typeStr = 'Object';
      }
    } else if (type is int) {
      typeStr = 'number';
    } else if (type is double) {
      typeStr = 'number';
    } else if (type is String) {
      if (type.startsWith('\$')) {
        typeStr = 'Object';
      }
    }
    typeStr ??= '$type';
    return typeStr;
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    var type = typeTitle.toLowerCase();
    bool valid = [
      'category',
      ...autorizedGlossaryType,
      '\$ref',
      '\$anyof',
    ].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getAttributHeader(TreeNode<NodeAttribut> node) {
    Widget icon = Container();
    var isRoot = node.isRoot;
    var isObject = node.data!.info.type == 'Object';
    var isOneOf = node.data!.info.type == '\$anyOf';
    var isRef = node.data!.info.type == '\$ref';
    var isArray = node.data!.info.type == 'Array';
    String name = node.data?.yamlNode.key;

    if (isRoot && name == 'Business model') {
      icon = Icon(Icons.business);
    } else if (isRoot) {
      icon = Icon(Icons.lan_outlined);
    } else if (isObject) {
      icon = Icon(Icons.data_object);
    } else if (isRef) {
      icon = Icon(Icons.link);
      name = '\$${node.data?.info.properties?[constRefOn] ?? '?'}';
    } else if (isOneOf) {
      name = '\$anyOf';
      icon = Icon(Icons.looks_one_rounded);
    } else if (isArray) {
      icon = Icon(Icons.data_array);
    }

    return IntrinsicWidth(
      //width: 180,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
              child: icon,
            ),
            Text(
              name,
              style:
                  (isObject || isArray)
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
