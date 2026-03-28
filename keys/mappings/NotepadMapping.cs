using System.Diagnostics;
using System.Runtime.InteropServices;

class NotepadMapping : KeyMapping
{
  const int WH_KEYBOARD_LL = 13;
  const uint WM_KEYDOWN = 0x0100;
  const byte VK_X = 0x58;
  const byte VK_Y = 0x59;
  const uint KEYEVENTF_KEYUP = 0x0002;
  const uint LLKHF_INJECTED = 0x00000010;

  nint _hookId;
  readonly LowLevelKeyboardProc _hookProc;

  public NotepadMapping()
  {
    _hookProc = HookCallback;
  }

  public override bool IsEnabled => false;

  public override IReadOnlyList<HotkeyBinding> Bindings { get; } = [];

  public override void Handle(int hotkeyId) { }

  public override bool Register()
  {
    using var curProcess = Process.GetCurrentProcess();
    using var curModule = curProcess.MainModule!;
    _hookId = Native.SetWindowsHookEx(WH_KEYBOARD_LL, _hookProc, Native.GetModuleHandle(curModule.ModuleName), 0);
    if (_hookId == 0) return false;

    Console.WriteLine("Notepad keyboard hook installed.");
    return true;
  }

  public override void Unregister()
  {
    if (_hookId != 0)
      Native.UnhookWindowsHookEx(_hookId);
  }

  nint HookCallback(int nCode, nuint wParam, nint lParam)
  {
    if (nCode < 0)
      return Native.CallNextHookEx(_hookId, nCode, wParam, lParam);

    var hookStruct = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);

    if ((hookStruct.flags & LLKHF_INJECTED) != 0)
      return Native.CallNextHookEx(_hookId, nCode, wParam, lParam);

    if (hookStruct.vkCode != VK_X)
      return Native.CallNextHookEx(_hookId, nCode, wParam, lParam);

    if (!IsNotepadFocused())
      return Native.CallNextHookEx(_hookId, nCode, wParam, lParam);

    if ((uint)wParam == WM_KEYDOWN)
    {
      for (var i = 0; i < 3; i++)
      {
        Native.keybd_event(VK_Y, 0, 0, 0);
        Native.keybd_event(VK_Y, 0, KEYEVENTF_KEYUP, 0);
      }
    }

    return 1;
  }

  static bool IsNotepadFocused()
  {
    var hwnd = Native.GetForegroundWindow();
    if (hwnd == 0) return false;

    Native.GetWindowThreadProcessId(hwnd, out var pid);
    try
    {
      using var proc = Process.GetProcessById((int)pid);
      return proc.ProcessName.Equals("Notepad", StringComparison.OrdinalIgnoreCase);
    }
    catch
    {
      return false;
    }
  }
}
