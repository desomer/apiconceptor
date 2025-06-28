import 'package:flutter/material.dart';
import 'package:jsonschema/widget/hexagon/hexagon_widget.dart';

class PanServiceInfo extends StatelessWidget {
  const PanServiceInfo({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 100,
          left: 150,
          child: HexagonWidget.pointy(
            width: 200,
            color: Colors.lightBlue,
            elevation: 8,
            child: Text('Business Domain'),
          ),
        ),
    
        Positioned(
          top: 100,
          left: 100,
          child: Card(
            elevation: 8,
            color: Colors.blue,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Application'),
            ),
          ),
        ),
    
        Positioned(
          top: 60,
          left: 40,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Text('Input API'),
            ),
          ),
        ),
    
        Positioned(
          top: 55,
          left: 150,
          child: Card(
            elevation: 8,
            color: Colors.yellow,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('DTO', style: TextStyle(color: Colors.black)),
            ),
          ),
        ),
    
        Positioned(
          top: 150,
          left: 30,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Input events'),
            ),
          ),
        ),
    
        Positioned(
          top: 130,
          left: 320,
          child: Card(
            elevation: 8,
            color: Colors.orange,
            child: Padding(padding: EdgeInsets.all(20), child: Text('MODELS')),
          ),
        ),
    
        Positioned(
          top: 100,
          left: 380,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Life cycle'),
            ),
          ),
        ),
    
        Positioned(
          top: 180,
          left: 350,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Mapping rule'),
            ),
          ),
        ),
    
        Positioned(
          top: 290,
          left: 260,
          child: Card(
            elevation: 8,
            color: Colors.blue,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Infrastructure'),
            ),
          ),
        ),
    
        Positioned(
          top: 340,
          left: 350,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Output events'),
            ),
          ),
        ),
    
        Positioned(
          top: 270,
          left: 370,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Output API'),
            ),
          ),
        ),
    
        Positioned(
          top: 340,
          left: 200,
          child: Card(
            elevation: 8,
            color: Colors.yellow,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'ORM ENTITIES',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        ),
        Positioned(
          top: 400,
          left: 200,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(padding: EdgeInsets.all(20), child: Text('BDD')),
          ),
        ),
      ],
    );
  }
}
