import 'package:flutter/material.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/core/api/widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_param.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_split.dart';

class WidgetApiCall extends StatefulWidget {
  const WidgetApiCall({
    super.key,
    required this.requestHelper,
    required this.idApi,
  });
  final WidgetRequestHelper requestHelper;
  final String idApi;

  @override
  State<WidgetApiCall> createState() => WidgetApiCallState();
}

class WidgetApiCallState extends State<WidgetApiCall> {
  @override
  initState() {
    super.initState();
  }

  Widget getLeftPan(BuildContext ctx) {
    return PanApiParam(
      config: ApiParamConfig(
        action: widget.requestHelper.getBtnExecuteCall(),
        modeSeparator: Separator.right,
        withBtnAddMock: true,
        modeMock: true,
      ),
      requestHelper: widget.requestHelper,
    );
  }

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(ChangeTag.apiparam, "WidgetApiCallState", this, () {
      // Future.delayed(Duration(milliseconds: 500)).then((_) {
      //   textConfigBody!.repaintYaml();
      //   keyBtnSave.currentState?.setState(() {});
      // });

      GoTo()
          .getApiRequestModel(
            widget.requestHelper.apiCallInfo,
            currentCompany.listAPI!.namespace!,
            widget.idApi,
            withDelay: false,
          )
          .then((value) {
            widget.requestHelper.apiCallInfo.currentAPIRequest = value;
          });

      GoTo()
          .getApiResponseModel(
            widget.requestHelper.apiCallInfo,
            currentCompany.listAPI!.namespace!,
            widget.idApi,
            withDelay: false,
          )
          .then((value) {
            widget.requestHelper.apiCallInfo.currentAPIResponse = value;
          });

      return false;
    });

    return SplitView(
      primaryWidth: -1,
      children: [
        getLeftPan(context),
        widget.requestHelper.getPanResponse(context),
      ],
    );
  }
}
