xquery version "3.1";

module namespace apimenota="http://teipublisher.com/api/custom/menota";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace me="http://www.menota.org/ns/1.0";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare function apimenota:resolve-doc($id as xs:string, $app as xs:string?) as document-node()? {
    let $decoded := xmldb:decode($id)
    let $module-uri := static-base-uri()
    let $module-col := replace($module-uri, "^(xmldb:exist://)?", "") => replace("/[^/]+$", "")
    let $app-root := substring-before($module-col, "/modules")
    let $candidates := (
        if ($app) then "/db/apps/" || $app || "/data/" || $decoded else (),
        if ($app) then "/db/apps/" || $app || "/" || $decoded else (),
        $decoded,
        "/db/" || $decoded,
        $app-root || "/data/" || $decoded,
        "/db/apps/tei-publisher/data/" || $decoded,
        "/db/apps/" || $decoded
    )
    let $direct := (
        for $c in $candidates
        where doc-available($c)
        return $c
    )[1]
    return
        if (exists($direct)) then
            doc($direct)
        else
            let $name := tokenize($decoded, "/")[last()]
            let $roots := (
                for $c in xmldb:get-child-collections("/db/apps")
                return "/db/apps/" || $c,
                for $c in xmldb:get-child-collections("/db")
                where $c != "apps" and $c != "system"
                return "/db/" || $c
            )
            let $hits :=
                for $root in $roots
                where xmldb:collection-available($root)
                return
                    collection($root)/*[
                        util:document-name(.) = $name
                    ]/root()
            return $hits[1]
};

declare
    %rest:GET
    %rest:path("/menota/levels/{$id}")
    %rest:query-param("app", "{$app}")
    %rest:produces("application/json")
    %output:method("json")
function apimenota:get-levels($id as xs:string*, $app as xs:string*) {
    let $doc := apimenota:resolve-doc($id, head($app))
    return
        if (empty($doc)) then
            array { }
        else
            let $has-dipl := exists($doc//me:dipl)
            let $has-facs := exists($doc//me:facs)
            let $has-norm := exists($doc//me:norm)
            let $has-pal := exists($doc//me:pal)
            let $header-levels := tokenize($doc//tei:normalization/@me:level, "\s+")
            let $levels := (
                if ($has-dipl or "dipl" = $header-levels) then "me:dipl" else (),
                if ($has-facs or "facs" = $header-levels) then "me:facs" else (),
                if ($has-norm or "norm" = $header-levels) then "me:norm" else (),
                if ($has-pal or "pal" = $header-levels) then "me:pal" else ()
            )
            let $final-levels := if (empty($levels)) then "me:dipl" else $levels
            return array { $final-levels }
};
