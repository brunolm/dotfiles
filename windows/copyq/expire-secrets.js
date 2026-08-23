var now = Date.now()
var tabs = tab()

for (var t = 0; t < tabs.length; ++t) {
    tab(tabs[t])

    for (var i = count() - 1; i >= 0; --i) {
        var expiresAt = Number(str(read("application/x-expiry-stamp", i)))
        if (!expiresAt || expiresAt > now) continue

        var text = str(read("text/plain", i))
        remove(i)

        if (text && str(clipboard("text/plain")) === text) copy("")
    }
}
