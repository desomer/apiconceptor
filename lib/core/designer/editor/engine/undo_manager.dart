class UndoAction {
  Function doAction;
  Function undoAction;

  UndoAction({required this.doAction, required this.undoAction});
}

UndoManager globalUndoManager = UndoManager();

class UndoManager {
  List<UndoAction> undoStack = [];
  List<UndoAction> redoStack = [];

  void execute(UndoAction action) {
    action.doAction();
    undoStack.add(action);
    redoStack.clear();
  }

  void undo() {
    if (undoStack.isNotEmpty) {
      var action = undoStack.removeLast();
      action.undoAction();
      redoStack.add(action);
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      var action = redoStack.removeLast();
      action.doAction();
      undoStack.add(action);
    }
  }
}
