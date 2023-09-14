# Retrieve user downtime due to Windows Feature Update restart

## Purpose

This solution will use an Intune-delivered PowerShell script to capture the amount of user downtime experienced on a device due to the restart to update a device to Windows 11. This data is then collected into Log Analytics where it can be analyzed by IT Admins to understand expected average downtime for end users. This information can be used as part of end user communications during a Windows 11 production rollout (e.g. "When you select to restart your device, you can expect an average of 35 minutes for the process to complete and return you to the logon screen.")

## Pre-Requisites

- Microsoft Entra ID
- Microsoft Intune
- Microsoft Azure Subscription 
- Windows 11 clients that have undergone a Windows Feature Update through Windows Update for Business (WUfB) or Autopatch

## Create Log Analytics Workspace
Follow the steps at [Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace?tabs=azure-portal) to create a Log Analytics workspace in your tenant.

Note the *Region* and the *Name* of your Log Analytics workspace. You will need these details for your data collection rules.

## Deploy Azure Monitor Client Agent
(Chad to complete)

## Configure Azure Monitor Data Collection Rules

In order to collect data from your devices, you will need to configure a data collection rule. You must create the data collection rule in the *same region* as your Log Analytics workspace. 

To configure the Data Collection Rule, navigate to the Azure portal and open the **Monitor** menu. Under *Settings* select **Data Collection Rules** 

Select **Create** to create a new data collection rule and associations.

* Name the Rule **setupSummary.log**
* Specify the correct **Azure subscription**, **Resource Group**, and **Region**
*    *Remember, the data collection rule must be in the same region as your Log Analytics workspace*
* Select the Platform Type **Windows**
* On the **Resources** tab, add your machines...CHECK WITH CHAD ON THIS WHEN IT COMES TO PHYSICAL MACHINES
* On the **Collect and deliver** tab, select **Add data source** to add a data source and destination
* Select the *Data Source type* **Custom Text Logs**
* Select the *File Pattern* **C:\ProgramData\Microsoft\setupsummarylog**
* Select the table name **setupSummary_CL**
* The record delimiter should default to **End-of-Line**
* Set the *Transform* to **source**
* On the **Destination* tab, add the *Destination Type* **Azure Monitor Logs** and then select the appropriate **Subscription** and the **Log Analytics workspace** created at the beginning of this process.
* Review your details and then select **Create** to create your data collection rule.


## Create a Device Group in Microsoft Entra ID

As an Entra ID adminstrator with rights to create new groups, open the Entra ID portal and create a **new device group** that contains one or more of your Windows devices that have undergone a Windows 11 Feature Update. 

Optionally, you can create a dynamic device group based upon Windows 11 devices.

## Create and Deploy Intune Script Policy

**Download** the file **Get-Win11UpdateUserDowntime.ps1** from this repository.

Follow the steps at [Microsoft Learn](https://learn.microsoft.com/en-us/mem/intune/apps/intune-management-extension#create-a-script-policy-and-assign-it) to create a new Intune script policy, with the following options set:

- Set *Run this script using the logged on credentials* to **No**
- Set *Enforce script signature check* to **No**
- Set *Run scripts in 64 bit PowerShell host* to **Yes**
- In the *Select groups to include* step, select the device group created earlier in this process

After the targeted devices query for new scripts to run, the script will be downloaded and executed on the device. This will create a local log file, C:\ProgramData\Microsoft\SetupSummary.log

The Azure Monitor client will detect a new entry has been made to SetupSummary.log and write the data back to your Log Analytics workspace.

Confirm the Device Status for this script shows success before proceeding into Log Analytics.

## What data is collected?

The script will execute on a Windows 11 device and parse the setupact.log file generated during an upgrade from Windows 10 to Windows 11. The script will then log the following information, in a single line, into C:\ProgramData\Microsoft\Setupsummary.log:

* The script version number. This allows you to deploy updated versions of the script and know which data set you are working with.
* The device hostname.
* The source Windows version (very likely a Windows 10 version number)
* The upgraded Windows version (a Windows 11 version number)
* The date and time the restart began in order to apply the update
* The data and time the restart completed after applying the update
* The elapsed time in minutes between the reboot's start time and end time 

## Log Analytics Kusto Queries

### Table view of user downtime

Log into your Log Analytics workspace, paste in the following KQL query and then select **Run**.

```
setupSummary_CL
| project TimeGenerated, splitValues = split(RawData, ",")
| project TimeGenerated, Hostname = split(splitValues[1], "=")[1], SourceWindowsVersion = split(splitValues[2], "=")[1], WindowsVersion = split(splitValues[3], "=")[1], DowntimeBegin = split(splitValues[4], "=")[1], DowntimeEnd = split(splitValues[5], "=")[1], DowntimeTotalMinutes = split(splitValues[6], "=")[1]
```
This will generate the results in a  table as shown below:
![image](https://github.com/MSFTeric/featureupdate-user-downtime-reporting/assets/44607393/2b83b3d5-2b21-4ef3-a288-0a06acdbafb3)
To export the data, select the **Export -> CSV (displayed columns)** option from the query header.

### Column chart of average downtime based on target OS version

Log into your Log Analytics workspace, paste in the following KQL query and then select **Run**

```
setupSummary_CL
| project TimeGenerated, splitValues = split(RawData, ",")
| project TimeGenerated, Hostname = split(splitValues[1], "=")[1], SourceWindowsVersion = tostring(split(splitValues[2], "=")[1]), WindowsVersion = tostring(split(splitValues[3], "=")[1]), DowntimeBegin = split(splitValues[4], "=")[1], DowntimeEnd = split(splitValues[5], "=")[1], DowntimeTotalMinutes = todouble(split(splitValues[6], "=")[1])
| summarize avg(DowntimeTotalMinutes) by WindowsVersion
| render columnchart
```
This will generate a column chart similar to the image below:
![image](https://github.com/MSFTeric/featureupdate-user-downtime-reporting/assets/44607393/24c90b83-bc4d-495b-b87b-4dfbb77d10a8)


### Bar chart of downtime for each device

Log into your Log Analytics workspace, paste in the following KQL query and then select **Run**

```
setupSummary_CL
| project TimeGenerated, splitValues = split(RawData, ",")
| project TimeGenerated, Hostname = tostring(split(splitValues[1], "=")[1]), SourceWindowsVersion = tostring(split(splitValues[2], "=")[1]), WindowsVersion = split(splitValues[3], "=")[1], DowntimeBegin = split(splitValues[4], "=")[1], DowntimeEnd = split(splitValues[5], "=")[1], DowntimeTotalMinutes = todouble(split(splitValues[6], "=")[1])
| summarize avg(DowntimeTotalMinutes) by Hostname
| render barchart
```
This will generate a bar chart similar to the image below:
![image](https://github.com/MSFTeric/featureupdate-user-downtime-reporting/assets/44607393/cdf44229-303d-43ca-9a82-3b9c0f6d74fe)

