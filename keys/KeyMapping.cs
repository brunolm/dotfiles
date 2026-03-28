using System.Runtime.InteropServices;

record HotkeyBinding(int Id, uint Modifiers, uint VirtualKey);

abstract class KeyMapping
{
  public abstract bool IsEnabled { get; }

  public abstract IReadOnlyList<HotkeyBinding> Bindings { get; }

  public abstract void Handle(int hotkeyId);

  public virtual bool Register()
  {
    foreach (var b in Bindings)
    {
      if (!Native.RegisterHotKey(0, b.Id, b.Modifiers, b.VirtualKey))
      {
        Console.Error.WriteLine($"[{GetType().Name}] Failed to register hotkey id={b.Id}");
        return false;
      }
    }
    return true;
  }

  public virtual void Unregister()
  {
    foreach (var b in Bindings)
      Native.UnregisterHotKey(0, b.Id);
  }
}

[StructLayout(LayoutKind.Sequential)]
struct MSG
{
  public nint hwnd;
  public uint message;
  public nuint wParam;
  public nint lParam;
  public uint time;
  public int pt_x;
  public int pt_y;
}

delegate nint LowLevelMouseProc(int nCode, nuint wParam, nint lParam);
delegate nint LowLevelKeyboardProc(int nCode, nuint wParam, nint lParam);

[StructLayout(LayoutKind.Sequential)]
struct KBDLLHOOKSTRUCT
{
  public uint vkCode;
  public uint scanCode;
  public uint flags;
  public uint time;
  public nuint dwExtraInfo;
}

[StructLayout(LayoutKind.Sequential)]
struct MSLLHOOKSTRUCT
{
  public int pt_x;
  public int pt_y;
  public uint mouseData;
  public uint flags;
  public uint time;
  public nuint dwExtraInfo;
}

static class Native
{
  [DllImport("user32.dll")]
  public static extern bool RegisterHotKey(nint hWnd, int id, uint fsModifiers, uint vk);

  [DllImport("user32.dll")]
  public static extern bool UnregisterHotKey(nint hWnd, int id);

  [DllImport("user32.dll")]
  public static extern int GetMessage(out MSG lpMsg, nint hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

  [DllImport("user32.dll", SetLastError = true)]
  public static extern nint SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, nint hMod, uint dwThreadId);

  [DllImport("user32.dll", SetLastError = true)]
  public static extern nint SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, nint hMod, uint dwThreadId);

  [DllImport("user32.dll")]
  public static extern bool UnhookWindowsHookEx(nint hhk);

  [DllImport("user32.dll")]
  public static extern nint CallNextHookEx(nint hhk, int nCode, nuint wParam, nint lParam);

  [DllImport("kernel32.dll")]
  public static extern nint GetModuleHandle(string lpModuleName);

  [DllImport("user32.dll")]
  public static extern nint GetForegroundWindow();

  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(nint hWnd, out uint lpdwProcessId);

  [DllImport("user32.dll")]
  public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, nuint dwExtraInfo);

  [DllImport("user32.dll")]
  public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, nuint dwExtraInfo);
}
