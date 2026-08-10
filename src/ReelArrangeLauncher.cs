using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

internal static class ReelArrangeLauncher
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(IntPtr window, string text, string caption, uint type);

    [STAThread]
    private static int Main()
    {
        string launcherDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string scriptPath = Path.Combine(launcherDirectory, "ReelArrange.ps1");
        string powerShellPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            @"WindowsPowerShell\v1.0\powershell.exe"
        );

        if (!File.Exists(scriptPath))
        {
            MessageBox(IntPtr.Zero, "The ReelArrange script could not be found:\r\n\r\n" + scriptPath,
                "ReelArrange", 0x10);
            return 1;
        }

        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = powerShellPath;
        startInfo.Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -File \"" + scriptPath + "\"";
        startInfo.WorkingDirectory = launcherDirectory;
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;

        try
        {
            using (Process process = Process.Start(startInfo))
            {
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch (Exception exception)
        {
            MessageBox(IntPtr.Zero, "ReelArrange could not start:\r\n\r\n" + exception.Message,
                "ReelArrange", 0x10);
            return 1;
        }
    }
}
