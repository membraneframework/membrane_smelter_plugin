{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # Smelter compositor binary, built from source at the v0.6.0 tag.
    # The flake lives in the tools/nix subdirectory of the repo.
    smelter.url = "github:software-mansion/smelter/v0.6.0?dir=tools/nix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, lib, ... }:
        let
          # Smelter compositor binary built from the v0.6.0 tag (tools/nix flake).
          # The plugin uses SMELTER_PATH (exported in the devShell shellHook below)
          # to point at this binary instead of downloading a prebuild.
          smelter = inputs'.smelter.packages.default;

          # Elixir toolchain on Erlang/OTP 28. mix.exs requires elixir ~> 1.13.
          # Note: OTP 29 is available but rebar3 fails to build against it in
          # this nixpkgs (a new OTP 29 compiler error), so we pin OTP 28.
          beamPackages = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang_28;
        in
        {
          devShells = {
            default = pkgs.mkShell {
              packages = [
                beamPackages.elixir_1_20
                beamPackages.erlang
                beamPackages.hex
                beamPackages.rebar3
                smelter
              ];

              shellHook = ''
                export SMELTER_PATH=${smelter}/bin/smelter
              '';
            };
          };
        };
    };
}
