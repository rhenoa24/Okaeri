import 'package:flutter/material.dart';

class OkaeriSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const OkaeriSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SearchBar(
          controller: controller,
          hintText: hintText,
          leading: const Icon(Icons.search),

          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),

          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),

          hintStyle: WidgetStatePropertyAll(
            TextStyle(color: Theme.of(context).colorScheme.outline),
          ),

          trailing: controller.text.isNotEmpty
              ? [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
                ]
              : null,

          onChanged: onChanged,
        );
      },
    );
  }
}
