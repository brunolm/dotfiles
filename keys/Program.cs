using System.Reflection;

const uint WM_HOTKEY = 0x0312;

var mappings = Assembly.GetExecutingAssembly()
    .GetTypes()
    .Where(t => t is { IsAbstract: false, IsClass: true } && t.IsSubclassOf(typeof(KeyMapping)))
    .Select(t => (KeyMapping)Activator.CreateInstance(t)!)
    .Where(m => m.IsEnabled)
    .ToList();

var hotkeyLookup = new Dictionary<int, KeyMapping>();

foreach (var mapping in mappings)
{
  if (!mapping.Register()) return 1;
  foreach (var b in mapping.Bindings)
    hotkeyLookup[b.Id] = mapping;
}

Console.WriteLine($"Registered {mappings.Count} mapping(s). Listening... (Ctrl+C to exit)");

Console.CancelKeyPress += (_, _) =>
{
  foreach (var mapping in mappings)
    mapping.Unregister();
};

while (Native.GetMessage(out var msg, 0, 0, 0) > 0)
{
  if (msg.message != WM_HOTKEY) continue;

  var id = (int)msg.wParam;
  if (hotkeyLookup.TryGetValue(id, out var mapping))
    mapping.Handle(id);
}

return 0;
