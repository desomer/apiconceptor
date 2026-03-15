import 'package:jsonschema/core/import/json2schema_yaml.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) {
  Swagger2Schema().import();
}

class Swagger2Schema {
  Future<void> import() async {
    String swagger = r"""
openapi: 3.1.0
info:
  title: API Catalogue
  version: 1.0.0

paths:
  /products:
    get:
      summary: Liste paginée des produits
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
        - name: pageSize
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
      responses:
        '200':
          description: Page de produits
          content:
            application/json:
              schema:
                $ref: '#/$defs/PaginatedProducts'

    post:
      summary: Créer un produit
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/$defs/ProductInput'
      responses:
        '201':
          description: Produit créé
          content:
            application/json:
              schema:
                $ref: '#/$defs/Product'

  /products/{id}:
    get:
      summary: Récupérer un produit
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Produit trouvé
          content:
            application/json:
              schema:
                $ref: '#/$defs/Product'

$defs:
  PaginatedProducts:
    type: object
    required: [items, page, pageSize, total]
    properties:
      items:
        type: array
        items:
          $ref: '#/$defs/Product'
      page:
        type: integer
      pageSize:
        type: integer
      total:
        type: integer

  ProductInput:
    type: object
    required: [name, price, category]
    properties:
      name:
        type: string
        minLength: 2
      price:
        type: number
        minimum: 0
      category:
        $ref: '#/$defs/Category'
      attributes:
        type: object
        additionalProperties:
          $ref: '#/$defs/AttributeValue'

  Product:
    allOf:
      - $ref: '#/$defs/ProductInput'
      - type: object
        required: [id]
        properties:
          id:
            type: string
          createdAt:
            type: string
            format: date-time

  Category:
    type: string
    enum:
      - electronics
      - clothing
      - food
      - books

  AttributeValue:
    oneOf:
      - type: string
      - type: number
      - type: boolean
      - type: array
        items:
          type: string
  """;

    var root = loadYaml(swagger);

    ImportData data = ImportData();
    doAttr(null, root, data);
    //print('${data.yaml}');
    //return data;
  }

  void doAttr(String? name, dynamic value, ImportData data) {
    if (value is List) {
      data.level++;
      if (value.isNotEmpty) {
        for (var i = 0; i < value.length; i++) {
          print('item "$name[$i]" level=${data.level} path=${data.path}');
          data.path.add('$name[$i]');
          doAttr(null, value[i], data);
          data.path.removeLast();
        }
      }
      data.level--;
    } else if (value is Map) {
      if (name != null) {
        data.level++;
        data.path.add(name);
        print('object "$name" level=${data.level} path=${data.path}');
      }
      for (var element in value.entries) {
        doAttr(element.key, element.value, data);
      }
      if (name != null) {
        data.level--;
        data.path.removeLast();
      }
    } else {
      if (name != null) {
        print('"$name" = <$value> level=${data.level} path=${data.path}');
      } else {
        print('- <$value> level=${data.level} path=${data.path}');
      }
      // data.yaml.write(name);
      // data.yaml.write(' : ');
      // data.yaml.writeln(getType(value));
    }
  }

  String getType(dynamic v) {
    if (v is int) {
      return 'integer';
    } else if (v is num) {
      return 'number';
    } else if (v is bool) {
      return 'boolean';
    }
    return 'string';
  }
}
