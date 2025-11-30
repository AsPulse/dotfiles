{ stdenv, lib, ... }: stdenv.mkDerivation  {
  pname = "pinentry-touchid";
  version = "v0.0.3";

  src = builtins.fetchurl {
    url = "https://github.com/jorgelbg/pinentry-touchid/releases/download/v0.0.3/pinentry-touchid_0.0.3_macos_arm64.tar.gz";
    sha256 = "0wkppmlq4795xpikmcjalsmy12d9519ph0p4x9gf8v435sh2873g";
  };

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    tar -zxvf $src -C $out/bin pinentry-touchid
    chmod a+x $out/bin/pinentry-touchid
  '';
  
  meta = with lib; {
    description = "Custom GPG pinentry program for macOS that allows using Touch ID";
    homepage = "https://github.com/jorgelbg/pinentry-touchid";
    license = licenses.asl20;
    platforms = platforms.darwin;
  };
}
