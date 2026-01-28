import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

typedef TextValidator =
    String? Function(String? value, TextfieldBuilderInfo info);

class TextfieldBuilderInfo {
  TextfieldBuilderInfo({
    required this.label,
    required this.bindType,
    required this.editable,
    required this.enable,
    this.controller,
    this.focus,
  });

  String? label;
  String? hint;

  String bindType; // INT, DOUBLE, CUR, PRCT, URL, MAIL, DATE, TEXT

  bool enable;
  bool editable;

  Widget? suffixIcon;
  String? pattern;
  String? suffix;
  String? prefix;
  int? maxLength;
  String? error;

  FocusNode? focus;
  TextEditingController? controller;

  List<TextInputFormatter>? formatters;
  List<TextValidator>? validators;
  TextInputType? textInputType;
  bool? required;
  Map<String, dynamic> additionalInfo = {};

  dynamic getUnmaskedValue(FormatterTextfield info, dynamic v) {
    var apattern = pattern ?? '';
    var asuffix = suffix ?? '';
    var aprefix = prefix ?? '';
    final String defaultLocale = 'fr'; //Platform.localeName;

    String vt = v;
    if (vt.startsWith(aprefix)) {
      vt = vt.substring(aprefix.length);
    }
    if (vt.endsWith(asuffix)) {
      vt = vt.substring(0, vt.length - asuffix.length);
    }
    if (!info.isNum) {
      return vt.toString();
    }

    var numFormatter = NumberFormat(apattern, defaultLocale);
    v = numFormatter.tryParse(vt);
    if (v != null) {
      if (bindType == 'INT') {
        return (v as num).toInt();
      } else if (bindType == 'DOUBLE' ||
          bindType == 'CUR' ||
          bindType == 'PRCT') {
        return (v as num).toDouble();
      }
    }
    return v;
  }
}

//-------------------------------------------------------------------------------
class FormatterTextfield {
  List<TextInputFormatter>? formatters;
  TextInputType? inputType;
  List<TextValidator>? validators;
  String? hint;
  bool isNum = false;

