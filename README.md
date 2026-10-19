# omp-bin

Nix flake packaging the prebuilt [oh-my-pi](https://github.com/can1357/oh-my-pi) (`omp`) Linux binaries for NixOS.

## Supported systems

- `x86_64-linux`
- `aarch64-linux`

Only glibc builds are packaged; the upstream musl artifacts are not used.

## Usage

Run without installing:

```bash
nix run github:kmdtaufik/omp-bin
```

Install into a profile:

```bash
nix profile install github:kmdtaufik/omp-bin
```

Build from a checkout:

```bash
nix build
./result/bin/omp --version
```

As a flake input:

```nix
{
  inputs.omp-bin.url = "github:kmdtaufik/omp-bin";
}
```

Use the package directly with `omp-bin.packages.${system}.default`, or add the overlay:

```nix
nixpkgs.overlays = [ inputs.omp-bin.overlays.default ];
```

which provides `pkgs.omp`.

## Updates

`source.json` pins the upstream version, URLs, and SRI hashes for each asset. Update it with:

```bash
./update.sh          # latest GitHub release
./update.sh 18.12.3  # explicit version
```

The script exits without changes when the latest release is already pinned. The `Update omp` GitHub Actions workflow runs every three days, verifies the build, and commits the new `source.json` automatically.

## Notes

The upstream binary is patched with `autoPatchelfHook` and explicit RPATH entries so its runtime-extracted native addon can load `libpulse` and `libasound` on NixOS. `fix-dt-verdef.mjs` repairs the `DT_VERDEF` section after `patchelf` rewrites the dynamic section.

The packaged software is MIT-licensed; see the [upstream repository](https://github.com/can1357/oh-my-pi).
