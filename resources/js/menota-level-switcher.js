/* <menota-level-switcher>: TEI Publisher pb-select for MENOTA levels.
   See README for attributes, CSS custom properties and events. */

(function () {
    "use strict";

    if (window.customElements && customElements.get("menota-level-switcher")) {
        return;
    }

    var DEFAULT_LEVELS = [
        { val: "dipl", tag: "me:dipl", label: "Diplomatic" },
        { val: "facs", tag: "me:facs", label: "Facsimile" },
        { val: "norm", tag: "me:norm", label: "Normalised" },
        { val: "pal",  tag: "me:pal",  label: "Palaeographic" }
    ];

    var STYLE = [
        ":host {",
        "  display: block;",
        "  background: var(--menota-switcher-bg, #fff);",
        "  border-bottom: var(--menota-switcher-border-bottom, 1px solid #eaecef);",
        "  padding: var(--menota-switcher-padding, 0.625rem 1.25rem);",
        "  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,",
        "    Helvetica, Arial, sans-serif;",
        "}",
        ".row {",
        "  display: flex;",
        "  flex-direction: row;",
        "  align-items: center;",
        "  gap: var(--menota-switcher-gap, 0.875rem);",
        "}",
        ".label {",
        "  font-size: var(--menota-switcher-label-size, 0.8125rem);",
        "  line-height: 1;",
        "  letter-spacing: 0.02em;",
        "  text-transform: uppercase;",
        "  color: var(--menota-switcher-label-color, #6b7280);",
        "  font-weight: 600;",
        "  white-space: nowrap;",
        "  flex-shrink: 0;",
        "}",
        ".label[hidden] { display: none; }",
        "::slotted(pb-select), .select-host {",
        "  flex: 1 1 auto;",
        "  min-width: 0;",
        "  width: 100%;",
        "  margin: 0;",
        "}"
    ].join("\n");

    function buildShadowCss(width) {
        return [
            ":host { margin: 0 !important; }",
            "paper-listbox, paper-listbox.dropdown-content {",
            "  width: " + width + "px !important;",
            "  min-width: " + width + "px !important;",
            "  box-sizing: border-box;",
            "  padding: 4px 0 !important;",
            "  background: #ffffff !important;",
            "  border: 1px solid #e5e7eb !important;",
            "  border-radius: 6px !important;",
            "  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.08) !important;",
            "}",
            "paper-item {",
            "  font-size: 0.9375rem !important;",
            "  min-height: 36px !important;",
            "  padding: 0 14px !important;",
            "  color: #1f2937 !important;",
            "}",
            ".floated-label-placeholder { display: none !important; }",
            "paper-input-container { padding: 0 !important; }",
            ".underline { display: none !important; }",
            ".input-content {",
            "  border: 1px solid #d1d5db !important;",
            "  border-radius: 6px !important;",
            "  padding: 6px 10px !important;",
            "  background: #ffffff !important;",
            "}",
            "input, .paper-input-input, iron-input {",
            "  font-size: 0.9375rem !important;",
            "  color: #1f2937 !important;",
            "}"
        ].join("\n");
    }

    function applyShadowStyles(host) {
        function upsert(root, css) {
            if (!root || root.nodeType !== Node.DOCUMENT_FRAGMENT_NODE) return;
            var s = root.querySelector && root.querySelector("style[data-menota-shadow]");
            if (!s) {
                s = document.createElement("style");
                s.setAttribute("data-menota-shadow", "");
                root.appendChild(s);
            }
            s.textContent = css;
            root.querySelectorAll("*").forEach(function (el) {
                if (el.shadowRoot) upsert(el.shadowRoot, css);
            });
        }

        function refresh() {
            if (!host.shadowRoot) return;
            var w = Math.round(host.getBoundingClientRect().width);
            if (w <= 0) return;
            upsert(host.shadowRoot, buildShadowCss(w));
        }

        function tryInject(retries) {
            refresh();
            if (retries > 0) {
                setTimeout(function () { tryInject(retries - 1); }, 200);
            }
        }
        tryInject(5);

        if (typeof ResizeObserver !== "undefined") {
            new ResizeObserver(refresh).observe(host);
        } else {
            window.addEventListener("resize", refresh);
        }
    }

    function getUrlParam(name) {
        return new URLSearchParams(window.location.search).get(name);
    }

    function setUrlParam(name, value, replace) {
        var url = new URL(window.location.href);
        if (url.searchParams.get(name) !== value) {
            url.searchParams.set(name, value);
            if (replace) {
                window.history.replaceState({ path: url.toString() }, "", url.toString());
            } else {
                window.history.pushState({ path: url.toString() }, "", url.toString());
            }
        }
    }

    function isTruthyAttr(value, fallback) {
        if (value === null || value === undefined) return fallback;
        if (value === "" || value === "true") return true;
        if (value === "false") return false;
        return Boolean(value);
    }

    /* Discover the eXist REST base on the current page so the
       /menota/levels endpoint resolves regardless of mount point. */
    function deriveRestBase() {
        var pathname = window.location.pathname;
        var existRootMatch = pathname.match(/^(.*?)\/(?:exist\/)?apps\//);
        var existRoot = existRootMatch ? existRootMatch[1] : "";
        if (!/\/exist$/.test(existRoot) && pathname.indexOf("/exist/") !== -1) {
            existRoot = pathname.substring(0, pathname.indexOf("/exist/") + "/exist".length);
        }
        return (existRoot || "") + "/restxq/";
    }

    function findDocPath() {
        var docEl = document.querySelector("pb-document");
        var p = null;
        if (docEl) {
            p = docEl.getAttribute("path") || (docEl.source ? docEl.source.id : null);
        }
        if (!p) {
            p = new URLSearchParams(window.location.search).get("doc");
        }
        return p;
    }

    function findAppName() {
        var m = window.location.pathname.match(/\/exist\/apps\/([^/]+)\//);
        return m ? m[1] : null;
    }

    class MenotaLevelSwitcher extends HTMLElement {
        static get observedAttributes() {
            return ["value", "channel", "label"];
        }

        constructor() {
            super();
            this.attachShadow({ mode: "open" });
            this._select = null;
            this._labelEl = null;
            this._wired = false;
        }

        get channel() { return this.getAttribute("channel") || "transcription"; }
        get level()   { return this.getAttribute("value") || "dipl"; }
        get labelText() {
            var v = this.getAttribute("label");
            return v === null ? "MENOTA level:" : v;
        }
        get updateUrl() { return isTruthyAttr(this.getAttribute("update-url"), true); }
        get populateAvailable() { return isTruthyAttr(this.getAttribute("populate-available"), true); }

        connectedCallback() {
            this._render();
            this._wire();
        }

        attributeChangedCallback(name, oldVal, newVal) {
            if (!this.shadowRoot || !this._select) return;
            if (name === "label" && this._labelEl) {
                this._labelEl.textContent = this.labelText;
                this._labelEl.hidden = this.labelText.length === 0;
            } else if (name === "value" && newVal && this._select.value !== newVal) {
                this._select.setAttribute("value", newVal);
                this._select.value = newVal;
                this._applyLevel(newVal, /*fromAttr*/ true);
            } else if (name === "channel" && this._select) {
                this._select.setAttribute("emit", newVal || "transcription");
            }
        }

        _render() {
            var labelText = this.labelText;
            var html = [
                "<style>", STYLE, "</style>",
                '<div class="row">',
                '  <span class="label"' + (labelText ? "" : " hidden") + ">" +
                    (labelText.replace(/[<>&]/g, "")) + "</span>",
                '  <pb-select class="select-host" name="level"',
                '             value="' + this.level + '"',
                '             emit="' + this.channel + '"',
                '             on="pb-toggle">',
                "    <slot></slot>",
                "  </pb-select>",
                "</div>"
            ].join("\n");
            this.shadowRoot.innerHTML = html;

            this._labelEl = this.shadowRoot.querySelector(".label");
            this._select = this.shadowRoot.querySelector("pb-select");

            // Populate defaults if no <paper-item>s were slotted; otherwise
            // move slotted children into pb-select so iron-selector finds them.
            if (this.children.length === 0) {
                var slot = this._select.querySelector("slot");
                if (slot) slot.remove();
                DEFAULT_LEVELS.forEach(function (l) {
                    var item = document.createElement("paper-item");
                    item.setAttribute("value", l.val);
                    item.textContent = l.label;
                    this._select.appendChild(item);
                }, this);
            } else {
                var slot2 = this._select.querySelector("slot");
                if (slot2) slot2.remove();
                Array.from(this.children).forEach(function (child) {
                    this._select.appendChild(child);
                }, this);
            }
        }

        _wire() {
            if (this._wired) return;
            this._wired = true;

            // URL takes precedence over the attribute on initial load,
            // but only when update-url is on.
            if (this.updateUrl) {
                var fromUrl = getUrlParam("level");
                if (fromUrl) {
                    this.setAttribute("value", fromUrl);
                    this._select.setAttribute("value", fromUrl);
                    this._select.value = fromUrl;
                }
            }

            applyShadowStyles(this._select);

            if (this.populateAvailable) {
                setTimeout(this._populateAvailable.bind(this), 500);
            }

            var self = this;
            function handle(value) {
                if (!value) return;
                self._applyLevel(value, /*fromAttr*/ false);
            }

            this._select.addEventListener("iron-select", function (ev) {
                if (ev.detail && ev.detail.item) {
                    handle(ev.detail.item.getAttribute("value"));
                }
            });

            // Listen on the host element so we can run our own refresh
            // without depending on the global pbEvents bus.
            this._select.addEventListener("pb-toggle", function (ev) {
                var v = ev && ev.detail && (ev.detail.value || ev.detail.level
                    || (ev.detail.properties && ev.detail.properties.level));
                handle(v || self._select.value);
            });
        }

        _applyLevel(value, fromAttr) {
            if (!value) return;
            this.setAttribute("value", value);

            // Scope by channel so per-column switchers stay independent.
            var channel = this.channel;
            var views = document.querySelectorAll(
                'pb-view[subscribe="' + channel + '"], '
                + 'pb-view[subscribe~="' + channel + '"]'
            );

            views.forEach(function (view) {
                var param = view.querySelector('pb-param[name="level"]');
                if (param) {
                    param.setAttribute("value", value);
                    param.value = value;
                }
                if (view._features) view._features.level = value;
                if (typeof view.forceUpdate === "function") {
                    view.forceUpdate();
                }
            });

            if (this.updateUrl) {
                setUrlParam("level", value, /*replace*/ false);
            }

            if (!fromAttr) {
                this.dispatchEvent(new CustomEvent("menota-level-change", {
                    bubbles: true,
                    composed: true,
                    detail: { level: value, channel: channel }
                }));
            }
        }

        async _populateAvailable() {
            var docPath = findDocPath();
            if (!docPath) return;

            var url = deriveRestBase() + "menota/levels/" + encodeURIComponent(docPath);
            var appName = findAppName();
            if (appName) url += "?app=" + encodeURIComponent(appName);

            try {
                var response = await fetch(url, {
                    headers: { "Accept": "application/json" }
                });
                if (!response.ok) return;
                var availableTags = await response.json();
                var available = DEFAULT_LEVELS.filter(function (l) {
                    return availableTags.includes(l.tag) || availableTags.includes(l.val);
                });
                if (available.length === 0) return;

                var oldItems = this._select.querySelectorAll("paper-item");
                oldItems.forEach(function (i) { i.parentNode.removeChild(i); });

                available.forEach(function (l) {
                    var item = document.createElement("paper-item");
                    item.setAttribute("value", l.val);
                    item.textContent = l.label;
                    this._select.appendChild(item);
                }, this);

                // Keep the dropdown in sync if URL specified a level.
                if (this.updateUrl) {
                    var fromUrl = getUrlParam("level");
                    if (fromUrl) {
                        this._select.setAttribute("value", fromUrl);
                        this._select.value = fromUrl;
                    }
                }
            } catch (e) {
                console.error("[menota-level-switcher] /menota/levels fetch failed:", e);
            }
        }
    }

    customElements.define("menota-level-switcher", MenotaLevelSwitcher);
}());
