import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:markdown_widget/markdown_widget.dart';

enum TypeMD { listmodel, model, listapi }

class WidgetMdDoc extends StatefulWidget {
  const WidgetMdDoc({super.key, required this.type});
  final TypeMD type;

  @override
  State<WidgetMdDoc> createState() => _WidgetMdDocState();
}

class _WidgetMdDocState extends State<WidgetMdDoc> {
  var mdLisModel = '''
# Structure Syntax 
Example : 
```
sales :
   order : model
   invoice : model 
client :
   customer : model
```
''';

  var mdModel = '''
# Structure Syntax 
Example 1 : Plain
```
orderId : string
quoteId : string 
itemsCount : number
activate : boolean
```
Example 2 : Objets
```
order :
    orderId : string
    quoteId : string 
other :
    example : 
       text : string
```

Example 3 : Link on component address
```
items :
    address1 : \$address
```

Example 4 : Array
```
tag : string[]

items[] :
    price : number
    activate : boolean
```

Example 5 : Array of any type
```
items :  # or items[] :
    - a :
         val : string
    - b :
         num : number
```

''';

  @override
  Widget build(BuildContext context) {
    Map<TypeMD, String> map = {
      TypeMD.listmodel: mdLisModel,
      TypeMD.model: mdModel,
    };

    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.5;
    double height = size.height * 0.8;

    return AlertDialog(
      title: const Text('Documentation YAML Structure'),
      content: SizedBox(
        width: width,
        height: height,

        child: MarkdownWidget(
          data: map[widget.type] ?? '',
          config: MarkdownConfig(
            configs: [
              PreConfig(
                theme: monokaiSublimeTheme,
                decoration: BoxDecoration(color: Colors.black54),
                language: 'YAML',
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
