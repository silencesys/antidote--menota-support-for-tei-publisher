xquery version "3.1";

(: Compiles menota.odd via pmu:process-odd for each output mode.
   Must live in the host app's modules/lib/api/ so pmu:fix-module-paths
   resolves "../modules/odd-global.xqm" against the host app. :)

import module namespace pmu="http://www.tei-c.org/tei-simple/xquery/util";
import module namespace odd="http://www.tei-c.org/tei-simple/odd2odd";
import module namespace config="http://www.tei-c.org/tei-simple/config"
    at "../../config.xqm";

declare variable $local:modules := ("web", "print", "latex", "epub", "fo");

let $cfg := $config:module-config
let $oddRoot := $config:odd-root
let $outRoot := $config:output-root
return
    <compile-menota-odd>
        {
            for $mode in $local:modules
            let $result :=
                try {
                    pmu:process-odd(
                        odd:get-compiled($oddRoot, "menota.odd"),
                        $outRoot,
                        $mode,
                        "transform",
                        $cfg,
                        $mode = "web"
                    )
                } catch * {
                    map { "error": $err:description }
                }
            return
                <module name="{$mode}">
                    {
                        if (map:contains($result, "error")) then
                            attribute status { "error" }
                        else if (map:contains($result, "main")) then
                            attribute status { "ok" }
                        else
                            attribute status { "unknown" },
                        if (map:contains($result, "error")) then
                            <error>{
                                if ($result?error instance of node()) then
                                    serialize($result?error)
                                else
                                    string($result?error)
                            }</error>
                        else if (map:contains($result, "main")) then
                            <main>{ string($result?main) }</main>
                        else
                            ()
                    }
                </module>
        }
    </compile-menota-odd>