  void initMaskAndValidatorInfo(TextfieldBuilderInfo infoMask) {
    isNum =
        infoMask.bindType == 'INT' ||
        infoMask.bindType == 'DOUBLE' ||
        infoMask.bindType == 'CUR' ||
        infoMask.bindType == 'PRCT';

    switch (infoMask.bindType) {
      case 'INT':
        infoMask.pattern = '#,###';
        infoMask.suffix = '';
        infoMask.prefix = '';
        formatters = [NumericInputFormatter(info: infoMask)];
        inputType = TextInputType.number;
        double? valueMax = infoMask.additionalInfo['max'];
        double? valueMin = infoMask.additionalInfo['min'];
        validators ??= [];
        validators!.add((value, current) {
          if (value == null || value == '') {
            return null;
          }
          double v = current.getUnmaskedValue(this, value);
          if (valueMax != null && v > valueMax) {
            return 'max $valueMax';
          }
          if (valueMin != null && v < valueMin) {
            return 'min $valueMin';
          }
          return null;
        });
        break;

      case 'DOUBLE':
        infoMask.pattern = '#,##0.######';
        infoMask.suffix = '';
        infoMask.prefix = '';
        formatters = [NumericInputFormatter(info: infoMask)];
        //FilteringTextInputFormatter.allow(RegExp(r'(^-?\d*\.?\d*)'));
        inputType = TextInputType.number;
        double? valueMax = infoMask.additionalInfo['max'];
        double? valueMin = infoMask.additionalInfo['min'];
        validators ??= [];
        validators!.add((value, current) {
          if (value == null || value == '') {
            return null;
          }
          double v = current.getUnmaskedValue(this, value);
          if (valueMax != null && v > valueMax) {
            return 'max $valueMax';
          }
          if (valueMin != null && v < valueMin) {
            return 'min $valueMin';
          }
          return null;
        });
        break;

      case 'CUR':
        infoMask.pattern = '#,##0.00';
        infoMask.suffix = ' €';
        infoMask.prefix = '';
        formatters = [NumericInputFormatter(info: infoMask)];
        inputType = TextInputType.number;
        double? valueMax = infoMask.additionalInfo['max'];
        double? valueMin = infoMask.additionalInfo['min'];
        validators ??= [];
        validators!.add((value, current) {
          if (value == null || value == '') {
            return null;
          }
          double v = current.getUnmaskedValue(this, value);
          if (valueMax != null && v > valueMax) {
            return 'max $valueMax';
          }
          if (valueMin != null && v < valueMin) {
            return 'min $valueMin';
          }
          return null;
        });
        break;

      case 'PRCT':
        infoMask.pattern = '#,##0.##';
        infoMask.suffix = ' %';
        infoMask.prefix = '';
        formatters = [NumericInputFormatter(info: infoMask)];
        inputType = TextInputType.number;
        break;

      case 'URL':
        validators ??= [];
        validators!.add(
          (value, current) {
                if (value == null || value.isEmpty) {
                  return null;
                }
                // if (TKValidatorString().isURL(value)) {
                //   return null;
                // }
                return 'wrong url';
              }
              as TextValidator,
        );
        break;

      case 'MAIL':
        validators ??= [];
        validators!.add(
          (value, current) {
                if (value == null || value.isEmpty) {
                  return null;
                }
                // if (EmailValidator.validate(value)) {
                //   return null;
                // }
                return 'wrong mail';
              }
              as TextValidator,
        );
        break;

      case 'DATE':
        formatters = [maskDate];
        hint = '__/__/____';
        validators ??= [];
        validators!.add((value, current) {
          if (value == null || value.isEmpty) {
            return null;
          }
          final components = value.split('/');
          if (components.length == 3) {
            final day = int.tryParse(components[0]);
            final month = int.tryParse(components[1]);
            final year = int.tryParse(components[2]);
            if (day != null && month != null && year != null && year > 1900) {
              var date = DateTime(year, month, day);
              var bool =
                  date.year == year && date.month == month && date.day == day;
              if (bool) {
                return null;
              }
            }
          }
          return 'wrong date';
        });
        break;

      case 'TEXT':
        double? valueMax = infoMask.additionalInfo['max'];
        double? valueMin = infoMask.additionalInfo['min'];
        if (valueMax != null) {
          infoMask.maxLength = valueMax.toInt();
        }

        infoMask.required = infoMask.additionalInfo['required'];
        if (infoMask.additionalInfo['mask'] != null) {
          var maskFormatter = MaskTextInputFormatter(
            mask: infoMask.additionalInfo['mask']!,
            filter: {
              '9': RegExp(r'[0-9]'),
              'x': RegExp(r'[\w.]'),
              'a': RegExp(r'[^0-9]'),
            },
            type: MaskAutoCompletionType.eager,
          );
          formatters = [maskFormatter];
        }

        // hint = 'required';
        validators ??= [];
        validators!.add((value, current) {
          if ((infoMask.required ?? false) && (value?.isEmpty ?? true)) {
            return 'Can\'t be empty';
          }
          if ((value?.length ?? 0) < (valueMin ?? 0)) {
            return 'Too short (min $valueMin)';
          }
          return null;
        });

        break;
    }
  }
}

//-------------------------------------------------------------------------------
final MaskTextInputFormatter maskDate = MaskTextInputFormatter(
  mask: '##/##/####',
  filter: {'#': RegExp(r'[0-9]')},
  type: MaskAutoCompletionType.eager,
);

//-------------------------------------------------------------------------------
class NumericInputFormatter extends TextInputFormatter {
  NumericInputFormatter({required this.info});

  TextfieldBuilderInfo info;

  final String defaultLocale = 'fr'; // Platform.localeName;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var pattern = info.pattern ?? '';
    var suffix = info.suffix ?? '';
    var prefix = info.prefix ?? '';

    var numFormatter = NumberFormat(info.pattern, defaultLocale);
    String decimalSep = numFormatter.symbols.DECIMAL_SEP;
    String tousandSep = numFormatter.symbols.GROUP_SEP;

    String textNew = newValue.text;
    if (textNew == '') {
      return newValue;
    }

    if (decimalSep != '.') {
      textNew = textNew.replaceAll(RegExp(r'\.'), decimalSep);
    }

    var posCur = newValue.selection.base.offset;
    // gestion suppression du separateur
    var splitOld = oldValue.text.split(decimalSep);
    if (splitOld.length == 2) {
      String txtSupSep = splitOld[0] + splitOld[1];
      if (txtSupSep == textNew) {
        var end = splitOld[0].length - 1;
        var endText = splitOld[1];
        var withSep = endText;
        if (endText.endsWith(suffix)) {
          withSep = withSep.substring(0, withSep.length - suffix.length);
        }
        if (splitOld[0] == '${prefix}0') {
          end = end + 1;
        }
        textNew =
            splitOld[0].substring(0, end < 0 ? 0 : end) +
            (withSep.isNotEmpty ? decimalSep : '') +
            endText;
        posCur = posCur - 1;
      }
    }

