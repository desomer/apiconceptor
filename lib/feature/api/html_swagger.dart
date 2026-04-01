import 'dart:convert';

class HtmlSwagger {

  String htmlSwagger(Map yaml) {

    var s = jsonEncode(yaml);   

    var r = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Swagger UI</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.32.1/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>

  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.32.1/swagger-ui-bundle.js"></script>
  <script>
    window.onload = () => {
      const spec = $s; 

      SwaggerUIBundle({
        spec: spec,  
        dom_id: "#swagger-ui"
      });
    };
  </script>
</body>
</html>''';

    return r;
  }
}
