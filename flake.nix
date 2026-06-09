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
          # SMELTER_PATH (set in the shellHook below) points at this binary so the
          # plugin uses it instead of downloading a prebuild at compile time.
          smelter = inputs'.smelter.packages.default;

          # Elixir toolchain on Erlang/OTP 28. mix.exs requires elixir ~> 1.13.
          # Note: OTP 29 is available but rebar3 fails to build against it in
          # this nixpkgs (a new OTP 29 compiler error), so we pin OTP 28.
          beamPackages = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang_28;

          # Native libraries for the Membrane plugins the examples use. Bundlex
          # first tries to download precompiled natives (the FFmpeg URL is dead),
          # then falls back to pkg-config, so these are exposed both at build time
          # (PKG_CONFIG_PATH via buildInputs) and at NIF load time (LD_LIBRARY_PATH
          # in the shellHook).
          #
          # FFmpeg is pinned to 6.x, the version the Membrane 0.x plugins target:
          #   - FFmpeg 7 dropped the legacy in/out_channel_layout swresample options
          #     that membrane_ffmpeg_swresample_plugin still sets -> swr_init() fails.
          #   - FFmpeg 8 fails to compile membrane_h264_ffmpeg_plugin.
          # alsa-lib provides libasound.so.2, a runtime dep of the portaudio bundle.
          nativeLibs = with pkgs; [
            ffmpeg_6
            SDL2
            SDL2_ttf
            portaudio
            fdk_aac
            libopus
            alsa-lib
          ];
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

              nativeBuildInputs = [ pkgs.pkg-config ];
              buildInputs = nativeLibs;

              shellHook = ''
                export SMELTER_PATH=${smelter}/bin/smelter
                # NIFs resolve their shared libs at load time via LD_LIBRARY_PATH.
                # stdenv.cc.cc.lib adds libstdc++.so.6, which the precompiled
                # portaudio bundle links against.
                export LD_LIBRARY_PATH="${lib.makeLibraryPath (nativeLibs ++ [ pkgs.stdenv.cc.cc.lib ])}:$LD_LIBRARY_PATH"
                # Let ALSA find the pulse/jack PCM plugins so the portaudio
                # examples route audio to the system sound server (PipeWire's
                # pulse-compatible socket) instead of only raw ALSA `default`.
                export ALSA_PLUGIN_DIR="${pkgs.alsa-plugins}/lib/alsa-lib"
              '';
            };
          };
        };
    };
}
