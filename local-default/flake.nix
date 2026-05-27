{
  description = "Default (no-op) local configuration overlay";

  outputs = { ... }: {
    home-overlay = { };
    nixos-overlay = { };
  };
}
