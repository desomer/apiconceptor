import 'package:event_listener/event_listener.dart';
import 'package:event_listener/exceptions.dart';
import 'package:flutter/scheduler.dart';

Function(dynamic) on(CDDesignEvent event, Function(dynamic) fct) {
  _eventListener.on(event.toString(), fct);
  return fct;
}

void emit(CDDesignEvent event, dynamic payload) {
  try {
    _eventListener.emit(event.toString(), payload);
  } on NoListener catch (e) {
    print('no listener $event  $e');
  }
}

void emitLater(
  CDDesignEvent event,
  dynamic payload, {
  int waitFrame = 3,
  bool multiple = false,
}) {
  if (waitFrame <= 0) {
    emit(event, payload);
  } else {
    if (multiple) emit(event, payload);
    //Future.delayed( Duration(milliseconds: 100), () {
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      emitLater(event, payload, waitFrame: waitFrame - 1);
    });
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
