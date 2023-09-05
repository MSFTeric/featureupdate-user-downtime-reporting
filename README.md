# Solution for retrieving user downtime due to Windows Feature Update restart

## Pre-Requisites

- Microsoft Entra ID
- Microsoft Intune
- Microsoft Azure Subscription 
- Windows 10 or Windows 11 clients that have undergone a Windows Feature Update through Windows Update for Business (WUfB) or Autopatch

## Create Log Analytics Workspace
(Chad to complete)

## Deploy Azure Monitor Client Agent
(Chad to complete)

## Import Script into Intune

Download the PS1 and create a new script deployment in Intune. Create a new group in Microsoft Entra ID that contains devices that have been targeted with a Feature Update. Assign script to group.

(Eric to flesh out all of the details)

## Log Analytics Kusto Query

(Add more details, capturing query here):

```
setupSummary_CL
| project TimeGenerated, splitValues = split(RawData, ",")
| project TimeGenerated, Hostname = split(splitValues[1], "=")[1], WindowsVersion = split(splitValues[2], "=")[1], DowntimeBegin = split(splitValues[3], "=")[1], DowntimeEnd = split(splitValues[4], "=")[1], DowntimeTotalMinutes = split(splitValues[5], "=")[1]
```

Export the results as a .CSV file
