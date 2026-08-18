using System;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;

[assembly: AssemblyTitle("ReelArrange")]
[assembly: AssemblyProduct("ReelArrange")]
[assembly: AssemblyCompany("CybersecKyle")]
[assembly: AssemblyDescription("Prepare downloaded movies and TV shows for a Jellyfin media library")]
[assembly: AssemblyCopyright("Copyright (c) Kyle Reddoch")]
[assembly: AssemblyVersion("0.3.0.0")]
[assembly: AssemblyFileVersion("0.3.0.0")]

internal static class ReelArrangeLauncher
{
    private const string AppUserModelId = "CybersecKyle.ReelArrange";

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(IntPtr window, string text, string caption, uint type);

    [DllImport("shell32.dll", SetLastError = true)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(
        [MarshalAs(UnmanagedType.LPWStr)] string appId);

    [STAThread]
    private static int Main(string[] arguments)
    {
        string launcherDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string scriptPath = Path.Combine(launcherDirectory, "ReelArrange.ps1");

        if (!File.Exists(scriptPath))
        {
            MessageBox(IntPtr.Zero, "The ReelArrange script could not be found:\r\n\r\n" + scriptPath,
                "ReelArrange", 0x10);
            return 1;
        }

        bool showAbout = arguments.Any(argument =>
            String.Equals(argument, "--about", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(argument, "/about", StringComparison.OrdinalIgnoreCase));
        bool runSelfTest = arguments.Any(argument =>
            String.Equals(argument, "--self-test", StringComparison.OrdinalIgnoreCase));

        try
        {
            SetCurrentProcessExplicitAppUserModelID(AppUserModelId);

            using (Runspace runspace = RunspaceFactory.CreateRunspace())
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                runspace.SessionStateProxy.Path.SetLocation(launcherDirectory);

                using (PowerShell powerShell = PowerShell.Create())
                {
                    powerShell.Runspace = runspace;
                    powerShell.AddCommand(scriptPath);
                    if (showAbout) { powerShell.AddParameter("About"); }
                    if (runSelfTest) { powerShell.AddParameter("SelfTest"); }
                    powerShell.Invoke();

                    if (powerShell.HadErrors)
                    {
                        string message = powerShell.Streams.Error.Count > 0
                            ? powerShell.Streams.Error[powerShell.Streams.Error.Count - 1].ToString()
                            : "The embedded PowerShell workflow reported an unknown error.";
                        MessageBox(IntPtr.Zero, "ReelArrange could not start:\r\n\r\n" + message,
                            "ReelArrange", 0x10);
                        return 1;
                    }
                }
            }

            return 0;
        }
        catch (Exception exception)
        {
            MessageBox(IntPtr.Zero, "ReelArrange could not start:\r\n\r\n" + exception.Message,
                "ReelArrange", 0x10);
            return 1;
        }
    }
}
