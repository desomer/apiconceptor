import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jsonschema/feature/api/pan_api_call.dart';

class PanApiResponseStatus extends StatefulWidget {
  const PanApiResponseStatus({super.key, required this.stateResponse});

  final WidgetApiCallState stateResponse;

  @override
  State<PanApiResponseStatus> createState() => _PanApiResponseStatusState();
}

class _PanApiResponseStatusState extends State<PanApiResponseStatus> {
  @override
  Widget build(BuildContext context) {
    if (!widget.stateResponse.callInProgress &&
        widget.stateResponse.aResponse == null) {
      return Container();
    }

    if (widget.stateResponse.callInProgress) {
      return Row( spacing: 10,
        children: [
          Chip(label: Text('In progress')),
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
        ],
      );
    }

    var aResponse = widget.stateResponse.aResponse;
    var httpState = aResponse?.reponse?.statusCode??500;
    var duration = aResponse?.duration;
    var size = aResponse?.size ?? 0;

    var colorHttp = Colors.green;
    if (httpState>299) {
      colorHttp = Colors.yellow;
    } 
    if (httpState>399) {
      colorHttp = Colors.orange;
    }   
    if (httpState>499) {
      colorHttp = Colors.red;
    }             

    return Row(
      spacing: 10,
      children: [
        Chip(
          label: Text('$httpState ${aResponse?.reponse?.statusMessage ?? ''}'),
          color: WidgetStatePropertyAll(colorHttp),
        ),
        Text('$duration ms'),
        Chip(label: Text('${aResponse?.contentType}')),
        Text(getFileSizeString(bytes: size, decimals: 2)),
      ],
    );
  }

  static String getFileSizeString({required int bytes, int decimals = 0}) {
    const suffixes = ["b", "kb", "mb", "gb", "tb"];
    if (bytes == 0) return '0 ${suffixes[0]}';
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
