xquery version "3.1";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

declare variable $target external;
declare variable $home external;

declare variable $local:lib-path := "/db/apps/antidote-menota-publisher";
declare variable $local:compile-script := "compile-menota-odd.xql";

declare function local:resource-exists($path as xs:string) as xs:boolean {
    let $col := replace($path, "/[^/]+$", "")
    let $name := replace($path, "^.*/", "")
    return
        $col != "" and $name != ""
        and xmldb:collection-available($col)
        and $name = xmldb:get-child-resources($col)
};

declare function local:install-html($src-col as xs:string,
                                    $name as xs:string,
                                    $dest-col as xs:string) {
    if ($name = xmldb:get-child-resources($dest-col)) then
        xmldb:remove($dest-col, $name)
    else (),
    xmldb:copy-resource($src-col, $name, $dest-col, $name)
};

(: XQuery files: same remove-then-copy pattern as local:install-html. :)
declare function local:install-xql($src-col as xs:string,
                                   $name as xs:string,
                                   $dest-col as xs:string) {
    if ($name = xmldb:get-child-resources($dest-col)) then
        xmldb:remove($dest-col, $name)
    else (),
    xmldb:copy-resource($src-col, $name, $dest-col, $name)
};

(:~ All package URIs that identify a TEI Publisher host or library across versions. :)
declare variable $local:tei-publisher-uris := (
    "http://existsolutions.com/apps/tei-publisher",
    "http://existsolutions.com/apps/tei-publisher-lib",
    "http://existsolutions.com/teipublisher",
    "http://existsolutions.com/teipublisher/v1",
    "http://existsolutions.com/teipublisher/v2",
    "http://existsolutions.com/teipublisher/v3",
    "http://existsolutions.com/teipublisher/v4",
    "http://existsolutions.com/teipublisher/v5",
    "http://existsolutions.com/teipublisher/v6",
    "http://existsolutions.com/teipublisher/v7",
    "http://existsolutions.com/teipublisher/v8",
    "http://existsolutions.com/teipublisher/v9",
    "http://existsolutions.com/teipublisher/v10"
);

declare function local:find-tei-publisher-apps() as xs:string* {
    let $all-apps := xmldb:get-child-collections("/db/apps")

    (: Apps identified via their expath-pkg.xml :)
    let $by-pkg :=
        for $app in $all-apps
        let $pkg-path := concat("/db/apps/", $app, "/expath-pkg.xml")
        where doc-available($pkg-path)
        let $pkg := doc($pkg-path)/expath:package
        where $pkg/@name != "https://antidote.hi.is/ns/menota-publisher-lib"
          and (
            $pkg/@name = $local:tei-publisher-uris or
            $pkg/expath:dependency[@package = $local:tei-publisher-uris]
          )
        return concat("/db/apps/", $app)

    (: Apps where menota.odd was already installed by a previous run —
       include them regardless of how their package declares its lineage. :)
    let $by-odd :=
        for $app in $all-apps
        let $app-path := concat("/db/apps/", $app)
        where $app-path != $local:lib-path
          and doc-available(concat($app-path, "/odd/menota.odd"))
          and not($app-path = $by-pkg)
        return $app-path

    return distinct-values(($by-pkg, $by-odd))
};

declare function local:install-odd-into($app-path as xs:string) {
    let $odd-collection := concat($app-path, "/odd")
    let $source := concat($local:lib-path, "/odd/menota.odd")
    return
        if (not(doc-available($source))) then
            util:log("WARN", "[antidote-menota-publisher] Source menota.odd missing in lib - cannot install")
        else
            try {
                let $_mk :=
                    if (not(xmldb:collection-available($odd-collection))) then
                        xmldb:create-collection($app-path, "odd")
                    else ()
                return (
                    if (doc-available($odd-collection || "/menota.odd")) then
                        xmldb:remove($odd-collection, "menota.odd")
                    else (),
                    xmldb:copy-resource($local:lib-path || "/odd", "menota.odd",
                                        $odd-collection, "menota.odd"),
                    util:log("INFO", "[antidote-menota-publisher] Installed menota.odd into " || $odd-collection)
                )
            } catch * {
                util:log("WARN", "[antidote-menota-publisher] Could not copy menota.odd into "
                                  || $odd-collection || ": " || $err:description)
            }
};

