import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class CommunityResourcesPage extends StatelessWidget {
  const CommunityResourcesPage({super.key});

  static final _content = rootBundle.loadString('content/parent_hub/resources.txt');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load resources.'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            snapshot.data!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      },
    );
  }
}
