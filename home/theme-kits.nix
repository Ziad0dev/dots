{ lib, pkgs, ... }:

# GTK, Kvantum, icon and cursor themes for the colour themes that come as a
# full kit: config/themes/<name>/look.conf names them (gtk, kvantum, icons,
# cursor) and dots-appearance applies them with the theme. Themes without a
# kit keep adw-gtk3 and KvGlass#, which themectl recolours to the palette.
let
  catppuccin = variant: {
    gtk = pkgs.catppuccin-gtk.override {
      inherit variant;
      accents = [ "blue" ];
    };
    kvantum = pkgs.catppuccin-kvantum.override {
      inherit variant;
      accent = "blue";
    };
  };
  mocha = catppuccin "mocha";
  latte = catppuccin "latte";

  # every other theme gets Papirus with folders in its accent colour; the
  # tints are whatever look.conf files name (icons=Papirus-Dark-violet, …)
  themes = ../config/themes;
  tints = lib.unique (
    lib.concatMap (
      t:
      let
        f = themes + "/${t}/look.conf";
        m = builtins.match ".*\nicons=Papirus-(Dark|Light)-([a-z]+)\n.*" (builtins.readFile f);
      in
      lib.optional (builtins.pathExists f && m != null) {
        variant = builtins.elemAt m 0;
        color = builtins.elemAt m 1;
      }
    ) (builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir themes)))
  );

  # several icon sets inherit from themes that aren't installed (Yaru,
  # Zafiro, …), which leaves holes; point them at Papirus like candy-icons
  iconFallback =
    pkg:
    pkgs.symlinkJoin {
      name = "${pkg.name}-icon-fallback";
      paths = [ pkg ];
      postBuild = ''
        for f in $out/share/icons/*/index.theme; do
          # whole-dir links are other packages (hicolor), not this theme
          [ -L "''${f%/index.theme}" ] && continue
          grep -q '^Directories=.' "$f" || continue
          case ''${f%/index.theme} in
            *Light | *dawn) base=Papirus-Light ;;
            *) base=Papirus-Dark ;;
          esac
          t=$(readlink -f "$f")
          rm "$f"
          sed "s|^Inherits=.*|Inherits=$base,Adwaita,hicolor|" "$t" > "$f"
          grep -q '^Inherits=' "$f" || sed -i "/^\[Icon Theme\]/a Inherits=$base,Adwaita,hicolor" "$f"
        done
      '';
    };

  # Kvantum themes are found in ~/.config/Kvantum/<name>; pick the ones the
  # kits use (rose-pine-kvantum nests its themes one level deeper). Each gets
  # translucent windows and menus (Hyprland blurs what shows through), as
  # Sweet, Nordic and Dracula already have; the rest ship them opaque.
  kvantumThemes = pkgs.runCommand "dots-kvantum-themes" { } ''
    mkdir -p $out/share/Kvantum
    for d in \
      ${pkgs.sweet-nova}/share/Kvantum/Sweet \
      ${mocha.kvantum}/share/Kvantum/catppuccin-mocha-blue \
      ${latte.kvantum}/share/Kvantum/catppuccin-latte-blue \
      ${pkgs.nordic}/share/Kvantum/Nordic \
      ${pkgs.dracula-theme}/share/Kvantum/Dracula \
      ${pkgs.gruvbox-kvantum}/share/Kvantum/Gruvbox-Dark-Brown \
      ${pkgs.rose-pine-kvantum}/share/Kvantum/themes/rose-pine-dawn-foam \
      ${pkgs.rose-pine-kvantum}/share/Kvantum/themes/rose-pine-moon-iris
    do
      [ -d "$d" ] || { echo "missing Kvantum theme: $d" >&2; exit 1; }
      n=''${d##*/}
      mkdir $out/share/Kvantum/$n
      for f in "$d"/*; do
        case $f in
          */$n.kvconfig)
            sed -E \
              -e 's/^(translucent_windows)=.*/\1=true/' \
              -e 's/^(reduce_window_opacity)=0*$/\1=15/' \
              -e 's/^(reduce_menu_opacity)=0*$/\1=20/' \
              "$f" > $out/share/Kvantum/$n/$n.kvconfig
            ;;
          *) ln -s "$f" $out/share/Kvantum/$n/ ;;
        esac
      done
    done
  '';
in
{
  qt.kvantum.themes = [ kvantumThemes ];

  home.packages = with pkgs; [
    # candy, candy-mars: Sweet GTK and Sweet-cursors (candy-icons is the
    # default icon theme, from gtk.iconTheme)
    sweet-gtk
    sweet-nova

    (papirus-tinted.override { inherit tints; })

    # catppuccin, catppuccin-latte
    mocha.gtk
    latte.gtk
    catppuccin-cursors.mochaDark
    catppuccin-cursors.latteLight

    # nord: Nordic GTK/Kvantum/cursors, Nordzy icons
    nordic
    (iconFallback nordzy-icon-theme)

    # dracula
    dracula-theme
    (iconFallback dracula-icon-theme)

    # gruvbox
    (gruvbox-gtk-theme.override { colorVariants = [ "dark" ]; })
    gruvbox-plus-icons
    capitaine-cursors-themed

    # tokyo-night
    (iconFallback (
      tokyonight-gtk-theme.override {
        colorVariants = [ "dark" ];
        iconVariants = [ "Dark" ];
      }
    ))

    # rose-pine, rose-pine-moon
    (iconFallback rose-pine-icon-theme)
    rose-pine-cursor

    # not tied to a colour theme: extra quick picks (Themes → App style)
    tela-circle-icon-theme
    colloid-icon-theme
    phinger-cursors

    # everforest (GTK + icons), kanagawa (icons)
    (iconFallback everforest-gtk-theme)
    (iconFallback kanagawa-icon-theme)
  ];
}
