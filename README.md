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

## Import Script into Intune

Download the file Get-Win11UpdateUserDowntime.ps1 from this repository.

Open the Intune portal as an Intune Administrator, or an administrator who has rights to create and deploy Scripts.

In the Intune portal, select **Devices**. In the *Devices* blade, navigate to the *Policy* section and select **Scripts**. In the *Scripts* blade, select the **Add** drop-down and select **Windows 10 and later**:

- Give the script a name in Intune, along with a description and then click **Next**.
- At the *script location*, browse to the downloaded Get-Win11UpdateUserDowntime.ps1 file.
- Set *Run this script using the logged on credentials* to **No**.
- Set *Enforce script signature check* to **No**.
- Set *Run scripts in 64 bit PowerShell host* to **Yes** and then click **Next**.
- In the *Included groups* select **Add groups** and then select the device group created earlier in this process. Click **Next**.
- Confirm the settings and then click **Add**

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
