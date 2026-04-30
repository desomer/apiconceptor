import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_version_state.dart';

class PanModelVersionList extends StatefulWidget {
  const PanModelVersionList({
    super.key,
    required this.schema,
    required this.onTap,
    required this.modelParent,
  });
  final ModelSchema schema;
  final ModelSchema modelParent;
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
    GlobalKey keyMore = GlobalKey();
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
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: keyMore,
                onTap: () {
                  openVersionAction(
                    context,
                    keyMore,
                    index,
                    widget.schema.versions!,
                  );
                },
                child: Icon(Icons.more_vert),
              ),
            ),
            Spacer(),
            InkWell(
              child: WidgetVersionState(
                margeVertical: 5,
                model: widget.schema,
                version: version,
                modelParent: widget.modelParent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void openVersionAction(
    BuildContext context,
    GlobalKey<State<StatefulWidget>> k,
    int index,
    List<ModelVersion> versions,
  ) {
    BuildContext? bCtx;
    List<Widget> listWidget = [
      ListTile(
        leading: Icon(Icons.edit),
        title: Text('Edit version'),
        onTap: () {
          if (bCtx != null) Navigator.pop(bCtx!);
        },
      ),
    ];

    if (index == 0 && versions.length > 1) {
      listWidget.add(
        ListTile(
          leading: Icon(Icons.delete),
          title: Text('Delete version'),
          onTap: () {
            if (bCtx != null) Navigator.pop(bCtx!);
            // widget.schema.versions!.removeAt(index);
            setState(() {});
          },
        ),
      );
    }

    dialogBuilderBelow(
      context,
      SizedBox(width: 110, height: 220, child: Column(children: listWidget)),
      k,
      Offset(-40, -20),
      (BuildContext ctx) {
        bCtx = ctx;
      },
    );
  }
}
