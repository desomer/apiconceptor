import 'package:flutter/material.dart';
import 'dart:math';

class CarouselChoice extends StatefulWidget {
  final List<String> items;
  final ValueChanged<String> onSelected;

  const CarouselChoice({
    super.key,
    required this.items,
    required this.onSelected,
  });

  @override
  State<CarouselChoice> createState() => _CarouselChoiceState();
}

class _CarouselChoiceState extends State<CarouselChoice> {
  late final PageController controller = PageController(
    viewportFraction: 1 / widget.items.length,
  );
  double currentPage = 0;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {
        currentPage = controller.page!;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      height: 60,
      child: PageView.builder(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.items.length,
        onPageChanged: (index) {
          widget.onSelected(widget.items[index]);
        },
        itemBuilder: (context, index) {
          final scale = max(0.8, 1 - (currentPage - index).abs() * 0.2);
          final isSelected = (currentPage - index).abs() < 0.5;

          return InkWell(
            onTap: () {
              controller.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              widget.onSelected(widget.items[index]);
            },
            child: Transform.scale(
              scale: scale,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1 : 0.6,
                child: ChoiceCard(
                  label: widget.items[index],
                  selected: isSelected,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ChoiceCard extends StatelessWidget {
  final String label;
  final bool selected;

  const ChoiceCard({super.key, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? Colors.blue : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow:
            selected
                ? [
                  BoxShadow(
                    color: Colors.blue.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
                : [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: selected ? 20 : 16,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
