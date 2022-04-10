<#
.SYNOPSIS

This script makes the following actions: Builds a ASP.NET Core project (web or web api), publishes it, creates an image for Docker and run it.
.DESCRIPTION

Parameters 'path', 'imageName' and 'port' are mandatories.
Your ASP.NET Core project doesn't have to got a 'Dockerfile' file for dockering it.
Also, your Docker doesn't have to got a Microsoft Framework image to run it.
If you have already got your application running and want to replace it with a new version, you don't have to remove your current Docker image or stop and remove its current container.
This script makes all the necessary for your application to work.
The most important: This script does not build and publish inside your Docker. It do it on your machine and only copies published files to Docker to create the image, in order to enhance your Docker performance.

.PARAMETER path

(mandatory)
The absolute path where the .NET project is.
Do not mistake project path for solution path. This is the main project path of the solution.

.PARAMETER imageName

(mandatory)
The image name for Docker. Also, this name is gonna be used for the container.

.PARAMETER port

(mandatory)
The port to map to Docker port 80.
Your ASP.NET application is gonna run on Docker port 80 and is gonna be exposed on this parameter value port.

.PARAMETER extension

By default, this script is gonna search for 'MyProject.csproj' file in order to build and publish it, where 'MyProject' is the name of the last folder you specified earlier in 'path' parameter.
In case you've used other language rather than C#, specify the extension of your project file with this parameter.

.PARAMETER framework

By default, this script is gonna execute 'dotnet build' command with no target framework specification. Though, your project is gonna be built with the last sdk version you've got on your machine.
This is important to take into account. 
Run 'dotnet --list-sdks' command to see all of your installed sdks. You have probably got more than one.
The last one is the one that 'dotnet build' is going to use (also, run 'dotnet --version' to see it).
Plus, if this parameter is not specified, this script is gonna pull the latest version of the Microsoft Framework image to install in your Docker.

In case you want to specify a sdk version (this is the recommended option) to use for 'dotnet build' command (and also to pull for the Microsoft Framework image), enter it in the following form:
2.1 (for .NET Core 2.1) or 3.0 (for .NET Core 3.0) or 5.0 (for .NET 5.0) or 6.0 (for .NET 6.0) or...

.PARAMETER loggingConsole

(.NET 6.0 and above)
NET 6.0 changed aspnet image type, making its default console logger format to JSON formatter, in order to have a default configuration that works with automated tools that rely on a machine-readable format.
Nevertheless, at Docker console you will see unreadable ugly Json strings.
Setting this parameter to "1" (no quoted), image will be configured to log with the usual simple console formatter.
(default is "0")

.PARAMETER wsl

In case you have installed Docker on Linux through WSL, set this parameter to "1" (no quoted)
(default is "0")

.EXAMPLE

& .\dockerizer.ps1 -path C:\Projects\MyProject\MyProject -imageName my_project -port 8000 -framework 5.0

In this example, you have a .NET solution at 'C:\Projects\MyProject' and its main project is at 'C:\Projects\MyProject\MyProject', coded with C#.
The Docker image name is gonna be 'my_project'.
The Docker container name is gonna be 'my_project'.
You will be able to access it at http://localhost:8000
Your project is gonna be built with the sdk version 5.0
Image 'mcr.microsoft.com/dotnet/aspnet:5.0' is gonna be pulled to your Docker.
Built and published files are gonna be created at the root solution folder, inside a 'docker' folder, in order to not mess with your \bin\release files.

#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $path,

    [Parameter()]
    [string]
    $imageName,

    [Parameter()]
    [string]
    $port,

    [Parameter()]
    [string]
    $extension = '.csproj',

    [Parameter()]
    [string]
    $framework,

    [Parameter()]
    [bool]
    $loggingConsole = $false,

    [Parameter()]
    [bool]
    $wsl = $false
)

# FUNCTIONS

function ValidateParameters ($path, $imageName, $port) {

    if (-not $path) {
        throw "Parameter 'path' is missing. Type 'Get-Help .\dockerizer.ps1 -detailed' for help."
    }

    if (-not $imageName) {
        throw "Parameter 'imageName' is missing. Type 'Get-Help .\dockerizer.ps1 -detailed' for help."
    }

    if (-not $port) {
        throw "Parameter 'port' is missing. Type 'Get-Help .\dockerizer.ps1 -detailed' for help."
    }
}

function ValidatePath ($path) {

    Write-Host ''
    Write-Host 'Verifying provided path...' -ForegroundColor DarkGreen

    $isAbsolute = Split-Path -Path $path -IsAbsolute
    if ($isAbsolute -eq $false) {
        throw "Provided path is relative. Please enter an absolute path."
    }
    
    $pathExists = Test-Path $path
    if ($pathExists -eq $false) {
        throw "Provided path does not exist."
    }
    
    Write-Host 'OK!' -ForegroundColor Green
}

function ValidateProjectFile ($path, $projectName, $projectFullName) {

    Write-Host ''
    Write-Host 'Verifying project file...' -ForegroundColor DarkGreen
    
    $projectExists = Test-Path $projectFullName
    if ($projectExists -eq $false) {
        throw "Provided path does not contain a project named '$projectName'"
    }
    
    Write-Host 'OK!' -ForegroundColor Green
}

