class PlatformViewRegistryStub {
  void registerViewFactory(String viewId, dynamic Function(int) viewFactory) {
    // Stub implementation does nothing
  }
}

final platformViewRegistry = PlatformViewRegistryStub();
