{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  nodejs,
  patchelf,
  alsa-lib,
  libpulseaudio,
  version,
  src,
}:

let
  fixDtVerdef = ./fix-dt-verdef.mjs;
  nativeLibraryPath = lib.makeLibraryPath [ stdenv.cc.cc.lib ];
  runtimeLibraryPath = lib.makeLibraryPath [
    stdenv.cc.libc
    stdenv.cc.cc.lib
    libpulseaudio
    alsa-lib
  ];
in
stdenv.mkDerivation {
  pname = "omp";
  inherit version src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    nodejs
    patchelf
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libpulseaudio
    alsa-lib
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/omp"
    runHook postInstall
  '';

  postFixup = ''
    patchelf --add-needed libstdc++.so.6 "$out/bin/omp"
    wrapProgram "$out/bin/omp" \
      --set-default OMP_NATIVE_LIBRARY_PATH "${nativeLibraryPath}"
  '';

  preInstallCheck = ''
    existingRpath="$(patchelf --print-rpath "$out/bin/.omp-wrapped")"
    rpath="${runtimeLibraryPath}"
    if [ -n "$existingRpath" ]; then
      rpath="$rpath:$existingRpath"
    fi
    patchelf --force-rpath --set-rpath "$rpath" "$out/bin/.omp-wrapped"
    node ${fixDtVerdef} "$out/bin/.omp-wrapped"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    smokeOutput="$("$out/bin/omp" --smoke-test)"
    grep -q "smoke-test: ok" <<<"$smokeOutput"
    runHook postInstallCheck
  '';

  meta = {
    description = "Terminal coding agent with multi-model support (prebuilt binary)";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
