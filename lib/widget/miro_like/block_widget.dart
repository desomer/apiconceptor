import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/block_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

class BlockWidget extends StatelessWidget {
  final Block block;
  final bool isSelected;

  const BlockWidget({super.key, required this.block, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final blockFillColor =
        kBlockColorMap[block.colorKey] ?? colorBlockBackground;
    return Container(
      width: block.size.width,
      height: block.size.height,
      decoration: BoxDecoration(
        color: isSelected ? colorBlockBackgroundSelected : blockFillColor,
        border: Border.all(
          color: isSelected ? colorBlockBorderSelected : colorBlockBorder,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorShadow1,
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          block.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? colorBlockTextSelected : colorBlockText,
          ),
        ),
      ),
    );
  }
}
