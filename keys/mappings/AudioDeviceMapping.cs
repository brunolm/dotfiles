using System.Diagnostics;

class AudioDeviceMapping : KeyMapping
{
  const int HOTKEY_UP = 1;
  const int HOTKEY_DOWN = 2;

  static readonly Dictionary<int, (string playback, string recording)> Devices = new()
  {
    [HOTKEY_UP] = ("Speakers (Razer BlackShark V2 Pro)", "Microphone (Razer BlackShark V2 Pro)"),
    [HOTKEY_DOWN] = ("Speakers (Realtek(R) Audio)", "Microphone Array (Intel® Smart Sound Technology for Digital Microphones)"),
  };

  public override IReadOnlyList<HotkeyBinding> Bindings { get; } =
  [
      new(HOTKEY_UP, Modifiers.MOD_CONTROL, Keys.VK_VOLUME_UP),
      new(HOTKEY_DOWN, Modifiers.MOD_CONTROL, Keys.VK_VOLUME_DOWN),
  ];

  public override void Handle(int hotkeyId)
  {
    if (!Devices.TryGetValue(hotkeyId, out var dev)) return;

    Console.WriteLine($"Switching to: {dev.playback} / {dev.recording}");
    SwitchAudioDevice(dev.playback, "Playback");
    SwitchAudioDevice(dev.recording, "Recording");
  }

  static void SwitchAudioDevice(string deviceName, string type)
  {
    var psCmd = string.Join("; ",
        "Import-Module AudioDeviceCmdlets",
        $"$dev = Get-AudioDevice -List | Where-Object {{ $_.Name -eq '{deviceName}' -and $_.Type -eq '{type}' }}",
        "if ($dev) { Set-AudioDevice -Index $dev.Index }");

    using var proc = Process.Start(new ProcessStartInfo
    {
      FileName = "powershell",
      Arguments = $"-NoProfile -Command \"{psCmd}\"",
      CreateNoWindow = true,
      UseShellExecute = false,
    });
    proc?.WaitForExit(5000);
  }
}
