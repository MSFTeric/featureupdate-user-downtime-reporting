# Retrieve user downtime due to Windows Feature Update restart

## Pre-Requisites

- Microsoft Entra ID
- Microsoft Intune
- Microsoft Azure Subscription 
- Windows 11 clients that have undergone a Windows Feature Update through Windows Update for Business (WUfB) or Autopatch

## Create Log Analytics Workspace
(Chad to complete)

## Deploy Azure Monitor Client Agent
(Chad to complete)

## Create a Device Group in Microsoft Entra ID

As an Entra ID adminstrator with rights to create new groups, open the Entra ID portal and create a new device group that contains one or more of your Windows devices that have undergone a Windows 11 Feature Update.  

## Create and Deploy Intune Script Policy

Download the file Get-Win11UpdateUserDowntime.ps1 from this repository.

Follow the steps at [Microsoft Learn](https://learn.microsoft.com/en-us/mem/intune/apps/intune-management-extension#create-a-script-policy-and-assign-it) to create a new Intune script policy, with the following options set:

- Set *Run this script using the logged on credentials* to **No**
- Set *Enforce script signature check* to **No**
- Set *Run scripts in 64 bit PowerShell host* to **Yes**
- In the *Select groups to include* step, select the device group created earlier in this process

After the targeted devices query for new scripts to run, the script will be downloaded and executed on the device. This will create a local log file, C:\ProgramData\Microsoft\SetupSummary.log

The Azure Monitor client will detect a new entry has been made to SetupSummary.log and write the data back to your Log Analytics workspace.

Confirm the Device Status for this script shows success before proceeding into Log Analytics.

## Log Analytics Kusto Query

Log into your Log Analytics workspace, paste in the following KQL query and then select **Run**.

```
setupSummary_CL
| project TimeGenerated, splitValues = split(RawData, ",")
| project TimeGenerated, Hostname = split(splitValues[1], "=")[1], WindowsVersion = split(splitValues[2], "=")[1], DowntimeBegin = split(splitValues[3], "=")[1], DowntimeEnd = split(splitValues[4], "=")[1], DowntimeTotalMinutes = split(splitValues[5], "=")[1]
```

This will generate the results in a simple table as shown below:

![Win11UserDowntimeAnalyticsResults](https://github.com/MSFTeric/featureupdate-user-downtime-reporting/assets/44607393/f91498ae-dd10-43b6-ab56-6f4d46a9d122)

To export the data, select the **Export -> CSV (displayed columns)** option from the query header.
