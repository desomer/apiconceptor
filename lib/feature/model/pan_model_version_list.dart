import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_version_state.dart';

class PanModelVersionList extends StatefulWidget {
  const PanModelVersionList({
    super.key,
    required this.schema,
    required this.onTap,
  });
  final ModelSchema schema;
  final Function onTap;

  @override
  State<PanModelVersionList> createState() => _PanModelVersionListState();
}

class _PanModelVersionListState extends State<PanModelVersionList>
    with WidgetHelper {
  late ScrollController _scrollController;

  @override
  void initState() {
    _scrollController = ScrollController();
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: getArrayVersion(),
      ),
    );
  }

  Widget getArrayVersion() {
    return ListView.builder(
      shrinkWrap: true,
      itemExtent: 35,
      itemCount: widget.schema.versions?.length ?? 0,
      itemBuilder: (context, index) {
        return getRow(index);
      },
    );
  }

  Widget getRow(int index) {
    ModelVersion version = widget.schema.versions![index];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
      ),
      child: InkWell(
        onTap: () {
          widget.onTap(version);
        },
        child: Row(
          spacing: 5,
          children: [
            Text('draft'),
            getChip(Text(version.data['versionTxt']), color: null),
            Text('by ${version.data['by']}'),
            Spacer(),
            InkWell(child: WidgetVersionState(margeVertical: 5,model: widget.schema, version: version)),
          ],
        ),
      ),
    );
  }
}
