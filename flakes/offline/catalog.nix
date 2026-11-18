# What the offline library can hold, in sets. Books are Kiwix catalog ids:
# `<name>` or `<name>_<flavour>` (maxi = with pictures, nopic, mini), exactly
# as https://library.kiwix.org lists them. offline-sync always fetches the
# newest release of each. Sizes are approximate (Kiwix catalog, 2026-11).
{
  kiwix = {
    survival = {
      description = "Preparedness: water treatment, food and home canning, field medicine, knots, post-disaster books, prepper guides, Ready.gov, US Army field manuals";
      size = "27 GB";
      books = [
        "zimgit-post-disaster_en"
        "zimgit-water_en"
        "zimgit-food-preparation_en"
        "zimgit-medicine_en"
        "zimgit-knots_en"
        "wikipedia_en_knots_maxi"
        "trueprepper.com_en_all"
        "urban-prepper_en_all"
        "canadian-prepper_en_preppingfood"
        "canadian-prepper_en_winterprepping"
        "canadian-prepper_en_bugoutconcepts"
        "canadian-prepper_en_bugoutroll"
        "ready.gov_en_all"
        "lrnselfreliance_en_all"
        "usda-2015_en"
        "armypubs_en_all"
      ];
    };

    medical = {
      description = "WikiMed, MDWiki, MedlinePlus, military medicine, medicine textbooks, drug reference, veterinary";
      size = "9 GB";
      books = [
        "wikipedia_en_medicine_maxi"
        "mdwiki_en_all_maxi"
        "medlineplus.gov_en_all"
        "irp.fas.org_en_military-medicine"
        "libretexts.org_en_med"
        "nhs.uk_en_medicines"
        "medicalsciences.stackexchange.com_en_all"
        "quickguidesformedicine_en_all"
        "wikivet.net_en_all_maxi"
      ];
    };

    encyclopedia = {
      description = "Wikipedia with pictures, Wiktionary, Wikivoyage, Wikibooks (English)";
      size = "148 GB";
      books = [
        "wikipedia_en_all_maxi"
        "wiktionary_en_all_nopic"
        "wikivoyage_en_all_maxi"
        "wikibooks_en_all_maxi"
      ];
    };

    practical = {
      description = "Repair, appropriate technology and energy, and Q&A on DIY, electronics, growing food, cooking, outdoors, mechanics, radio";
      size = "14 GB";
      books = [
        "ifixit_en_all"
        "appropedia_en_all_maxi"
        "energypedia_en_all_maxi"
        "diy.stackexchange.com_en_all"
        "electronics.stackexchange.com_en_all"
        "gardening.stackexchange.com_en_all"
        "cooking.stackexchange.com_en_all"
        "outdoors.stackexchange.com_en_all"
        "sustainability.stackexchange.com_en_all"
        "mechanics.stackexchange.com_en_all"
        "bicycles.stackexchange.com_en_all"
        "engineering.stackexchange.com_en_all"
        "ham.stackexchange.com_en_all"
      ];
    };

    science = {
      description = "LibreTexts textbooks (biology, chemistry, physics, maths, engineering, geosciences, statistics) and science Q&A";
      size = "10 GB";
      books = [
        "libretexts.org_en_bio"
        "libretexts.org_en_chem"
        "libretexts.org_en_phys"
        "libretexts.org_en_math"
        "libretexts.org_en_eng"
        "libretexts.org_en_geo"
        "libretexts.org_en_stats"
        "physics.stackexchange.com_en_all"
        "chemistry.stackexchange.com_en_all"
        "biology.stackexchange.com_en_all"
      ];
    };

    computing = {
      description = "ArchWiki, Nix docs and Linux Q&A, to keep machines running";
      size = "8 GB";
      books = [
        "archlinux_en_all_maxi"
        "devdocs_en_nix"
        "unix.stackexchange.com_en_all"
        "askubuntu.com_en_all"
        "superuser.com_en_all"
      ];
    };

    books-practical = {
      description = "Project Gutenberg's agriculture, technology, science, medicine, military, naval and geography shelves";
      size = "37 GB";
      books = map (c: "gutenberg_en_lcc-${c}") [
        "g"
        "q"
        "r"
        "s"
        "t"
        "u"
        "v"
      ];
    };

    books-all = {
      description = "All of Project Gutenberg (English), every Library of Congress shelf";
      size = "173 GB";
      books = map (c: "gutenberg_en_lcc-${c}") [
        "a"
        "b"
        "cdef"
        "g"
        "h"
        "j"
        "k"
        "l"
        "m"
        "n"
        "p"
        "pa"
        "pb"
        "pc"
        "pd"
        "pe"
        "pf"
        "pg"
        "ph"
        "pj"
        "pk"
        "pl"
        "pm"
        "pn"
        "pq"
        "pr"
        "ps"
        "pt"
        "pz"
        "q"
        "r"
        "s"
        "t"
        "u"
        "v"
        "z"
      ];
    };

    survivor-library = {
      description = "Survivor Library: scanned books on pre-industrial skills and trades";
      size = "220 GB";
      books = [ "survivorlibrary.com_en_all" ];
    };

    khan-academy = {
      description = "Khan Academy videos and exercises, US curriculum (2023 snapshot)";
      size = "180 GB";
      books = [ "khanacademy_en_all" ];
    };

    swedish = {
      description = "Swedish Wikipedia with pictures and Wiktionary";
      size = "17 GB";
      books = [
        "wikipedia_sv_all_maxi"
        "wiktionary_sv_all_nopic"
      ];
    };

    arabic = {
      description = "Arabic Wikipedia with pictures";
      size = "19 GB";
      books = [ "wikipedia_ar_all_maxi" ];
    };
  };

  # Documents kept as files and served at /docs, as path = URL. Re-fetched
  # only when the server has a newer copy.
  docs =
    let
      # Hesperian lets anyone copy its books for non-commercial use, with credit
      wtnd = "https://hesperian.org/wp-content/uploads/pdf/en_wtnd_2025/en_wtnd_2025";
      book = "Where There Is No Doctor (Hesperian, 2025)";
      chapter = n: {
        name = "${book}/${n}.pdf";
        value = "${wtnd}_${n}.pdf";
      };
    in
    {
      # the national civil-defence brochure (MCF, formerly MSB), sent to every household
      "In case of crisis or war (MCF, English).pdf" = "https://rib.msb.se/filer/pdf/31523.pdf";
      "Om krisen eller kriget kommer (MCF, svenska).pdf" = "https://rib.msb.se/filer/pdf/30828.pdf";
      "${book}/00 Front matter.pdf" = "${wtnd}_fm.pdf";
      "${book}/24 Green pages (medicines).pdf" = "${wtnd}_gp.pdf";
      "${book}/25 Back matter.pdf" = "${wtnd}_bm.pdf";
    }
    // builtins.listToAttrs (
      map chapter (
        map (n: if n < 10 then "0${toString n}" else toString n) (builtins.genList (i: i + 1) 23)
      )
    );

  # Android apps served at /apps, so a phone can install them with no internet.
  apps = {
    # F-Droid package ids: the newest build for the phone's ABI, checked
    # against the SHA-256 in F-Droid's index
    fdroid = [
      "org.fdroid.fdroid" # F-Droid itself, for when the internet is back
      "app.comaps.fdroid" # offline maps with search and routing
      "app.organicmaps"
      "net.osmand.plus" # OsmAnd~: maps with contour lines, tracks
      "com.geeksville.mesh" # Meshtastic
      "org.briarproject.briar.android" # messaging over Wi-Fi/Bluetooth, no internet
      "com.kunzisoft.keepass.libre" # KeePassDX
      "org.videolan.vlc"
      "com.termux"
      "org.fossify.filemanager"
    ];
    # file name = URL, for apps F-Droid doesn't carry
    direct = {
      "Kiwix.apk" =
        "https://download.kiwix.org/release/kiwix-android/org.kiwix.kiwixmobile.standalone.apk";
    };
  };
}
