using System.Diagnostics;

class ExitMapping : KeyMapping
{
  const int HOTKEY_EXIT = 100;

  public override IReadOnlyList<HotkeyBinding> Bindings { get; } =
  [
      new(HOTKEY_EXIT, Modifiers.MOD_CONTROL | Modifiers.MOD_ALT | Modifiers.MOD_SHIFT, Keys.VK_VOLUME_MUTE),
  ];

  public override void Handle(int hotkeyId)
  {
    Environment.Exit(0);
  }
}
