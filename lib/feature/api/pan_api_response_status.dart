import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';

class PanApiResponseStatus extends StatefulWidget {
  const PanApiResponseStatus({super.key, required this.requestHelper});

  final WidgetRequestHelper requestHelper;

  @override
  State<PanApiResponseStatus> createState() => _PanApiResponseStatusState();
}

class _PanApiResponseStatusState extends State<PanApiResponseStatus> {
  @override
  Widget build(BuildContext context) {
    if (!widget.requestHelper.callInProgress &&
        widget.requestHelper.apiCallInfo.aResponse == null) {
      return Container();
    }

    if (widget.requestHelper.callInProgress) {
      return Row(
        spacing: 10,
        children: [
          Chip(label: Text('In progress')),
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
        ],
      );
    }

    var aResponse = widget.requestHelper.apiCallInfo.aResponse;
    var httpState = aResponse?.reponse?.statusCode ?? 500;
    var duration = aResponse?.duration;
    var size = aResponse?.size ?? 0;

    var colorHttp = Colors.green;
    if (httpState > 299) {
      colorHttp = Colors.yellow;
    }
    if (httpState > 399) {
      colorHttp = Colors.orange;
    }
    if (httpState > 499) {
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

}
