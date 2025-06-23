import 'dart:async';

import 'package:flutter/material.dart';

/// exemple
/// 
// WidgetSearch<String>(
//   hintText: 'search',
//   searchFunction: (query) {
//     Iterable<String> r = [
//       "date-time",
//       "date",
//       "time",
//       "duration",
//       "email",
//       "hostname",
//       "ipv4",
//       "ipv6",
//       "uri",
//       "uuid"
//     ];
//     return Future.value(r);
//   },
// ),


class WidgetSearch<T> extends StatefulWidget {
  const WidgetSearch({
    super.key,
    required this.hintText,
    required this.searchFunction,
    this.onResultSelected,
  });

  final String hintText;
  final Future<Iterable<T>> Function(String query) searchFunction;
  final Function(T result)? onResultSelected;

  @override
  State<WidgetSearch<T>> createState() => _WidgetSearchState();
}

class _WidgetSearchState<T> extends State<WidgetSearch<T>> {
  final _searchController = SearchController();
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;

  Future<Iterable<T>> _search(String query) async {
    // if (query.isEmpty) {
    //   return <T>[];
    // }

    try {
      final results = await widget.searchFunction(query);
      return results;
    } catch (error) {
      return <T>[];
    }
  }

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(_search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          constraints: BoxConstraints(minHeight: 40, maxHeight: 40),
          //overlayColor: WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadiusGeometry.all(Radius.circular(5)),
              side: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
          controller: controller,
          // padding: const WidgetStatePropertyAll<EdgeInsets>(
          //   EdgeInsets.symmetric(horizontal: 16.0),
          // ),
          onTap: () {
            controller.openView();
          },
          leading: const Icon(Icons.search),
          hintText: widget.hintText,
        );
      },
      suggestionsBuilder: (
        BuildContext context,
        SearchController controller,
      ) async {
        final results = await _debouncedSearch(controller.text);
        if (results == null) {
          return <Widget>[];
        }
        return results.map((result) {
          return ListTile(
            title: Text(result.toString()),
            onTap: () {
              widget.onResultSelected?.call(result);
              controller.closeView(controller.text);
            },
          );
        }).toList();
      },
    );
  }
}

/// This is a simplified version of debounced search based on the following example:
/// https://api.flutter.dev/flutter/material/SearchAnchor-class.html#material.SearchAnchor.4
typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer();
    try {
      await debounceTimer!.future;
    } catch (error) {
      print(error); // Should be 'Debounce cancelled' when cancelled.
      return null;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer() {
    _timer = Timer(_duration, _onComplete);
  }

  late final Timer _timer;
  final Duration _duration = const Duration(milliseconds: 500);
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError('Debounce cancelled');
  }
}
