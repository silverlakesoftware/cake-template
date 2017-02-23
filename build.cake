var OutputDir = Directory("out");

Task("Default")
    .Does(() =>
{
    CreateDirectory(OutputDir);
    CleanDirectory(OutputDir);
    CopyFile(File("build.ps1"),OutputDir + File("build.ps1"));
    System.IO.File.WriteAllText(OutputDir + File("build.cake"),"");
    StartProcess("powershell.exe", new ProcessSettings()
    {
        Arguments = "-ExecutionPolicy ByPass -File build.ps1 -Verbose",
        WorkingDirectory = OutputDir
    });
});

RunTarget("Default");