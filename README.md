# Dockerizer
This script makes the following actions: Builds a ASP.NET Core project (web or web api), publishes it, creates an image for Docker and run it.

## Description
Parameters 'path', 'imageName' and 'port' are mandatories.  
Your ASP.NET Core project doesn't have to got a 'Dockerfile' file for dockering it.  
Also, your Docker doesn't have to got a Microsoft Framework image to run it.  
If you have already got your application running and want to replace it with a new version, you don't have to remove your current Docker image or stop and remove its current container.  
This script makes all the necessary for your application to work.  
The most important: This script does not build and publish inside your Docker. It do it on your machine and only copies published files to Docker to create the image, in order to enhance your Docker performance.

## Parameters
**-path**  
(mandatory)  
The absolute path where the .NET project is.  
Do not mistake project path for solution path. This is the main project path of the solution.

**-imageName**  
(mandatory)  
The image name for Docker. Also, this name is gonna be used for the container.

**-port**  
(mandatory)  
The port to map to Docker port 80.  
Your ASP.NET application is gonna run on Docker port 80 and is gonna be exposed on this parameter value port.

**-extension**  
By default, this script is gonna search for *MyProject.csproj* file in order to build and publish it, where *'MyProject'* is the name of the last folder you specified earlier in *'path'* parameter.  
In case you've used other language rather than C#, specify the extension of your project file with this parameter.

**-framework**  
By default, this script is gonna execute *dotnet build* command with no target framework specification. Though, your project is gonna be built with the last sdk version you've got on your machine.  
This is important to take into account.  
Run *dotnet --list-sdks* command to see all of your installed sdks. You have probably got more than one.  
The last one is the one that *dotnet build* is going to use (also, run *dotnet --version* to see it).  
Besides, if this parameter is not specified, this script is gonna pull the latest version of the Microsoft Framework image to install in your Docker.

In case you want to specify a sdk version (this is the recommended option) to use for 'dotnet build' command (and also to pull for the Microsfot Framework image), enter it in the following form:  
2.1 (for .NET Core 2.1) or 3.0 (for .NET Core 3.0) or 5.0 (for .NET 5.0) or 6.0 (for .NET 6.0) or...

**-loggingConsole**  
(.NET 6.0 and above)  
.NET 6.0 changed aspnet image type, making its default console logger format to JSON formatter, in order to have a default configuration that works with automated tools that rely on a machine-readable format.  
Nevertheless, at Docker console you will see unreadable ugly Json strings.
Setting this paramter to "1" (no quoted), image will be configured to log with the usual simple console formatter.  
(default is "0")

**-wsl**  
In case you have installed Docker on Linux through WSL, set this parameter to "1" (no quoted)  
(default is "0")

## Example
```
& .\dockerizer.ps1 -path C:\Projects\MyProject\MyProject -imageName my_project -port 8000 -framework 5.0  
```

In this example, you have a .NET solution at 'C:\Projects\MyProject' and its main project is at 'C:\Projects\MyProject\MyProject', coded with C#.  
The Docker image name is gonna be 'my_project'.  
The Docker container name is gonna be 'my_project'.  
You will be able to access it at http://localhost:8000  
Your project is gonna be built with the sdk version 5.0  
Image 'mcr.microsoft.com/dotnet/aspnet:5.0' is gonna be pulled to your Docker.  

Built and published files are gonna be created at the root solution folder, inside a 'docker' folder, in order to not mess with your \bin\release files.
