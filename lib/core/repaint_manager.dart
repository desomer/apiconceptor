import 'package:flutter/material.dart';

RepaintManager repaintManager = RepaintManager();

enum ChangeTag { showListModel, showListApi, apichange, apiparam }

class RepaintManager {
  Map<ChangeTag, DicoTagRepaint> tags = {};
  void addTag(ChangeTag id, String idWidget, State? state, Function isChanged) {
    DicoTagRepaint? dico = tags[id];
    if (dico == null) {
      dico = DicoTagRepaint(id: id);
      tags[id] = dico;
    }
    dico.states[idWidget] = TagRepaint(
      idWidget: idWidget,
      state: state,
      isChanged: isChanged,
    );
  }

  void doRepaint(ChangeTag id) {
    print("************** repaint $id **********");
    if (tags[id] == null) return;
    for (var element in tags[id]!.states.entries) {
      bool change = element.value.isChanged();
      if (change) {
        if (element.value.state?.mounted ?? false) {
          // ignore: invalid_use_of_protected_member
          element.value.state!.setState(() {});
        }
      }
    }
  }
}

class DicoTagRepaint {
  final ChangeTag id;
  Map<String, TagRepaint> states = {};

  DicoTagRepaint({required this.id});
}

class TagRepaint {
  final String idWidget;
  final State? state;
  final Function isChanged;

  TagRepaint({
    required this.idWidget,
    required this.state,
    required this.isChanged,
  });
}
