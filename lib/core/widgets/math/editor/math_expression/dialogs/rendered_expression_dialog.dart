import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_math_fork/flutter_math.dart' as math_fork;

import '../../bloc/settings/settings_bloc.dart';
import '../../data/models/settings_model.dart';
import '../../widgets/custom_color_picker.dart';
import '../rendered_expression.dart';
import '../types/latex_renderer.dart';
import '../utils/custom_text_decoration.dart';

class RenderedExpressionDialog extends StatelessWidget {
  const RenderedExpressionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoadSuccess) {
            final settings = state.settings;
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expression Styling',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0, bottom: 4.0),
                    child: Text(
                      'Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    height: 150,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: const RenderedExpression(),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              _buildSettingsSection(
                                'Text Style',
                                [
                                  _buildSliderTile(
                                    'Font Size',
                                    settings.fontSize,
                                    10.0,
                                    100.0,
                                    (value) {
                                      context
                                          .read<SettingsBloc>()
                                          .add(UpdateSetting(
                                            key: 'fontSize',
                                            value: value,
                                          ));
                                    },
                                    'Adjust the font size',
                                  ),
                                  _buildColorPickerTile(
                                    'Expression Color',
                                    settings.expressionColor,
                                    (color) {
                                      context
                                          .read<SettingsBloc>()
                                          .add(UpdateSetting(
                                            key: 'expressionColor',
                                            value: color,
                                          ));
                                    },
                                    'Select the color',
                                    context,
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (state is SettingsLoadInProgress) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return const Text('Failed to load settings.');
          }
        },
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSliderTile(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String tooltip, {
    bool enabled = true,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: (max - min).round(),
        label: value.round().toString(),
        onChanged: enabled ? onChanged : null,
      ),
      dense: true,
    );
  }

  Widget _buildColorPickerTile(
    String title,
    Color currentColor,
    ValueChanged<Color> onColorChanged,
    String tooltip,
    BuildContext context,
  ) {
    return ListTile(
      title: Text(title),
      trailing: GestureDetector(
        onTap: () async {
          Color? pickedColor = await showDialog<Color>(
            context: context,
            builder: (context) {
              Color tempColor = currentColor;
              return AlertDialog(
                title: Text('Select $title'),
                content: SingleChildScrollView(
                  child: CustomColorPicker(
                    initialColor: tempColor,
                    onColorSelected: (color) {
                      tempColor = color;
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: const Text('Select'),
                    onPressed: () {
                      Navigator.of(context).pop(tempColor);
                    },
                  ),
                ],
              );
            },
          );

          if (pickedColor != null && pickedColor != currentColor) {
            onColorChanged(pickedColor);
          }
        },
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: currentColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey),
          ),
        ),
      ),
      dense: true,
    );
  }
}
