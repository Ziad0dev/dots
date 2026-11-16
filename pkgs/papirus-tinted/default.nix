{
  lib,
  runCommand,
  papirus-icon-theme,
  # [ { variant = "Dark" | "Light"; color = "violet"; } … ]
  tints ? [ ],
}:

# Papirus with its folders in another colour, as separate thin themes
# (Papirus-Dark-violet, …) so every colour theme can have its own: only the
# places icons are relinked (what papirus-folders does in place), the rest is
# inherited from Papirus-Dark / Papirus-Light.
let
  papirus = "${papirus-icon-theme}/share/icons";
  one =
    { variant, color }:
    ''
      tint ${lib.escapeShellArg variant} ${lib.escapeShellArg color}
    '';
in
runCommand "papirus-tinted"
  {
    meta = {
      description = "Papirus icon themes with tinted folders";
      inherit (papirus-icon-theme.meta) license platforms;
    };
  }
  ''
    # Papirus' default folder colour is blue: folder.svg -> folder-blue.svg,
    # user-home.svg -> user-blue-home.svg, …
    tint() {
      local variant=$1 color=$2 base=Papirus-$1 name=Papirus-$1-$2
      local src=${papirus}/$base dst=$out/share/icons/$name dirs= scaled= d f t new real
      for d in $(sed -n 's/^\(Scaled\)\?Directories=//p' $src/index.theme | tr , '\n' | grep '/places$'); do
        real=$(readlink -f $src/$d)
        [ -d "$real" ] || continue
        mkdir -p $dst/$d
        for f in $real/*; do
          [ -L "$f" ] || continue
          t=$(readlink "$f")
          case $t in */*) continue ;; *-blue*) ;; *) continue ;; esac
          new=''${t/-blue/-$color}
          [ -e "$real/$new" ] && ln -s "$real/$new" "$dst/$d/''${f##*/}"
        done
        rmdir $dst/$d 2>/dev/null && continue
        case $d in *@2x/*) scaled=$scaled,$d ;; *) dirs=$dirs,$d ;; esac
      done
      [ -n "$dirs$scaled" ] || { echo "no folders tinted for $name" >&2; exit 1; }
      {
        printf '[Icon Theme]\nName=Papirus %s (%s folders)\n' "$variant" "$color"
        printf 'Comment=Papirus-%s with %s folders\n' "$variant" "$color"
        printf 'Inherits=%s,Adwaita,hicolor\n' "$base"
        printf 'Directories=%s\n' "''${dirs#,}"
        [ -n "$scaled" ] && printf 'ScaledDirectories=%s\n' "''${scaled#,}"
        printf '\n'
        # the [size/places] sections, as Papirus has them
        awk -v want="$dirs$scaled," '
          /^\[/ { d = substr($0, 2, length($0) - 2); keep = index(want, "," d ",") > 0 }
          keep
        ' $src/index.theme
      } > $dst/index.theme
    }

    ${lib.concatMapStrings one tints}
  ''
