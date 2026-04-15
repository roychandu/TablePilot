/// Base URL for serving static assets (images/icons) from AWS S3 / CDN.
/// Update here if the CDN domain changes.
const String _staticAssetsBaseUrl = "https://go.atlassyguld.info/assets/";

/// Folder path inside the bucket where static images live.
/// Keep the leading/trailing slashes consistent.
const String subFolderName = "/p261/menu/";

/// Returns a full URL for a static asset.
///
/// Usage:
///   getStaticImageUrl("images/profile_placeholder.png");
///   getStaticImageUrl("/images/logo.png");
///
/// If an absolute URL is provided, it is returned unchanged.
String getStaticImageUrl(String path) {
  if (path.isEmpty) return "";
  if (path.startsWith("http")) return path;

  final normalizedPath = path.startsWith("/") ? path.substring(1) : path;

  // Ensure subFolderName has no leading slash when concatenated after base URL.
  final folder = subFolderName.startsWith("/")
      ? subFolderName.substring(1)
      : subFolderName;

  // Ensure folder ends with a slash.
  final folderWithSlash = folder.endsWith("/") ? folder : "$folder/";

  return "$_staticAssetsBaseUrl$folderWithSlash$normalizedPath";
}

/// Common static asset helpers (add more here as needed).
String get profilePlaceholderImage =>
    getStaticImageUrl("images/profile_placeholder.png");
