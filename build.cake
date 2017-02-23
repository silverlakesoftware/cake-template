var OutputDir = Directory("out");

Task("Default")
    .Does(() =>
{
    CreateDirectory(OutputDir);
    CleanDirectory(OutputDir);
    System.IO.File.WriteAllText(OutputDir + File("build.cake"),"Information(\"Works!\");");

    if (IsRunningOnWindows())
    {
        CopyFile(File("build.ps1"),OutputDir + File("build.ps1"));
        StartProcess("powershell.exe", new ProcessSettings()
        {
            Arguments = "-ExecutionPolicy ByPass -File build.ps1 -Verbose",
            WorkingDirectory = OutputDir
        });
    }
    if (IsRunningOnUnix())
    {
        CopyFile(File("build.sh"),OutputDir + File("build.sh"));
        StartProcess("bash", new ProcessSettings()
        {
            Arguments = "build.sh",
            WorkingDirectory = OutputDir
        });
    }
});

RunTarget("Default");