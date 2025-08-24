import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

abstract mixin class CoreEventListener {
  void onLog(Log log) {}

  void onDelay(Delay delay) {}

  void onRequest(TrackerInfo connection) {}

  void onLoaded(String providerName) {}
}

class CoreEventManager {
  final controller = StreamController<Map<String, Object?>>();

  CoreEventManager._() {
    controller.stream.listen((message) {
      if (message.isEmpty) {
        return;
      }
      final m = CoreEvent.fromJson(message);
      for (final CoreEventListener listener in _listeners) {
        switch (m.type) {
          case CoreEventType.log:
            listener.onLog(Log.fromJson(m.data));
            break;
          case CoreEventType.delay:
            listener.onDelay(Delay.fromJson(m.data));
            break;
          case CoreEventType.request:
            listener.onRequest(TrackerInfo.fromJson(m.data));
            break;
          case CoreEventType.loaded:
            listener.onLoaded(m.data);
            break;
        }
      }
    });
  }

  static final CoreEventManager instance = CoreEventManager._();

  final ObserverList<CoreEventListener> _listeners =
      ObserverList<CoreEventListener>();

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(CoreEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CoreEventListener listener) {
    _listeners.remove(listener);
  }
}

final coreEventManager = CoreEventManager.instance;