declare function local:install-template-into($app-path as xs:string) {
    let $candidates := (
        concat($app-path, "/templates/pages"),
        concat($app-path, "/templates")
    )
    let $tpl-collection := head(
        for $c in $candidates
        where xmldb:collection-available($c)
        return $c
    )
    let $source := concat($local:lib-path, "/templates/menota-document.html")
    let $snippet-source := concat($local:lib-path, "/templates/snippets/level-switcher.html")
    let $module-source := concat($local:lib-path, "/modules/get-levels.xql")

    return (
        if (exists($tpl-collection) and local:resource-exists($source)) then
            try {
                let $_doc := local:install-html(
                    $local:lib-path || "/templates",
                    "menota-document.html",
                    $tpl-collection)
                let $_doc-log := util:log("INFO",
                    "[antidote-menota-publisher] Installed menota-document.html into "
                    || $tpl-collection)

                let $grid-source :=
                    concat($local:lib-path, "/templates/menota-document-grid.html")
                let $_grid :=
                    if (local:resource-exists($grid-source)) then (
                        local:install-html(
                            $local:lib-path || "/templates",
                            "menota-document-grid.html",
                            $tpl-collection),
                        util:log("INFO",
                            "[antidote-menota-publisher] Installed menota-document-grid.html into "
                            || $tpl-collection)
                    ) else ()

                let $_snippet :=
                    if (local:resource-exists($snippet-source)) then (
                        let $snippet-col := concat($app-path, "/templates/snippets")
                        let $_mk :=
                            if (not(xmldb:collection-available($snippet-col))) then
                                xmldb:create-collection(
                                    concat($app-path, "/templates"), "snippets")
                            else ()
                        let $_copy := local:install-html(
                            $local:lib-path || "/templates/snippets",
                            "level-switcher.html",
                            $snippet-col)
                        return
                            util:log("INFO",
                                "[antidote-menota-publisher] Installed level-switcher.html into "
                                || $snippet-col)
                    ) else ()
                return ()
            } catch * {
                util:log("WARN", "[antidote-menota-publisher] Could not copy templates into "
                                  || $tpl-collection || ": " || $err:description)
            }
        else
            util:log("INFO", "[antidote-menota-publisher] Skipping template install for " || $app-path
                              || " - no templates/ or templates/pages/ collection found"),

        if (xmldb:collection-available(concat($app-path, "/modules"))) then
            try {
                let $mod-col := concat($app-path, "/modules")
                let $_ := util:log("INFO", "[antidote-menota-publisher] Installing get-levels.xql into " || $mod-col)
                return (
                    local:install-xql($local:lib-path || "/modules", "get-levels.xql", $mod-col),
                    util:log("INFO", "[antidote-menota-publisher] Installed get-levels.xql into " || $mod-col)
                )
            } catch * {
                util:log("WARN", "[antidote-menota-publisher] Could not install get-levels.xql into modules/: " || $err:description)
            }
        else
            util:log("INFO", "[antidote-menota-publisher] Skipping get-levels.xql - no modules/ collection in " || $app-path),

        let $js-source := concat($local:lib-path, "/resources/js/menota-level-switcher.js")
        let $resources := concat($app-path, "/resources")
        let $js-col := concat($resources, "/js")
        return
            if (util:binary-doc-available($js-source) and xmldb:collection-available($resources)) then
                try {
                    if (not(xmldb:collection-available($js-col))) then
                        xmldb:create-collection($resources, "js")
                    else (),
                    if (util:binary-doc-available($js-col || "/menota-level-switcher.js")) then
                        xmldb:remove($js-col, "menota-level-switcher.js")
                    else (),
                    xmldb:copy-resource($local:lib-path || "/resources/js", "menota-level-switcher.js",
                                        $js-col, "menota-level-switcher.js"),
                    util:log("INFO", "[antidote-menota-publisher] Installed menota-level-switcher.js into " || $js-col)
                } catch * {
                    util:log("WARN", "[antidote-menota-publisher] Could not copy menota-level-switcher.js: "
                                      || $err:description)
                }
            else (),

        (: ── CSS files ─────────────────────────────────────────────────
           menota.css   : always overwritten so the lib version is current.
           menota-custom.css : copied only on first install so user edits
                               survive a package upgrade. :)
        let $css-lib := concat($local:lib-path, "/resources/css")
        let $css-col := concat($app-path, "/resources/css")
        return
            if (xmldb:collection-available($css-col)) then
                try {
                    (: menota.css — always replace :)
                    let $_css :=
                        if (util:binary-doc-available($css-col || "/menota.css")) then
                            xmldb:remove($css-col, "menota.css")
                        else ()
                    let $_css-copy :=
                        xmldb:copy-resource($css-lib, "menota.css", $css-col, "menota.css")
                    let $_css-log :=
                        util:log("INFO", "[antidote-menota-publisher] Installed menota.css into " || $css-col)

                    (: menota-custom.css — only if absent :)
                    let $_custom :=
                        if (not(util:binary-doc-available($css-col || "/menota-custom.css"))) then (
                            xmldb:copy-resource($css-lib, "menota-custom.css", $css-col, "menota-custom.css"),
                            util:log("INFO", "[antidote-menota-publisher] Installed starter menota-custom.css into " || $css-col)
                        ) else
                            util:log("INFO", "[antidote-menota-publisher] menota-custom.css already exists in " || $css-col || " - skipping")
                    return ()
                } catch * {
                    util:log("WARN", "[antidote-menota-publisher] Could not copy CSS files: "
                                      || $err:description)
                }
            else
                util:log("INFO", "[antidote-menota-publisher] No " || $css-col || " collection - skipping CSS install")
    )
};

