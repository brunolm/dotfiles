using System.Runtime.InteropServices;

record HotkeyBinding(int Id, uint Modifiers, uint VirtualKey);

abstract class KeyMapping
{
  public abstract IReadOnlyList<HotkeyBinding> Bindings { get; }

  public abstract void Handle(int hotkeyId);

  public bool Register()
  {
    foreach (var b in Bindings)
    {
      if (!Native.RegisterHotKey(0, b.Id, b.Modifiers, b.VirtualKey))
      {
        Console.Error.WriteLine($"Failed to register hotkey id={b.Id}");
        return false;
      }
    }
    return true;
  }

  public void Unregister()
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

static class Native
{
  [DllImport("user32.dll")]
  public static extern bool RegisterHotKey(nint hWnd, int id, uint fsModifiers, uint vk);

  [DllImport("user32.dll")]
  public static extern bool UnregisterHotKey(nint hWnd, int id);

  [DllImport("user32.dll")]
  public static extern int GetMessage(out MSG lpMsg, nint hWnd, uint wMsgFilterMin, uint wMsgFilterMax);
}