function RestoreDependencies ($projectFullName) {

    Write-Host ''
    Write-Host 'Restoring dependencies...' -ForegroundColor DarkGreen

    & dotnet restore "$projectFullName" -v m   

    if ($LASTEXITCODE -ne 0) {
        throw "Restore dependencies not succeded."
    }

    Write-Host 'OK!' -ForegroundColor Green
}

function GetProjectFramework($framework) {

    if ($framework) {

        if ([decimal]$framework -lt 4) {

            return 'netcoreapp' + $framework
        } else {

            return 'net' + $framework
        }
    }

    return ''
}

function BuildProject ($buildPath, $projectFullName, $projectFramework) {

    Write-Host ''
    Write-Host 'Building the project...' -ForegroundColor DarkGreen

    if ($projectFramework) {
        & dotnet build "$projectFullName" -f $projectFramework -c Release -o "$buildPath" -v m --no-restore
    } else {
        & dotnet build "$projectFullName" -c Release -o "$buildPath" -v m --no-restore
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Build project not succeded."
    }
    
    Write-Host 'OK!' -ForegroundColor Green
}

function PublishProject ($publishPath, $projectFullName) {
    
    Write-Host ''
    Write-Host 'Publishing the project...' -ForegroundColor DarkGreen
    
    & dotnet publish "$projectFullName" -c Release -o "$publishPath" -v m --no-restore
    if ($LASTEXITCODE -ne 0) {
        throw "Publish project not succeded."
    }
    
    Write-Host 'OK!' -ForegroundColor Green
}

function CopyDllsToPublishFolder ($buildPath, $publishPath) {

    Write-Host ''
    Write-Host 'Copying remaining DLLs to publish folder...' -ForegroundColor DarkGreen
    
    $dllsToCopy = GetDllsToCopy $buildPath $publishPath
    CopyDlls $dllsToCopy $buildPath $publishPath

    Write-Host 'OK!' -ForegroundColor Green
}

function GetDllsToCopy ($buildPath, $publishPath) {

    $buildDlls = Get-ChildItem -Path $buildPath -Filter *.dll -Name
    $publishDlls = Get-ChildItem -Path $publishPath -Filter *.dll -Name
    $remainingDlls = @()
    
    for ($i = 0; $i -lt $buildDlls.Count; $i++) {
        
        $dllExists = $false
    
        for ($j = 0; $j -lt $publishDlls.Count; $j++) {
            
            if ($buildDlls[$i] -eq $publishDlls[$j]) {
                $dllExists = $true
                break
            }
        }
    
        if ($dllExists -eq $false) {
            $remainingDlls += $buildDlls[$i]
        }
    }

    return $remainingDlls
}

function CopyDlls ($dllsToCopy, $origin, $destination) {

    for ($i = 0; $i -lt $dllsToCopy.Count; $i++) {

        $dllFullFileName = Join-Path $origin -ChildPath $dllsToCopy[$i]
        Copy-Item $dllFullFileName -Destination $destination
    }    
}

function GenerateDockerFile ($dockerFullFileName, $framework, $projectNameNoExtension) {

    Write-Host ''
    Write-Host 'Creating docker file...' -ForegroundColor DarkGreen

    $dockerFileExists = Test-Path $dockerFullFileName
    if ($dockerFileExists -eq $false) {
        New-Item $dockerFullFileName
    }

    $frameworkVersion = 'latest'
    if ($framework) {
        $frameworkVersion = $framework
    }

    $content = @()
    $content += 'FROM mcr.microsoft.com/dotnet/aspnet:' + $frameworkVersion
    $content += 'WORKDIR /app'
    $content += 'EXPOSE 80'
    $content += ''
    $content += 'FROM mcr.microsoft.com/dotnet/aspnet:' + $frameworkVersion
    $content += 'COPY ["docker/publish", "app/"]'
    $content += 'WORKDIR /app'
    $content += "ENTRYPOINT [`"dotnet`", `"$projectNameNoExtension.dll`"]"

    Set-Content -Path $dockerFullFileName -Value $content

    Write-Host 'OK!' -ForegroundColor Green
}

