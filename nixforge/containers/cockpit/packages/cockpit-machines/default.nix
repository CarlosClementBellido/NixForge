{ lib, stdenv, fetchzip, gettext, gobject-introspection, osinfo-db-tools, python3Packages, pkgs, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "cockpit-machines";
  version = "309";

  src = fetchzip {
    url = "https://github.com/cockpit-project/cockpit-machines/releases/download/${version}/cockpit-machines-${version}.tar.xz";
    sha256 = "sha256-sVjP3KFmZH3c2tGzlEohAue0u2e7+vAmXBBA+5uuass=";
  };

  # gobject-introspection works now, thanks to the post below. but...
  # https://discourse.nixos.org/t/getting-things-gnome-modulenotfounderror-no-module-named-gi/8439/4
  # ...the python script that cockpit-machines runs is failing with a "No such file or directory" error.
  # the script loads properly and i'm not getting an import or gi "Namespace Libosinfo is not available"
  # error, so i'm thinking that the OSINFO_DATA_DIR env var needs to be set. however...
  nativeBuildInputs = [
    gettext
    gobject-introspection
    osinfo-db-tools    
  ];

  # ...osinfo-db doesn't show up in nix-support/propagated-build-inputs, and...
  propagatedBuildInputs = with pkgs; [
    python3Packages.pygobject3
    libosinfo
    osinfo-db
  ];

  makeFlags = [ "DESTDIR=$(out)" "PREFIX=" ];

  postPatch = ''
    touch pkg/lib/cockpit.js
    touch pkg/lib/cockpit-po-plugin.js
    touch dist/manifest.json
  '';

  postFixup = ''
    gunzip $out/share/cockpit/machines/index.js.gz
    sed -i "s#/usr/bin/python3#/usr/bin/env python3#ig" $out/share/cockpit/machines/index.js
    sed -i "s#/usr/bin/pwscore#/usr/bin/env pwscore#ig" $out/share/cockpit/machines/index.js
    gzip -9 $out/share/cockpit/machines/index.js

    # ...this doesn't work either
    osinfo-db-import --dir "$out/share/osinfo" "${pkgs.osinfo-db.src}"
  '';

  dontBuild = true;

  meta = with lib; {
    description = "Cockpit UI for virtual machines";
    license = licenses.lgpl21;
    homepage = "https://github.com/cockpit-project/cockpit-machines";
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
}