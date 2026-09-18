import 'package:flutter/widgets.dart';

/// A simple dependency injection and state management container
/// that replaces flutter_riverpod.
class ProviderScope extends InheritedWidget {
  final Map<Type, dynamic> dependencies;

  const ProviderScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  @override
  bool updateShouldNotify(ProviderScope oldWidget) => false;

  static T read<T>(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<ProviderScope>();
    if (element == null) {
      throw FlutterError('No ProviderScope found in context');
    }
    final scope = element.widget as ProviderScope;
    final dep = scope.dependencies[T];
    if (dep == null) {
      throw FlutterError('Dependency of type $T not found in ProviderScope');
    }
    return dep as T;
  }
}
