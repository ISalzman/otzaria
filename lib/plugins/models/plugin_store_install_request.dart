class PluginStoreInstallRequest {
  final Uri downloadUri;
  final bool forceOverwrite;

  const PluginStoreInstallRequest({
    required this.downloadUri,
    this.forceOverwrite = false,
  });
}
