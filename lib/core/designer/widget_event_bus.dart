import 'package:event_listener/event_listener.dart';

Function(dynamic) on(CDDesignEvent event, Function(dynamic) fct) {
  _eventListener.on(event.toString(), fct);
  return fct;
}

void emit(CDDesignEvent event, dynamic payload) {
  try {
    _eventListener.emit(event.toString(), payload);
  } catch (e) {
    print('no listener $event');
  }
}

void removeListener(CDDesignEvent event, Function(dynamic) fct) {
  _eventListener.removeEventListener(event.toString(), fct);
}

void removeAllListener(CDDesignEvent event) {
  _eventListener.removeAllListeners(event.toString());
}

final _eventListener = EventListener();

enum CDDesignEvent {
  select,
  reselect,
  preview,
  device,
  savePage,
  clearAll,
  displayProp,
}
