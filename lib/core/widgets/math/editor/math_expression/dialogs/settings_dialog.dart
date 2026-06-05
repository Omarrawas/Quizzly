import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../data/models/settings_model.dart';
import '../utils/custom_text_decoration.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  SettingsDialogState createState() => SettingsDialogState();
}

class SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              if (state is SettingsLoadSuccess) {
                final settings = state.settings;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSettingsSection(
                        'Editor Settings',
                        [
                          _buildSwitchTile(
                            'Show Preview',
                            settings.showPreview,
                            (value) {
                              context.read<SettingsBloc>().add(UpdateSetting(
                                    key: 'showPreview',
                                    value: value,
                                  ));
                            },
                            'Toggle real-time preview panel',
                          ),
                          _buildSwitchTile(
                            'Auto-Complete',
                            settings.enableAutoComplete,
                            (value) {
                              context.read<SettingsBloc>().add(UpdateSetting(
                                    key: 'enableAutoComplete',
                                    value: value,
                                  ));
                            },
                            'Enable symbol and expression auto-completion',
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildSettingsSection(
                        'Auto-Save Settings',
                        [
                          _buildSwitchTile(
                            'Enable Auto-Save',
                            settings.autoSave,
                            (value) {
                              context.read<SettingsBloc>().add(UpdateSetting(
                                    key: 'autoSave',
                                    value: value,
                                  ));
                            },
                            'Automatically save your work',
                          ),
                        ],
                      ),
                    ]);
              } else if (state is SettingsLoadInProgress) {
                return const Center(child: CircularProgressIndicator());
              } else {
                return const Text('Failed to load settings.');
              }
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.read<SettingsBloc>().add(ResetSettings());
          },
          child: const Text('Reset to Defaults'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
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

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        dense: true,
      ),
    );
  }
}
