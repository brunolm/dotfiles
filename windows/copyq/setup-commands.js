var EXPIRE_MS = 5 * 60 * 1000
var TAB = 'Passwords'
var NAME = 'Expire password-looking items'

var appData = str(env('APPDATA')).split('\\').join('/')
var programFiles = str(env('PROGRAMFILES')).split('\\').join('/')

var sweeperPath = appData + '/copyq/expire-secrets.js'
var copyqExe = programFiles + '/CopyQ/copyq.exe'

// CopyQ has no timer in its script API, so the expiry is a detached copyq
// process that sleeps and then runs the sweeper.
var loader = [
    'sleep(' + (EXPIRE_MS + 2000) + ');',
    'var f = new File(' + JSON.stringify(sweeperPath) + ');',
    'f.openReadOnly();',
    'var src = str(f.readAll());',
    'f.close();',
    'eval(src)'
].join(' ')

// Data in the application/x-copyq-* namespace is silently discarded when the
// item is stored, so the expiry timestamp uses its own format name.
var expireCommand = {
    name: NAME,
    automatic: true,
    enable: true,
    input: 'text/plain',
    tab: TAB,
    remove: true,
    re: /^(?!\w+:\/\/)(?=\S*[a-z])(?=\S*[A-Z])(?=\S*\d)\S{10,64}$/,
    cmd: [
        'copyq:',
        'setData("application/x-expiry-stamp", String(Date.now() + ' + EXPIRE_MS + '))',
        'execute("cmd", "/c", "start", "", "/b", ' + JSON.stringify(copyqExe) + ', "eval", "--", ' + JSON.stringify(loader) + ')'
    ].join('\n'),
    icon: ''
}

var toggleCommand = {
    name: 'Show/hide main window',
    isGlobalShortcut: true,
    globalShortcuts: ['meta+v'],
    enable: true,
    cmd: 'copyq: toggle()',
    icon: ''
}

var kept = commands().filter(function (c) { return c.name !== NAME })
var hasToggle = kept.some(function (c) {
    return c.isGlobalShortcut && c.globalShortcuts.length > 0 && c.cmd.indexOf('toggle()') >= 0
})

setCommands(kept.concat(hasToggle ? [expireCommand] : [expireCommand, toggleCommand]))

'CopyQ commands configured: ' + commands().length + ' total'
