# C# / Windows Hooks

- Never call `SendInput` synchronously inside a low-level hook callback (`LowLevelMouseProc`, `LowLevelKeyboardProc`). Use `Task.Run` or post to another thread to avoid reentrancy issues where Windows loses track of input state on consecutive presses.