(: The compile script must live in modules/lib/api/ so that
   pmu:fix-module-paths in tei-publisher-lib resolves
   "../modules/odd-global.xqm" against the host app's modules/. :)
declare function local:install-compile-script-into($app-path as xs:string) as xs:string? {
    let $mod-col := concat($app-path, "/modules/lib/api")
    let $src := $local:lib-path || "/modules/" || $local:compile-script
    return
        if (not(xmldb:collection-available($mod-col))) then (
            util:log("WARN", "[antidote-menota-publisher] No " || $mod-col
                              || " - cannot install compile script"),
            ()
        )
        else
            try {
                let $_ := util:log("INFO", "[antidote-menota-publisher] Installing " || $local:compile-script || " into " || $mod-col)
                (: Remove stale copy from old location (modules/) if present :)
                let $stale := concat($app-path, "/modules/", $local:compile-script)
                let $_old :=
                    if (local:resource-exists($stale)) then
                        xmldb:remove(concat($app-path, "/modules"), $local:compile-script)
                    else ()
                let $_copy :=
                    local:install-xql($local:lib-path || "/modules", $local:compile-script, $mod-col)
                let $_log :=
                    util:log("INFO", "[antidote-menota-publisher] Installed " || $local:compile-script
                                      || " into " || $mod-col)
                return
                    $mod-col || "/" || $local:compile-script
            } catch * {
                util:log("WARN", "[antidote-menota-publisher] Could not install compile script: "
                                  || $err:description),
                ()
            }
};

declare function local:compile-odd-into($app-path as xs:string, $script-path as xs:string?) {
    let $transform-root := concat($app-path, "/transform")
    let $odd-source := concat($app-path, "/odd/menota.odd")
    return
        if (empty($script-path)) then
            util:log("WARN", "[antidote-menota-publisher] Compile script not installed - skipping ODD compilation")
        else if (not(doc-available($odd-source))) then
            util:log("WARN", "[antidote-menota-publisher] menota.odd not found at " || $odd-source)
        else (
            if (not(xmldb:collection-available($transform-root))) then
                xmldb:create-collection($app-path, "transform")
            else (),
            try {
                let $script-uri := xs:anyURI("xmldb:exist://" || $script-path)
                let $result := util:eval($script-uri, false())
                let $errors := $result//module[@status = "error"]
                return
                    if (exists($errors)) then
                        util:log("WARN", "[antidote-menota-publisher] ODD compile produced errors: "
                                          || string-join(
                                                $errors ! (string(@name) || ": " || string(error)),
                                                "; "))
                    else
                        util:log("INFO", "[antidote-menota-publisher] Compiled menota.odd into "
                                          || $transform-root || " ("
                                          || string-join($result//module/@name/string(), ", ")
                                          || ")")
            } catch * {
                util:log("WARN", "[antidote-menota-publisher] Failed to compile menota.odd: "
                                  || $err:description
                                  || " - open the ODD editor and click Recompile")
            }
        )
};

let $hosts := local:find-tei-publisher-apps()
return
    if (empty($hosts)) then
        util:log("INFO", "[antidote-menota-publisher] No TEI Publisher app detected. "
                          || "menota.odd remains in " || $local:lib-path || "/odd/ "
                          || "and can be copied manually into your app's odd/ collection.")
    else
        for $host in $hosts
        return (
            local:install-odd-into($host),
            local:install-template-into($host),
            local:compile-odd-into($host, local:install-compile-script-into($host))
        )
