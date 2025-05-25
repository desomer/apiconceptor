class CaseValidator {
  ///Can be also referred as: lower flat case
  var lowerflatcase = RegExp(r'[a-z0-9]+');

  /// Represents matching for upper flat case, e.g. 'UPPERFLATCASE'
  var upperflatcase = RegExp(r'[A-Z0-9]+');

  /// Represents matching for camel case, e.g. 'camelCase'
  ///
  /// Can be also referred as: lower camel case, dromedary case
  var camelCase = RegExp(r'[a-z]+(?:[A-Z0-9]+[a-z0-9]+[A-Za-z0-9]*)*');

  /// Represents matching for upper camel case, e.g. 'UpperCamelCase'
  ///
  /// Can be also referred as: pascal case, studly case
  var uppercamelCase = RegExp(r'(?:[A-Z][a-z0-9]+)(?:[A-Z]+[a-z0-9]*)*');

  /// Represents matching for snake case, e.g. 'snake_case'
  ///
  /// Can be also referred as: lower snake case, pothole case
  var snakecase = RegExp(r'[a-z0-9]+(?:_[a-z0-9]+)*');

  /// Represents matching for screaming snake case, e.g. 'SCREAMING_SNAKE_CASE'
  ///
  /// Can be also referred as: upper snake case, macro case, constant case
  var uppersnakecase = RegExp(r'[A-Z0-9]+(?:_[A-Z0-9]+)*');

  /// Represents matching for camel snake case, e.g. 'Camel_Snake_Case'
  var camelsnakecase = RegExp(r'[A-Z][a-z0-9]+(?:_[A-Z]+[a-z0-9]*)*');

  /// Represents matching for kebab case, e.g. 'kebab-case'
  ///
  /// Can be also referred as: lower kebab case, dash case, lisp case
  var kebabcase = RegExp(r'[a-z0-9]+(?:-[a-z0-9]+)*');

  /// Represents matching for screaming kebab case, e.g. 'SCREAMING-KEBAB-CASE'
  ///
  /// Can be also referred as: upper kebab case, cobol case
  var upperkebabcase = RegExp(r'[A-Z0-9]+(?:-[A-Z0-9]+)*');

  /// Represents matching for train case, e.g. 'Train-Case'
  var trainCase = RegExp(r'[A-Z][a-z0-9]+(?:-[A-Z]+[a-z0-9]*)*');
}
