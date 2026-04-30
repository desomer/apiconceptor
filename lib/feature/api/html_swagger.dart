import 'dart:convert';

class HtmlSwagger {
  String htmlRedoc(Map yaml) {
    var s = jsonEncode(yaml);

    var r = '''<!DOCTYPE html>  
<html lang="en">
<head>  
  <meta charset="UTF-8">  
  <base href="https://apiarchitec.netlify.app/">  
  <title>ReDoc</title>
  <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>
</head>
<body>
  <div id="redoc"></div>

  <script>
    const spec = $s;
    Redoc.init(spec, {}, document.getElementById('redoc'));
  </script>
</body> 
</html>''';

    return r;
  }

  String htmlSwagger(Map yaml) {
    var s = jsonEncode(yaml);

    var r = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <base href="https://apiarchitec.netlify.app/">
  <title>Swagger UI</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.32.1/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.32.1/swagger-ui-bundle.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.32.1/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = () => {
      const spec = $s; 

      console.log('Loaded Swagger Spec:', SwaggerUIBundle); // Debug log
      console.log('Spec content:', SwaggerUIBundle.presets); // Debug log
      SwaggerUIBundle({
        spec: spec,  
        dom_id: "#swagger-ui",
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ]        
      });
    };
  </script>
</body>
</html>''';

    return r;
  }
}
