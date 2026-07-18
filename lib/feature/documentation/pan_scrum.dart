import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/api/widget_api_helper.dart';
import 'package:jsonschema/feature/documentation/documentation_options.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:markdown_widget/markdown_widget.dart';

enum ScrumModeEnum { model, api }

class PanScrumModel extends StatefulWidget {
  const PanScrumModel({super.key, required this.mode, this.requestHelper});
  final ScrumModeEnum mode;
  final WidgetAPIHelper? requestHelper;
  @override
  State<PanScrumModel> createState() => _PanScrumModelState();
}

class _PanScrumModelState extends State<PanScrumModel> {
  DocumentationInfo info = DocumentationInfo();
  bool apiIsLoading = false;

  Future<WidgetAPIHelper> initAPI() async {
    var apiCallInfo = widget.requestHelper!.apiCallInfo;

    if (apiCallInfo.currentAPIRequest != null &&
        apiCallInfo.currentAPIResponse != null &&
        apiCallInfo.responseSchema != null) {
      apiIsLoading = true;
      return widget.requestHelper!;
    }

    info.showExampleAvro = false;
    info.showExampleDto = false;
    info.showExampleMongoose = false;

    var future1 = ApiRequestNavigator().getApiRequestModel(
      apiCallInfo,
      currentCompany.listAPI!.namespace!,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    var future2 = ApiRequestNavigator().getApiResponseModel(
      apiCallInfo,
      currentCompany.listAPI!.namespace!,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    var apiRequest = await future1;
    var apiResponse = await future2;

    apiCallInfo.responseSchema = await apiResponse.getSubSchema(subNode: 200);
    apiCallInfo.currentAPIRequest = apiRequest;
    apiCallInfo.currentAPIResponse = apiResponse;
    apiCallInfo.responseSchema?.headerName = 'Response 200';
    apiIsLoading = true;

    return widget.requestHelper!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == ScrumModeEnum.api) {
      if (apiIsLoading) {
        return getWidgetToDisplay(
          DocumentationOptions(
            context: context,
            info: info,
          ).getAPIDocumentation(widget.requestHelper),
        );
      }

      return FutureBuilder(
        future: initAPI(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Text('Erreur : ${snapshot.error}');
          }

          return getWidgetToDisplay(
            DocumentationOptions(
              context: context,
              info: info,
            ).getAPIDocumentation(widget.requestHelper),
          );
        },
      );
    } else {
      if (currentCompany.currentModel == null) {
        return Text('select model first');
      }
      return getWidgetToDisplay(
        DocumentationOptions(
          info: info,
          context: context,
        ).getModelDocumentation(),
      );
    }
  }

  Column getWidgetToDisplay(String md) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: !info.full,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                setState(() {
                  info.full = !(value ?? true);
                });
              },
            ),
            const Text('dense markdown table'),
            const SizedBox(width: 20),
            Checkbox(
              value: info.showExampleDto,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                setState(() {
                  info.showExampleDto = value ?? true;
                });
              },
            ),
            const Text('Show DTO example'),
            const SizedBox(width: 20),
            Checkbox(
              value: info.showExampleMongoose,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                setState(() {
                  info.showExampleMongoose = value ?? true;
                });
              },
            ),
            const Text('Show Mongoose example'),
            const SizedBox(width: 20),
            Checkbox(
              value: info.showExampleAvro,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                setState(() {
                  info.showExampleAvro = value ?? true;
                });
              },
            ),
            const Text('Show Avro example'),
          ],
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: md.toString()));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('copied to clipboard')));
          },
          label: Text('Generate User story in clipboard'),
        ),
        Expanded(
          child: MarkdownWidget(
            data: md.toString(),
            config: MarkdownConfig.darkConfig,
          ),
        ),
      ],
    );
  }
}


