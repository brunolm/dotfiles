using System.Diagnostics;
using System.Runtime.InteropServices;

class ArcRaidersMapping : KeyMapping
{
  const int WH_MOUSE_LL = 14;
  const uint WM_XBUTTONDOWN = 0x020B;
  const uint WM_XBUTTONUP = 0x020C;
  const ushort XBUTTON2 = 0x0002;
  const uint INPUT_MOUSE = 0;
  const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
  const uint MOUSEEVENTF_MIDDLEUP = 0x0040;
  const nuint SELF_INJECTED = 0xA3C_4A1D;

  nint _hookId;
  readonly LowLevelMouseProc _hookProc;

  public ArcRaidersMapping()
  {
    _hookProc = HookCallback;
  }

  public override bool IsEnabled => true;

  public override IReadOnlyList<HotkeyBinding> Bindings { get; } = [];

  public override void Handle(int hotkeyId) { }

  public override bool Register()
  {
    using var curProcess = Process.GetCurrentProcess();
    using var curModule = curProcess.MainModule!;
    _hookId = Native.SetWindowsHookEx(WH_MOUSE_LL, _hookProc, Native.GetModuleHandle(curModule.ModuleName), 0);
    if (_hookId == 0) return false;

    Console.WriteLine("Arc Raiders mouse hook installed.");
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

    var msg = (uint)wParam;
    if (msg is not (WM_XBUTTONDOWN or WM_XBUTTONUP))
      return Native.CallNextHookEx(_hookId, nCode, wParam, lParam);

    var hookStruct = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);
    var xButton = (ushort)(hookStruct.mouseData >> 16);
    if (xButton != XBUTTON2)
      return Native.CallNextHookEx(_hookId, nCode, wParam, lParam);

    if (!IsArcRaidersFocused())
      return Native.CallNextHookEx(_hookId, nCode, wParam, lParam);

    var flags = msg == WM_XBUTTONDOWN ? MOUSEEVENTF_MIDDLEDOWN : MOUSEEVENTF_MIDDLEUP;
    Task.Run(() =>
    {
      var input = new INPUT
      {
        type = INPUT_MOUSE,
        mi = new MOUSEINPUT
        {
          dwFlags = flags,
          dwExtraInfo = SELF_INJECTED,
        }
      };
      SendInput(1, [input], Marshal.SizeOf<INPUT>());
    });

    return 1;
  }

  static bool IsArcRaidersFocused()
  {
    var hwnd = Native.GetForegroundWindow();
    if (hwnd == 0) return false;

    Native.GetWindowThreadProcessId(hwnd, out var pid);
    try
    {
      using var proc = Process.GetProcessById((int)pid);
      return proc.ProcessName.Equals("PioneerGame", StringComparison.OrdinalIgnoreCase);
    }
    catch
    {
      return false;
    }
  }

  [DllImport("user32.dll", SetLastError = true)]
  static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

  [StructLayout(LayoutKind.Sequential)]
  struct MOUSEINPUT
  {
    public int dx;
    public int dy;
    public uint mouseData;
    public uint dwFlags;
    public uint time;
    public nuint dwExtraInfo;
  }

  [StructLayout(LayoutKind.Sequential)]
  struct INPUT
  {
    public uint type;
    public MOUSEINPUT mi;
  }
}
