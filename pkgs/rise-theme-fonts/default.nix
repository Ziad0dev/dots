{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Type for the desktop and lock themes ported from dhrruvsharma/shell into
# rise (config/quickshell/rise/ext): the Google Fonts its installer fetches
# (Art Deco, Cathedral, Broadsheet, Wasteland, Observatory, Abyss, Devaloka,
# Siege, HUD), and Alegreya Sans, rise's body text in the grimoire look,
# pinned to one google/fonts revision. All OFL or Apache-2.0.
let
  rev = "5e8a3ba899557829a76cfdac30fa512bda91d7ca";
  base = "https://raw.githubusercontent.com/google/fonts/${rev}";
in
stdenvNoCC.mkDerivation {
  pname = "rise-theme-fonts";
  version = "0-unstable-2026-10-08";

  srcs = [
    (fetchurl {
      name = "AlegreyaSans-Regular.ttf";
      url = "${base}/ofl/alegreyasans/AlegreyaSans-Regular.ttf";
      hash = "sha256-j6tjQZYAevyoOfHlpvswCXba/1XYUotZDvAy8BsU6hA=";
    })
    (fetchurl {
      name = "AlegreyaSans-Italic.ttf";
      url = "${base}/ofl/alegreyasans/AlegreyaSans-Italic.ttf";
      hash = "sha256-9J9vK92E34ULJbD4GF2KBR4dHrLdCOL5G4x7htmp4aY=";
    })
    (fetchurl {
      name = "AlegreyaSans-Medium.ttf";
      url = "${base}/ofl/alegreyasans/AlegreyaSans-Medium.ttf";
      hash = "sha256-S4n+eAT9FIXsJ1d5WlP/22bhIG3Vb4RMLXKzyUSBW0M=";
    })
    (fetchurl {
      name = "AlegreyaSans-MediumItalic.ttf";
      url = "${base}/ofl/alegreyasans/AlegreyaSans-MediumItalic.ttf";
      hash = "sha256-DHnaRirmN9f5X0KMk1ysepwiy5llXFzTe4cICGHdc+w=";
    })
    (fetchurl {
      name = "AlegreyaSans-Bold.ttf";
      url = "${base}/ofl/alegreyasans/AlegreyaSans-Bold.ttf";
      hash = "sha256-owVaGJN1m9vXUEuyKrxYN2nnl0xJNTF26sCwN5LJ+44=";
    })
    (fetchurl {
      name = "AlegreyaSans-BoldItalic.ttf";
      url = "${base}/ofl/alegreyasans/AlegreyaSans-BoldItalic.ttf";
      hash = "sha256-alVQ8OTDAh5+LoOsSBToxkmg/iA4VInOdgnwCAIJe00=";
    })
    (fetchurl {
      name = "SpecialElite-Regular.ttf";
      url = "${base}/apache/specialelite/SpecialElite-Regular.ttf";
      hash = "sha256-p3b8tM64vfA+KWdojr2tQmgN5bkafmLBfnGK4hLRS8Q=";
    })
    (fetchurl {
      name = "Alegreya-Italic-wght.ttf";
      url = "${base}/ofl/alegreya/Alegreya-Italic%5Bwght%5D.ttf";
      hash = "sha256-+pFe7HYieTXcX7Z4lTyUtxKHw2CSgBPP20Qd/lL1o5E=";
    })
    (fetchurl {
      name = "Alegreya-wght.ttf";
      url = "${base}/ofl/alegreya/Alegreya%5Bwght%5D.ttf";
      hash = "sha256-ulVkY0uTqPi6V7SM1PGudBfStGVvusd5AoZ5sA3jzxI=";
    })
    (fetchurl {
      name = "Anton-Regular.ttf";
      url = "${base}/ofl/anton/Anton-Regular.ttf";
      hash = "sha256-pLo6kjUOuwMdoMtHYwrEnrJlCCyhvARQRC9Kg6uUfKs=";
    })
    (fetchurl {
      name = "B612-Bold.ttf";
      url = "${base}/ofl/b612/B612-Bold.ttf";
      hash = "sha256-kXSVQax7LDKLWIMrfixN+AnX4ro41io6WqP444snGBQ=";
    })
    (fetchurl {
      name = "B612-BoldItalic.ttf";
      url = "${base}/ofl/b612/B612-BoldItalic.ttf";
      hash = "sha256-WRH+CuaSZPt0spVvxmxhZYDNOStH8pM1+mjOXbR6TS8=";
    })
    (fetchurl {
      name = "B612-Italic.ttf";
      url = "${base}/ofl/b612/B612-Italic.ttf";
      hash = "sha256-V/2KDTyLrwZvIcCjA0ryd4h6Cxe4wYy7zBxkJkDdFJ8=";
    })
    (fetchurl {
      name = "B612-Regular.ttf";
      url = "${base}/ofl/b612/B612-Regular.ttf";
      hash = "sha256-E53OZZEAqDv5W0hHRpbkSL7pVjHvhP09BDfO0r8zz3M=";
    })
    (fetchurl {
      name = "B612Mono-Bold.ttf";
      url = "${base}/ofl/b612mono/B612Mono-Bold.ttf";
      hash = "sha256-tGex0Z/avtQr5R2H44yGZFzu/y+CjylHdRiNANH9aMo=";
    })
    (fetchurl {
      name = "B612Mono-BoldItalic.ttf";
      url = "${base}/ofl/b612mono/B612Mono-BoldItalic.ttf";
      hash = "sha256-kaaoU1/GE1SixZpk6iBaT2lXwuCaxP+Rofxh00bABOE=";
    })
    (fetchurl {
      name = "B612Mono-Italic.ttf";
      url = "${base}/ofl/b612mono/B612Mono-Italic.ttf";
      hash = "sha256-1Y+oB+adGBWaQNV5DSV3IjnfIBZ7UKD4QOn+slMALJw=";
    })
    (fetchurl {
      name = "B612Mono-Regular.ttf";
      url = "${base}/ofl/b612mono/B612Mono-Regular.ttf";
      hash = "sha256-uYy5bMimIG2uCMBj1gkC335tQPhhOevblyVnBCU8nGk=";
    })
    (fetchurl {
      name = "BarlowCondensed-Bold.ttf";
      url = "${base}/ofl/barlowcondensed/BarlowCondensed-Bold.ttf";
      hash = "sha256-5HZWLsnB4WzxZHWJW1EfCMgE9DjMmp+ApE6lCg7rW2U=";
    })
    (fetchurl {
      name = "BarlowCondensed-Medium.ttf";
      url = "${base}/ofl/barlowcondensed/BarlowCondensed-Medium.ttf";
      hash = "sha256-JivRQyks5HnuDNCaQrR6sXP8qOnG617QtcioRbw3HRc=";
    })
    (fetchurl {
      name = "BarlowCondensed-Regular.ttf";
      url = "${base}/ofl/barlowcondensed/BarlowCondensed-Regular.ttf";
      hash = "sha256-WDzsXaO4S8TcfJxy4qVlyU005DFRixnX4lC3gwrV+ZY=";
    })
    (fetchurl {
      name = "BarlowCondensed-SemiBold.ttf";
      url = "${base}/ofl/barlowcondensed/BarlowCondensed-SemiBold.ttf";
      hash = "sha256-e2GdFLwjJ1CanvMrCJD3CWJvfsyf9hGRwqQxTFSZ0tk=";
    })
    (fetchurl {
      name = "BarlowSemiCondensed-Bold.ttf";
      url = "${base}/ofl/barlowsemicondensed/BarlowSemiCondensed-Bold.ttf";
      hash = "sha256-W9Z1fkWaEQ2oG0RTLw9DBY4tqyQBaIq8qE8v294ZPLs=";
    })
    (fetchurl {
      name = "BarlowSemiCondensed-Italic.ttf";
      url = "${base}/ofl/barlowsemicondensed/BarlowSemiCondensed-Italic.ttf";
      hash = "sha256-bOKCBMikg2nyVAVfzPF4T+EOx/zCb4SjANUWXd/Aywo=";
    })
    (fetchurl {
      name = "BarlowSemiCondensed-Medium.ttf";
      url = "${base}/ofl/barlowsemicondensed/BarlowSemiCondensed-Medium.ttf";
      hash = "sha256-SZi2k6GQt28rETFYRDRahUbB4uajIJBVB6nu0E7fi0g=";
    })
    (fetchurl {
      name = "BarlowSemiCondensed-Regular.ttf";
      url = "${base}/ofl/barlowsemicondensed/BarlowSemiCondensed-Regular.ttf";
      hash = "sha256-6MckL2ErE9Am4YqUtjsP0HnpGj+vAJ0baYHbtfFtEVM=";
    })
    (fetchurl {
      name = "BarlowSemiCondensed-SemiBold.ttf";
      url = "${base}/ofl/barlowsemicondensed/BarlowSemiCondensed-SemiBold.ttf";
      hash = "sha256-vSmfS8W0TTC+jULputOl331mrxzVXQ7XKouJFjYKFCQ=";
    })
    (fetchurl {
      name = "BigShouldersStencil-opsz-wght.ttf";
      url = "${base}/ofl/bigshouldersstencil/BigShouldersStencil%5Bopsz%2Cwght%5D.ttf";
      hash = "sha256-dY7IgClqi9r3NqMfxX6Q+hZnPYw1fvw8Nr22WC1iXwo=";
    })
    (fetchurl {
      name = "Cinzel-wght.ttf";
      url = "${base}/ofl/cinzel/Cinzel%5Bwght%5D.ttf";
      hash = "sha256-9Ng9NNH2x0EZPkrPSz3/lTHlpntqplIo0Ap9typODzQ=";
    })
    (fetchurl {
      name = "EBGaramond-Italic-wght.ttf";
      url = "${base}/ofl/ebgaramond/EBGaramond-Italic%5Bwght%5D.ttf";
      hash = "sha256-u6LESZyTyWErkLmCXTKwfaUvzi/ldWKh62uDNVP5PE4=";
    })
    (fetchurl {
      name = "EBGaramond-wght.ttf";
      url = "${base}/ofl/ebgaramond/EBGaramond%5Bwght%5D.ttf";
      hash = "sha256-75US+S9tV55dx1r1mlpLG4tH0u2ongC5VNRFIOU2kCc=";
    })
    (fetchurl {
      name = "Eczar-wght.ttf";
      url = "${base}/ofl/eczar/Eczar%5Bwght%5D.ttf";
      hash = "sha256-tSrzo7RX+bInhhK3PJfq8oJw/8kcmeTJBHHMFbuHSMY=";
    })
    (fetchurl {
      name = "GermaniaOne-Regular.ttf";
      url = "${base}/ofl/germaniaone/GermaniaOne-Regular.ttf";
      hash = "sha256-PuPVZYS6uMnj9ZzDNgqoo24hnc8KnzyJKOPaWhknfj8=";
    })
    (fetchurl {
      name = "IMFeENit28P.ttf";
      url = "${base}/ofl/imfellenglish/IMFeENit28P.ttf";
      hash = "sha256-R8113OVLHy4IMTWdItXmiPUZ1orkVwa2ZP0xD9DjzPc=";
    })
    (fetchurl {
      name = "IMFeENrm28P.ttf";
      url = "${base}/ofl/imfellenglish/IMFeENrm28P.ttf";
      hash = "sha256-/pcFu95Rr4AnGSRtRgjQjTe96VarmdmlkNqZalIhokw=";
    })
    (fetchurl {
      name = "IMFeENsc28P.ttf";
      url = "${base}/ofl/imfellenglishsc/IMFeENsc28P.ttf";
      hash = "sha256-ECMk+1Q0u12nljUzQmsK1EyFu8nndVBnU1ydEUZKF2s=";
    })
    (fetchurl {
      name = "JosefinSans-Italic-wght.ttf";
      url = "${base}/ofl/josefinsans/JosefinSans-Italic%5Bwght%5D.ttf";
      hash = "sha256-witCymkL5+oH0EQVrHC0hgPf+I6FRzjLpL2HAnuQXvE=";
    })
    (fetchurl {
      name = "JosefinSans-wght.ttf";
      url = "${base}/ofl/josefinsans/JosefinSans%5Bwght%5D.ttf";
      hash = "sha256-klWr2185O8UeEBq70Hpxapd/0+FUcrG4SyYPQmo0K/0=";
    })
    (fetchurl {
      name = "Limelight-Regular.ttf";
      url = "${base}/ofl/limelight/Limelight-Regular.ttf";
      hash = "sha256-9b+KkVmt/FucdWyF2BKk/RKZuJFv7985rUskrebY0M8=";
    })
    (fetchurl {
      name = "Michroma-Regular.ttf";
      url = "${base}/ofl/michroma/Michroma-Regular.ttf";
      hash = "sha256-tiMBFjeIvFt/j8rAt0sYTjThgn5Xe0mey3JNoGUJj4c=";
    })
    (fetchurl {
      name = "OldStandard-Bold.ttf";
      url = "${base}/ofl/oldstandardtt/OldStandard-Bold.ttf";
      hash = "sha256-fYMenXma0j7pjoiTganbKig7Lax/Io3VwGBx3sucVNs=";
    })
    (fetchurl {
      name = "OldStandard-Italic.ttf";
      url = "${base}/ofl/oldstandardtt/OldStandard-Italic.ttf";
      hash = "sha256-S5Ui9HETF/wG4kE6WLRmLCSctwffGT1oK51kDjZe9WQ=";
    })
    (fetchurl {
      name = "OldStandard-Regular.ttf";
      url = "${base}/ofl/oldstandardtt/OldStandard-Regular.ttf";
      hash = "sha256-QnF6EoC1I6UGyisChcyjgOd/4hSx9uPXWouSUAXxnqw=";
    })
    (fetchurl {
      name = "Orbitron-wght.ttf";
      url = "${base}/ofl/orbitron/Orbitron%5Bwght%5D.ttf";
      hash = "sha256-9C2y3RbmQiWONXgpFuzrHc2+oG+5WNd61x3FljWH6P0=";
    })
    (fetchurl {
      name = "PlayfairDisplay-Italic-wght.ttf";
      url = "${base}/ofl/playfairdisplay/PlayfairDisplay-Italic%5Bwght%5D.ttf";
      hash = "sha256-peJtxeLnf7KAOgvwL9T4HuE27I3qhjzNsMWaJjshN4s=";
    })
    (fetchurl {
      name = "PlayfairDisplay-wght.ttf";
      url = "${base}/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf";
      hash = "sha256-xA8ik3ZqUDvHDM6eUS74RKTMt8vN55L+LqMdGRkX2NY=";
    })
    (fetchurl {
      name = "PoiretOne-Regular.ttf";
      url = "${base}/ofl/poiretone/PoiretOne-Regular.ttf";
      hash = "sha256-RX8tAyY/WOWm28wbYHsQ3/ZYHnz5xOvfMw7D5ncqNVg=";
    })
    (fetchurl {
      name = "StardosStencil-Bold.ttf";
      url = "${base}/ofl/stardosstencil/StardosStencil-Bold.ttf";
      hash = "sha256-axX1Cxs1hRLZIrXxGTevF+kHBFh+HX+wCfFxXS1d+nQ=";
    })
    (fetchurl {
      name = "StardosStencil-Regular.ttf";
      url = "${base}/ofl/stardosstencil/StardosStencil-Regular.ttf";
      hash = "sha256-IIsT0VOHwoKhwMQ5qOTDiAkkPRXDYbMdpECyWn5POa4=";
    })
    (fetchurl {
      name = "Texturina-Italic-opsz-wght.ttf";
      url = "${base}/ofl/texturina/Texturina-Italic%5Bopsz%2Cwght%5D.ttf";
      hash = "sha256-1YJ+ZTFRDpteKpXzBC7nRjsLHzIPmkFGFZpVNIL24zk=";
    })
    (fetchurl {
      name = "Texturina-opsz-wght.ttf";
      url = "${base}/ofl/texturina/Texturina%5Bopsz%2Cwght%5D.ttf";
      hash = "sha256-R4oV1xRc+UVlz8GuszWWrrARjH2GqE0GHd9G3j19/aM=";
    })
    (fetchurl {
      name = "TiroDevanagariSanskrit-Italic.ttf";
      url = "${base}/ofl/tirodevanagarisanskrit/TiroDevanagariSanskrit-Italic.ttf";
      hash = "sha256-lkGRQDIVTqaKfK7RADIM9UfWOJGh45YgM7qR3JwzrCs=";
    })
    (fetchurl {
      name = "TiroDevanagariSanskrit-Regular.ttf";
      url = "${base}/ofl/tirodevanagarisanskrit/TiroDevanagariSanskrit-Regular.ttf";
      hash = "sha256-da6HPl4/nDD7lio9KDufXnvFvKV4IqKqkmdTspexUMo=";
    })
    (fetchurl {
      name = "UnifrakturMaguntia-Book.ttf";
      url = "${base}/ofl/unifrakturmaguntia/UnifrakturMaguntia-Book.ttf";
      hash = "sha256-1kr8BUcFndLkp42ki9oKugqZAb5Yx/jCAaiytrRJLMg=";
    })
  ];

  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    for f in $srcs; do
      install -Dm644 "$f" "$out/share/fonts/truetype/''${f#*-}"
    done
    runHook postInstall
  '';

  meta = {
    description = "Google Fonts used by rise's desktop and lock themes";
    homepage = "https://github.com/google/fonts";
    license = with lib.licenses; [
      ofl
      asl20
    ];
    platforms = lib.platforms.all;
  };
}
