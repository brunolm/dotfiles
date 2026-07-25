// Star-burst click effect companion for the crystal cursor set.
// Runs in the background, hooks left-clicks system-wide, and plays a short
// sparkle burst at the click point on a click-through layered window.
// Compiled at install time by install-click-sparkle.ps1 (needs only the
// .NET Framework csc.exe that ships with Windows).
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

static class Program
{
    [DllImport("user32.dll")]
    static extern bool SetProcessDPIAware();

    [STAThread]
    static void Main()
    {
        bool created;
        using (new Mutex(true, "ClickSparkleSingleton", out created))
        {
            if (!created) return;
            SetProcessDPIAware();
            MouseHook.Install();
            Application.Run();
        }
    }
}

static class MouseHook
{
    delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);
    const int WH_MOUSE_LL = 14;
    const int WM_LBUTTONDOWN = 0x0201;

    // kept in a static so the delegate never gets garbage-collected while hooked
    static readonly LowLevelMouseProc Proc = HookCallback;
    static IntPtr hookId;

    [StructLayout(LayoutKind.Sequential)]
    struct POINT { public int x, y; }

    [StructLayout(LayoutKind.Sequential)]
    struct MSLLHOOKSTRUCT { public POINT pt; public uint mouseData, flags, time; public IntPtr dwExtraInfo; }

    [DllImport("user32.dll")]
    static extern IntPtr SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Install()
    {
        hookId = SetWindowsHookEx(WH_MOUSE_LL, Proc, GetModuleHandle(null), 0);
    }

    static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && (int)wParam == WM_LBUTTONDOWN)
        {
            var info = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(MSLLHOOKSTRUCT));
            SparkleBurst.Spawn(info.pt.x, info.pt.y);
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}

class SparkleBurst : Form
{
    const int SIZE = 170;
    const int FRAMES = 6;        // ~200ms: with no stars, the ring is the whole effect
    const double RING_END = 1.0;
    const int INTERVAL_MS = 33;
    const float MAX_R = 8f;
    const float BAND_MAX = 4f;  // peak ring half-thickness; gaussian falloff makes the gradient

    static readonly Color RingColor = Color.FromArgb(110, 160, 205);
    static readonly Color[] Palette =
    {
        Color.FromArgb(242, 242, 235),
        Color.FromArgb(155, 232, 255),
        Color.FromArgb(110, 180, 255)
    };
    static readonly Random Rng = new Random();

    struct Star { public double Angle, DistFrac, Size, Delay, Twinkle; public Color Color; }

    readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
    readonly Star[] stars = new Star[0];
    int frame;

    public static void Spawn(int x, int y)
    {
        new SparkleBurst(x, y).Show();
    }

    SparkleBurst(int x, int y)
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        Bounds = new Rectangle(x - SIZE / 2, y - SIZE / 2, SIZE, SIZE);
        TopMost = true;

        for (int i = 0; i < stars.Length; i++)
        {
            double distFrac = 0.3 + Rng.NextDouble() * 0.55;
            stars[i] = new Star
            {
                Angle = Rng.NextDouble() * Math.PI * 2,
                DistFrac = distFrac,
                Size = 2.5 + Rng.NextDouble() * 3.5,
                // stars light up as the expanding ring passes their radius
                Delay = 0.08 + 0.45 * distFrac + Rng.NextDouble() * 0.1,
                Twinkle = Rng.NextDouble() * Math.PI * 2,
                Color = Palette[Rng.Next(Palette.Length)]
            };
        }

