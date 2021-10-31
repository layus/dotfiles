super: self: {

  moreRecent = package: version: builtins.compareVersions package.version version > 0;

}
