{ lib , stdenv, fetchFromGitLab, meson, pkg-config, glib, libvirt, libvirt-glib, docutils, ninja, pkgs, ...}:

pkgs.stdenv.mkDerivation rec {
  pname = "libvirt-dbus";
  version = "1.4.1";

  src = fetchFromGitLab {
    owner = "libvirt";
    repo = "libvirt-dbus";
    rev = "v${version}";
    sha256 = "1nfijdax7ljqjvvf0s096cp3qh3n743p423vw5g3p7cw16sj912b";
  };

  mesonFlags = [
    "-Dsystem_user=root"
  ];

  nativeBuildInputs = [
    meson
    pkg-config
    docutils
    ninja
  ];
  buildInputs = [
    glib
    libvirt
    libvirt-glib
  ];

  meta = with lib; {
    description = "DBus protocol binding for libvirt native C API";
    license = licenses.lgpl2Plus;
    homepage = src.meta.homepage;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
}
