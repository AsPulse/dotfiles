# AsPulse/dotfiles
My dotfiles, Nix configurations, etc.

<br />

**for those who want to import my complete settings**
```nix
inputs = {
  aspulse-dotfiles.url = "github:AsPulse/dotfiles";
};
```
```nix
modules = [
  setup
  aspulse-dotfiles.desktopModules.aarch64-darwin
  # your-desktop-configuration.nix
  home-manager.darwinModules.home-manager {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.<your-username> = { ... }: {
        imports = [
          aspulse-dotfiles.homeModules.aarch64-darwin
          # your-home-manager-configuration.nix
        ];
      };
      extraSpecialArgs = { inherit inputs; };
    };
    users.users.<your-username>.home = "/Users/<your-username>";
  }
];
```
