properties {
	$base_dir = resolve-path .
	$configuration = "Debug"
	$environment = "QA"
}

task default -depends Clean, Build, Test

task Clean {
	$folders_to_clean = @(
		".\TestProject1\bin",
		".\TestProject1\obj",
		".\TestProject2\bin",
		".\TestProject2\obj"
	) 

	$folders_to_clean | foreach-object ($_) {
		if (Test-Path $_) { Remove-Item -force -recurse $_ }
	}
}

task Build {
	$v4_net_version = (ls "$env:windir\Microsoft.NET\Framework\v4.0*").Name

	Write-Host "Using $v4_net_version"
	exec { &"C:\Windows\Microsoft.NET\Framework\$v4_net_version\MSBuild.exe" "$base_dir\TestProject1.sln" }
}

task Test {
	$test_assemblies = (Get-ChildItem "." -recurse -filter "*.dll") |
														? { $_.FullName -match "\\bin\\$configuration\\Test.*?\d\.dll" }
								
	Invoke-MSTest $test_assemblies "test.trx"
}

function Invoke-MSTest
{
  [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)] [System.IO.FileInfo[]]$TestDll = $null,
        [Parameter(Position=1,Mandatory=0)] [string]$ResultTrx = $null
        )
				
		if ($ResultTrx -eq $null -or $resultTrx -eq "") {
			$ResultTrx = "$TestDll.trx"
		}

		$mstest = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE\mstest.exe"
        
    Write-Host "Running Tests:"
		Write-Host "- Located at:" $TestDll 
		Write-Host "-  Output to:" $ResultTrx
    
    if ( Test-Path $ResultTrx )       
    {
        Write-Host "Found" $ResultTrx "it will be deleted prior to running the test"
        Remove-Item $ResultTrx
    }       

		$command_args = @()
		$TestDll | foreach-object ($_) {
			$path_to_test_assembly = $_.FullName
			$command_args += "/testcontainer:`"$path_to_test_assembly`""
		}

		$command_args += "/resultsfile:`"$ResultTrx`""
		$command_string = $command_args -join ' '

		&$mstest $command_args

		Write-Host ""
		Write-Output "##teamcity[importData type='mstest' path='$ResultTrx']"

		return 

		$result = (&$mstest $command_args)

		Write-Host ""
    
    foreach( $line in $result )
    {
        if ( $line -ne $null )
        {
            if ($line.StartsWith("Failed") -eq $true -or $line -match "^\d+\/\d+ test")
            {
                $line
            }
        }
    }

		Write-Host ""

		
}
