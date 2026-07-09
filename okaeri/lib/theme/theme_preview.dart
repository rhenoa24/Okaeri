import 'package:flutter/material.dart';
import 'theme_controller.dart';

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  static const seed = Color(0xFFD22C32);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, themeMode, _) {
        final systemBrightness = MediaQuery.platformBrightnessOf(context);

        final brightness = switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => systemBrightness,
        };

        final fidelityScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );

        final monochromeScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Theme Preview')),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ThemeColumn(title: 'Fidelity', scheme: fidelityScheme),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _ThemeColumn(
                  title: 'Monochrome',
                  scheme: monochromeScheme,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeColumn extends StatelessWidget {
  final String title;
  final ColorScheme scheme;

  const _ThemeColumn({required this.title, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),

          const SizedBox(height: 20),

          _sectionTitle("Primary"),
          _colorTile("Primary", scheme.primary, scheme.onPrimary),
          _colorTile(
            "Primary Container",
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
          ),

          const SizedBox(height: 20),

          _sectionTitle("Secondary"),
          _colorTile("Secondary", scheme.secondary, scheme.onSecondary),
          _colorTile(
            "Secondary Container",
            scheme.secondaryContainer,
            scheme.onSecondaryContainer,
          ),

          const SizedBox(height: 20),

          _sectionTitle("Tertiary"),
          _colorTile("Tertiary", scheme.tertiary, scheme.onTertiary),
          _colorTile(
            "Tertiary Container",
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer,
          ),

          const SizedBox(height: 20),

          _sectionTitle("Surface"),
          _colorTile("Surface", scheme.surface, scheme.onSurface),
          _colorTile("Surface Bright", scheme.surfaceBright, scheme.onSurface),
          _colorTile("Surface Dim", scheme.surfaceDim, scheme.onSurface),
          _colorTile(
            "Container Lowest",
            scheme.surfaceContainerLowest,
            scheme.onSurface,
          ),
          _colorTile(
            "Container Low",
            scheme.surfaceContainerLow,
            scheme.onSurface,
          ),
          _colorTile("Container", scheme.surfaceContainer, scheme.onSurface),
          _colorTile(
            "Container High",
            scheme.surfaceContainerHigh,
            scheme.onSurface,
          ),
          _colorTile(
            "Container Highest",
            scheme.surfaceContainerHighest,
            scheme.onSurface,
          ),

          const SizedBox(height: 20),

          _sectionTitle("Other"),
          _colorTile("Error", scheme.error, scheme.onError),
          _colorTile("Outline", scheme.outline, scheme.surface),
          _colorTile("Outline Variant", scheme.outlineVariant, scheme.surface),

          const SizedBox(height: 28),

          Text(
            "Widgets",
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Theme(
            data: ThemeData(useMaterial3: true, colorScheme: scheme),
            child: Column(
              children: [
                FilledButton(
                  onPressed: () {},
                  child: const Text("Filled Button"),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text("Outlined Button"),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: () {}, child: const Text("Text Button")),
                const SizedBox(height: 10),
                Card(
                  child: const ListTile(
                    title: Text("Card"),
                    subtitle: Text("Lorem ipsum dolor sit amet"),
                    trailing: Icon(Icons.favorite),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "TextField",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.favorite),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _colorTile(String label, Color background, Color foreground) {
    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
