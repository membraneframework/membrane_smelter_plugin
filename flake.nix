{
  description = "Dev shell for plugin development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, lib, ... }:
        {
          devShells = {
            default = pkgs.mkShell {
              env.LD_LIBRARY_PATH = lib.makeLibraryPath (with pkgs; [
                xorg.libX11
                xorg.libXext
                xorg.libXrandr
                xorg.libXfixes
                xorg.libXi
                xorg.libXcursor
                xorg.libXScrnSaver
                alsa-lib
                libopus
                vulkan-loader
              ]);

              packages = with pkgs; [
                ffmpeg
                elixir
              ];
            };
          };
        };
    };
}