    // gestion saisie separateur
    if (textNew.startsWith(prefix)) {
      textNew = textNew.substring(prefix.length);
    }
    if (textNew.endsWith(suffix)) {
      textNew = textNew.substring(0, textNew.length - suffix.length);
    }
    if (textNew.endsWith(decimalSep) &&
        splitOld.length == 2 &&
        splitOld[1].length == 1 + suffix.length) {
      //retire le sep
      textNew = textNew.substring(0, textNew.length - 1);
    }

    int idxdd = textNew.indexOf('$decimalSep$decimalSep');
    if (textNew == decimalSep || idxdd >= 0) {
      return TextEditingValue(
        text:
            textNew == decimalSep ? '${prefix}0$textNew$suffix' : oldValue.text,
        selection: TextSelection.collapsed(
          offset:
              idxdd >= 0
                  ? prefix.length + idxdd + 1
                  : newValue.selection.baseOffset + 1,
        ),
      );
    }

    if (textNew == '') {
      return const TextEditingValue(text: '');
    }

    var valueNew = numFormatter.tryParse(textNew);
    print('$textNew => $valueNew idx=$posCur');

    if (valueNew == null) return oldValue;

    var textOld = oldValue.text;
    if (textOld.startsWith(prefix)) {
      textOld = textOld.substring(prefix.length);
    }
    if (textOld.endsWith(suffix)) {
      textOld = textOld.substring(0, textOld.length - suffix.length);
    }

    var valueOld = numFormatter.tryParse(textOld);

    var dblgroup = valueNew.toString().split('.');

    var firstSep = textNew.endsWith(decimalSep);

    // conserve les 0 apres la virgule et le separateur
    var isFormatDisable = firstSep || valueOld == valueNew;

    if (isFormatDisable) {
      var idx = newValue.selection.baseOffset;
      if (textNew.startsWith(',')) {
        //reste devant le 0 et garde toujours un 0
        textNew = '0$textNew';
        idx++;
      }

      // ne depasse pas le nb de decimal prévu
      var nbgroupPattern = pattern.toString().split('.');
      bool isInt = nbgroupPattern.length == 1;

      var textGroup = textNew.split(decimalSep);
      if (textGroup.length > 1 && isInt) {
        // pas decimal sur de l'int
        textNew = textGroup[0];
      } else if (textGroup.length > 1 &&
          textGroup[1].length > nbgroupPattern[1].length) {
        textNew =
            textGroup[0] +
            decimalSep +
            textGroup[1].substring(0, nbgroupPattern[1].length);
      }
      if (idx > prefix.length + textNew.length) {
        idx = prefix.length + textNew.length;
      }

      return TextEditingValue(
        text: prefix + textNew + suffix,
        selection: TextSelection.collapsed(offset: idx),
      );
    }

    int posSep = textNew.indexOf(decimalSep) + prefix.length;
    // pas + de 10 digit avant la virgule
    if (dblgroup[0].length > 10 && (posSep == -1 || posCur <= posSep)) {
      return oldValue;
    }

    // max le nb de digit aprés la virgule
    var nbgroupPattern = pattern.toString().split('.');
    if (nbgroupPattern.length > 1 &&
        dblgroup[1].length > nbgroupPattern[1].length) {
      textNew =
          dblgroup[0] +
          decimalSep +
          dblgroup[1].substring(0, nbgroupPattern[1].length);
      valueNew = numFormatter.tryParse(textNew);
    }

    // if (valueOld == 0 && posCur <= prefix.length) {
    //   print(textNew);
    // }

    var valText = numFormatter.format(valueNew);

    int nbT = tousandSep.allMatches(textOld).length;
    int nbT2 = tousandSep.allMatches(valText).length;
    if ((valueOld.toString().length - valueNew.toString().length).abs() == 1) {
      if (nbT2 > nbT) {
        posCur++;
      }

      if (nbT2 < nbT) {
        posCur--;
      }
    }

    if (posCur > prefix.length + valText.length) {
      // ne sort pas sur le suffix
      posCur = prefix.length + valText.length;
    }

    if (valueNew == 0) {
      posSep = valText.indexOf(decimalSep);
      if (posSep >= 0) {
        //se position pour remplacer le 0
        posCur = prefix.length + posSep;
      }
    } else {
      if (textNew.startsWith('0')) {
        posSep = newValue.text.indexOf(decimalSep);
        //reste avant la virgule
        if (posCur <= posSep) posCur--;
      }
    }
    if (posCur < prefix.length) {
      // se position apres le prefix
      posCur = prefix.length + 1;
    }

    print('TextEditingValue ====>$valText  nbt=$nbT nbt2=$nbT2  nbgroup=$dblgroup  idx=$posCur');

    return TextEditingValue(
      text: prefix + valText + suffix,
      selection: TextSelection.collapsed(offset: posCur),
    );
  }
}