function CreateDockerImage ($parentPath, $dockerFullFileName, $imageName, $wsl) {

    Write-Host ''
    Write-Host 'Creating docker image...' -ForegroundColor DarkGreen

    $length = 0
	
	$containerNames
	if ($wsl -eq $true) {
		$containerNames = & wsl docker ps --format '{{.Names}}'
	} else {
		$containerNames = & docker ps --format '{{.Names}}'
	}

    if ($imageName -in $containerNames) {

        [void]($length = WriteBackground "Stopping container $imageName...")
		if ($wsl -eq $true) {
			[void](& wsl docker stop $imageName)
		} else {
			[void](& docker stop $imageName)
		}
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stop container $imageName"
        }
        [void](WriteBackground "" $length)
    }

	$stoppedContainerNames
	if ($wsl -eq $true) {
		$stoppedContainerNames = & wsl docker ps -f status=exited --format '{{.Names}}'
	} else {
		$stoppedContainerNames = & docker ps -f status=exited --format '{{.Names}}'
	}

    if ($imageName -in $stoppedContainerNames) {

        [void]($length = WriteBackground "Removing container $imageName..." $length)
		if ($wsl -eq $true) {
			[void](& wsl docker rm $imageName)
		} else {
			[void](& docker rm $imageName)
		}
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove container $imageName"
        }
        [void](WriteBackground "" $length)
    }

	$existinImageId
	if ($wsl -eq $true) {
		$existinImageId = & wsl docker images -q $imageName
	} else {
		$existinImageId = & docker images -q $imageName
	}

    if ($existinImageId) {
        
        [void]($length = WriteBackground "Removing image $imageName..." $length)
		if ($wsl -eq $true) {
			[void](& wsl docker rmi $imageName)
		} else {
			[void](& docker rmi $imageName)
		}
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove image $imageName"
        }
        [void](WriteBackground "" $length)
    }

    $realParentPath = $parentPath
    $realDockerFullFileName = $dockerFullFileName
    if ($wsl -eq $true) {
        $realParentPath = ConvertToLinuxPath $parentPath
        $realDockerFullFileName = ConvertToLinuxPath $dockerFullFileName
    }

	if ($wsl -eq $true) {
		& wsl docker build -f $realDockerFullFileName -t $imageName $realParentPath
	} else {
		& docker build -f $realDockerFullFileName -t $imageName $realParentPath
	}

    if ($LASTEXITCODE -ne 0) {
        throw "Docker image creation not succeded."
    }
    
    Write-Host 'OK!' -ForegroundColor Green
}

function WriteBackground([string]$text, [int]$length = 0) {

    $textToWrite = $text;
    if ($length -gt $text.Length) {
        $textToWrite = $text.PadRight($length - $text.Length, ' ');
    }

    Write-Host -NoNewLine "`r$textToWrite" -ForegroundColor DarkGray

    return $textToWrite.Length
}

function ConvertToLinuxPath($windowsPath) {

    $linuxPath = $windowsPath
    [string]$unit = $linuxPath[0]
    $linuxPath = $linuxPath.Replace($unit, $unit.ToLower())
    $linuxPath = "/mnt/" + $linuxPath
    $linuxPath = $linuxPath.Replace(':', '')
    $linuxPath = $linuxPath.Replace('\', '/')

    return $linuxPath
}

function PullFramework ($framework, $wsl) {

    Write-Host ''
    Write-Host 'Pulling .NET...' -ForegroundColor DarkGreen

	if ($wsl -eq $true) {
		& wsl docker pull mcr.microsoft.com/dotnet/aspnet:$framework
	} else {
		& docker pull mcr.microsoft.com/dotnet/aspnet:$framework
	}

    if ($LASTEXITCODE -ne 0) {
        throw "Docker .NET pull not succeded."
    }
    
    Write-Host 'OK!' -ForegroundColor Green
}

function RunDockerImage ($imageName, $port, $loggingConsole, $wsl) {

    Write-Host ''
    Write-Host 'Running docker image...' -ForegroundColor DarkGreen

    $portMapping = $port + ":80"

    if ($loggingConsole -eq $true) {

        $logging = "Logging__Console__FormatterName=`"`""
		if ($wsl -eq $true) {
			& wsl docker run -d --name $imageName -p $portMapping -e $logging $imageName
		} else {
			& docker run -d --name $imageName -p $portMapping -e $logging $imageName
		}
    } else {

		if ($wsl -eq $true) {
			& wsl docker run -d --name $imageName -p $portMapping $imageName
		} else {
			& docker run -d --name $imageName -p $portMapping $imageName
		}
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Docker image execution not succeded."
    }
    
    Write-Host 'OK!' -ForegroundColor Green
}

# VALIDATIONS

ValidateParameters $path $imageName $port
ValidatePath $path

$projectNameNoExtension = Split-Path -Path $path -Leaf
$projectName = $projectNameNoExtension + $extension
$projectFullName = Join-Path -Path $path -ChildPath $projectName

ValidateProjectFile $path $projectName $projectFullName

# PROCESS

$parentPath = Split-Path -Path $path
$buildPath = Join-Path -Path $parentPath -ChildPath '\docker\build'
$publishPath = Join-Path -Path $parentPath -ChildPath '\docker\publish'
$dockerFilePath = Join-Path -Path $parentPath -ChildPath '\docker'
$projectFramework = GetProjectFramework $framework
$dockerFullFileName = Join-Path $dockerFilePath -ChildPath 'Dockerfile'

RestoreDependencies $projectFullName
BuildProject $buildPath $projectFullName $projectFramework
PublishProject $publishPath $projectFullName
CopyDllsToPublishFolder $buildPath $publishPath
GenerateDockerFile $dockerFullFileName $framework $projectNameNoExtension
CreateDockerImage $parentPath $dockerFullFileName $imageName $wsl
PullFramework $framework $wsl
RunDockerImage $imageName $port $loggingConsole $wsl
