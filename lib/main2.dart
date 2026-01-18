// main d'un ecran simple
import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table_layout.dart';

void main(List<String> args) {
  //debugPaintSizeEnabled = true;
  //debugPaintBaselinesEnabled = true;
  //debugPaintPointersEnabled = true;
  runApp(MaterialApp(home: Scaffold(body: NewWidget())));
}

class NewWidget extends StatefulWidget {
  const NewWidget({super.key});

  @override
  State<NewWidget> createState() => _NewWidgetState();
}

class _NewWidgetState extends State<NewWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Frozen Table View Example'),
        Expanded(
          child: FrozenTableView(
            rowWidthBorderL: 0,
            rowWidthBorderR: 0,
            rowCountTop: 1,
            rowCount: 5,
            rowCountBottom: 1,
            colFreezeLeftCount: 3,
            colCount: 20,
            buildTopCell: (row, col) => HeaderCell("R$row Col $col"),
            buildBottomCell: (row, col) => FooterCell("R$row Sum $col"),
            buildLeftCell: (row, col) => LeftCell("R $row Col $col"),
            buildBodyCell: (row, col) => BodyCell("R$row C$col"),
            getColWidth: (int col) {
              if (col == 2 || col % 3 == 0) {
                return 200;
              }
              return 120;
            },
            getRowHeight: (int row) {
              //return null;

              if (row == 1) {
                return 20;
              }

              if (row == 1 || row % 4 == 0) {
                return 80;
              }
              return 50;
            },
            buildRow: (int row, bool isStartCols, Widget child) {
              return child;
            },
          ),
        ),
      ],
    );
  }
}

class LeftCell extends StatelessWidget {
  final String text;
  const LeftCell(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.orange,
      width: 100,
      //height: 50,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class FooterCell extends StatelessWidget {
  final String text;
  const FooterCell(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.green,
      width: 120,
      //height: 50,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class BodyCell extends StatelessWidget {
  final String text;
  const BodyCell(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: 120,
      //height: 50,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
      child: Text(text),
    );
  }
}

class HeaderCell extends StatelessWidget {
  final String text;
  const HeaderCell(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.blue,
      width: 120,
      //height: 50,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
