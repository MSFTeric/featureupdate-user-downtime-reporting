<#
.SYNOPSIS
	This script determines the user downtime based on Windows 11 update restart time.

.DESCRIPTION
	This script gathers information from the setupact.log file generated during a Windows Feature Update.
	It gathers date/time attributes related to the start of the system restart and the end of the system restart.
	By calculating the difference between start and end times, the end user downtime can be calculated.
	The values are written to a log file where Azure Monitor or other monitoring agent can pull the values for analysis.

.PARAMETER
	-interactive 
		Run in interactive mode
		
		Required?					false
		Position?					0
		Default value				false
		Accept pipline input? 		false 
		Accept wildcard characters?	False
		
.EXAMPLE
	To run non-interactively, e.g. through an Intune PowerShell script deployed to a client:
	
		Get-Win11UpdateUserDowntime.ps1
	
	To run interactively and report back to the screen as well as the log file, run the following as a local administrator 
	
		Get-Win11UpdateUserDowntime.ps1 -interactive
		
.INPUTS 
	C:\Windows\Panther\Setupact.log
	
.OUTPUTS 
	C:\ProgramData\Microsoft\setupsummary.log 
	
DATE
	2023-09-11
	
VERSION
	1.0
	
UPDATES
	2023-09-11 Initial version of script
	
COPYRIGHT
	Copyright (c) Microsoft Corporation 2023. All rights reserved.
#>

param (
    [Parameter(Mandatory = $false)]
    [switch]$Interactive
)

function Get-IsElevated {
         <#
            .SYNOPSIS
                .Function to determine whether or not the script has been run elevated.

            .DESCRIPTION
                Returns True if script is being run elevated, False if not.

            .EXAMPLE
                Get-IsElevated
        #>
        process {
                $IsElevated = $null
                $WindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
                $WindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($WindowsID)
                $AdministratorRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
                if ($WindowsPrincipal.IsInRole($AdministratorRole))
                {
                    $IsElevated = $true
                }
                else
                {
                    $IsElevated = $false
                }
                Return $IsElevated
            } #end Process
} #end Get-IsElevated



function Retrieve-UserDowntimeStartDateTime() {
	 <#
		.SYNOPSIS
			.Function to return the line in setupact.log that contains the finalize critical boundary date/time stamp

		.DESCRIPTION
			Returns the date/time value
	#>

    param ([Parameter(Mandatory=$true)]$Log)
	
	$FinalizeCriticalBoundarySTartTime = $null
	
	$FinalizeCriticalBoundaryText = "Info                  SP      93|Finalize critical boundary "
	
	# Return the start time for $FinalizeCriticalBoundaryText, this will be the last entry with this text in setupact.log

	$FinalizeCriticalBoundaryStartTime = (Get-Content $Log | Select-String -Pattern $FinalizeCriticalBoundaryText | Select-Object -Last 1).Line.Split("|")[3]

    if ($FinalizeCriticalBoundaryStartTime -eq "" -or $FinalizeCriticalBoundarySTartTime -eq $null) {
        # Need to exit now, a bad value was returned
        exit 1
    }

    # Convert to an actual date/time and return value

	$DowntimeStart = Get-Date $FinalizeCriticalBoundaryStartTime
	
	return $DowntimeStart
		
} #end Retrieve-UserDowntimeStartDateTime



function Retrieve-UserDowntimeStopDatetime() {
	 <#
		.SYNOPSIS
			.Function to return the line in setupact.log that contains the start suspended services date/time stamp

		.DESCRIPTION
			Returns the date/time value
	#>
	
	param ([Parameter(Mandatory=$true)]$Log)
	
	$StartSuspendedServicesEndTime = $null
	
	$StartSuspendedServicesText   = "Info                  SP     146|Start suspended services"

    # Return the end time for $StartSuspendedServicesText, this will be the second-to-last entry with this text in setupact.log if all goes right

	$StartSuspendedServicesEndTime = (Get-Content $Log | Select-String -Pattern $StartSuspendedServicesText | Select-Object -Last 2).Line.Split("|")[4]

    if ($StartSuspendedServicesEndTime -eq "" -or $StartSuspendedServicesEndTime -eq $null) {
        # Need to exit now, a bad value was returned
        Exit 1
    }

    # Convert to an actual date/time and return value

	$DowntimeEnd = Get-Date $StartSuspendedServicesEndTime
	
	return $DowntimeEnd
	
} #End Retrieve-UserDowntimeStopDatetime


##########################################
#                                        #
#             Main processing            #
#                                        #
##########################################


# Verify interactive script is running elevated before proceeding

if ($PSBoundParameters.ContainsKey('Interactive')) {
	if (!(Get-IsElevated)) { 
			write-host "Script must be running as administrator, quitting." -ForegroundColor Red
		Exit 1
	}
}

# Set script version as a variable

$ScriptVersion = "1.0"

# Verify script is running on Windows 11 before proceeding

if ((Get-WmiObject Win32_OperatingSystem).caption -match "Microsoft Windows 11") {
	$DeviceHostname = $env:computername
	$WindowsVersion = (Get-WmiObject win32_OperatingSystem).Version
}
else {
	if ($PSBoundParameters.ContainsKey('Interactive')) {
		write-host "Script can only be run on a Windows 11 device, quitting." -ForegroundColor Red
	}
    Exit 1
}

$SetupLog = "C:\Windows\panther\setupact.log"

if (Test-Path $SetupLog) {

    # Calculate user downtime
     
    $StartUserDowntime = Retrieve-UserDowntimeStartDateTime($SetupLog)
	
	$EndUserDowntime = Retrieve-UserDowntimeStopDatetime($SetupLog)

    $TotalUserDowntimeRaw = New-TimeSpan $StartUserDowntime $EndUserDowntime
	
	$TotalUserDowntimeInMinutes = $TotalUserDowntimeRaw.Minutes
}
else {
	# No setupact.log found, exit with error
		if ($PSBoundParameters.ContainsKey('Interactive')) {
		write-host "Unable to find setup file $SetupLog, quitting..." -ForegroundColor Red
	}
    Exit 1
}
	

# Verify the Output Folder exists

$OutputFolder = "C:\ProgramData\Microsoft"

if ( -Not (Test-Path $OutputFolder)) {
    New-Item -ItemType directory -Path $FolderPath | Out-Null
}

# Verify Output Log File exists

$OutLogFile = "$OutputFolder\setupsummary.log"

if ( -Not (Test-Path $OutLogFile)) {
    New-Item -ItemType file -Path $OutLogFile -Force | Out-Null
}

# Write out data to log for Azure Monitor agent to pick up

write-output "ScriptVersion=$ScriptVersion,Hostname=$DeviceHostname,WindowsVersion=$WindowsVersion,DowntimeBegin=$StartUserDowntime,DowntimeEnd=$EndUserDowntime,DowntimeTotalMinutes=$TotalUserDowntimeInMinutes" | Out-File -FilePath $OutLogFile -Append -Encoding ASCII

# Write to screen if interactive mode selected

if ($PSBoundParameters.ContainsKey('Interactive')) {
	write-host "ScriptVersion=$ScriptVersion,Hostname=$DeviceHostname,WindowsVersion=$WindowsVersion,DowntimeBegin=$StartUserDowntime,DowntimeEnd=$EndUserDowntime,DowntimeTotalMinutes=$TotalUserDowntimeInMinutes" -ForegroundColor Yellow
}

# End Script without error

Exit 0