        timer.Interval = INTERVAL_MS;
        timer.Tick += delegate
        {
            frame++;
            if (frame >= FRAMES) { timer.Stop(); Close(); }
            else Render();
        };
        timer.Start();
        Render();
    }

    protected override CreateParams CreateParams
    {
        get
        {
            // WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE:
            // per-pixel alpha, click-through, no taskbar/alt-tab entry, never steals focus
            var cp = base.CreateParams;
            cp.ExStyle |= 0x80000 | 0x20 | 0x80 | 0x8000000;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    void Render()
    {
        using (var bmp = new Bitmap(SIZE, SIZE, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            double t = (double)frame / FRAMES;
            float c = SIZE / 2f;

            // ring time runs compressed into the first RING_END of the effect
            double rt = t / RING_END;
            double envelope = 0, fade = 0;
            float band = 1f;
            float r = 0f;
            if (rt < 1)
            {
                // fast ease-out expansion, like the reference (near-full size
                // within the first couple frames)
                double grow = 1 - Math.Pow(1 - Math.Min(1, rt / 0.8), 2);
                r = (float)(2 + (MAX_R - 2) * grow);
                // thickness and opacity share one sine envelope: fade in
                // thin, swell mid-flight, thin back out while dissipating
                envelope = Math.Pow(Math.Sin(Math.PI * rt), 2);
                fade = envelope;
                band = (float)(1.0 + (BAND_MAX - 1.0) * envelope);
            }

            if (fade > 0)
            {
                // fake a soft radial gradient with densely stacked faint
                // circles on a gaussian band — a wide sigma and small step
                // keep any single stroke from reading as a solid outline
                float spread = Math.Max(3f, band);
                double sigma = spread / 2.4;
                for (float o = -spread; o <= spread; o += 0.6f)
                {
                    float rr = r + o;
                    if (rr <= 1) continue;
                    int alpha = (int)(95 * Math.Exp(-(o * o) / (2 * sigma * sigma)) * fade);
                    if (alpha <= 3) continue;
                    using (var pen = new Pen(Color.FromArgb(alpha, RingColor), 1.4f))
                        g.DrawEllipse(pen, c - rr, c - rr, 2 * rr, 2 * rr);
                }
            }

            // stars ignite inside as the ring passes, twinkle, then fade at the end
            double endFade = Math.Min(1, (1 - t) / 0.18);
            foreach (var st in stars)
            {
                double ignite = (t - st.Delay) / 0.2;
                if (ignite <= 0) continue;
                if (ignite > 1) ignite = 1;
                double twinkle = 0.75 + 0.25 * Math.Sin(t * 14 + st.Twinkle);
                int alpha = (int)(255 * ignite * endFade * twinkle);
                if (alpha <= 4) continue;
                float sx = (float)(c + Math.Cos(st.Angle) * st.DistFrac * MAX_R);
                float sy = (float)(c + Math.Sin(st.Angle) * st.DistFrac * MAX_R);
                DrawStar(g, sx, sy, (float)(st.Size * (0.7 + 0.3 * ignite)), st.Color, alpha);
            }
            Push(bmp);
        }
    }

    // Same star shape as the cursor set: long 4-ray cross, faint diagonals,
    // bright white core
    static void DrawStar(Graphics g, float x, float y, float s, Color c, int alpha)
    {
        using (var pen = new Pen(Color.FromArgb(alpha, c), 1.6f))
        {
            g.DrawLine(pen, x - s, y, x + s, y);
            g.DrawLine(pen, x, y - s, x, y + s);
        }
        float d = s * 0.45f;
        using (var pen2 = new Pen(Color.FromArgb(alpha * 140 / 255, c), 1f))
        {
            g.DrawLine(pen2, x - d, y - d, x + d, y + d);
            g.DrawLine(pen2, x - d, y + d, x + d, y - d);
        }
        using (var b = new SolidBrush(Color.FromArgb(alpha, 255, 255, 255)))
            g.FillEllipse(b, x - 1.5f, y - 1.5f, 3f, 3f);
    }

    [StructLayout(LayoutKind.Sequential)]
    struct WPOINT { public int x, y; }
    [StructLayout(LayoutKind.Sequential)]
    struct WSIZE { public int cx, cy; }
    [StructLayout(LayoutKind.Sequential)]
    struct BLENDFUNCTION { public byte BlendOp, BlendFlags, SourceConstantAlpha, AlphaFormat; }

    [DllImport("user32.dll")]
    static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref WPOINT pptDst, ref WSIZE psize,
        IntPtr hdcSrc, ref WPOINT pprSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
    [DllImport("user32.dll")]
    static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")]
    static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("gdi32.dll")]
    static extern IntPtr CreateCompatibleDC(IntPtr hDC);
    [DllImport("gdi32.dll")]
    static extern bool DeleteDC(IntPtr hdc);
    [DllImport("gdi32.dll")]
    static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
    [DllImport("gdi32.dll")]
    static extern bool DeleteObject(IntPtr hObject);

    void Push(Bitmap bmp)
    {
        IntPtr screenDc = GetDC(IntPtr.Zero);
        IntPtr memDc = CreateCompatibleDC(screenDc);
        IntPtr hBitmap = bmp.GetHbitmap(Color.FromArgb(0));
        IntPtr oldBitmap = SelectObject(memDc, hBitmap);
        var size = new WSIZE { cx = bmp.Width, cy = bmp.Height };
        var src = new WPOINT { x = 0, y = 0 };
        var pos = new WPOINT { x = Left, y = Top };
        var blend = new BLENDFUNCTION { BlendOp = 0, BlendFlags = 0, SourceConstantAlpha = 255, AlphaFormat = 1 };
        UpdateLayeredWindow(Handle, screenDc, ref pos, ref size, memDc, ref src, 0, ref blend, 2);
        SelectObject(memDc, oldBitmap);
        DeleteObject(hBitmap);
        DeleteDC(memDc);
        ReleaseDC(IntPtr.Zero, screenDc);
    }
}
