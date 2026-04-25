xquery version "3.1";

declare namespace repo="http://exist-db.org/xquery/repo";

declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else ()
};

declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

local:mkcol("/db", "apps"),
local:mkcol("/db/apps", "antidote-menota-publisher")
