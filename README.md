# Active Directory Automation

PowerShell scripts for automating Active Directory user lifecycle management, group management, and reporting. Requires RSAT / AD PowerShell module.

## Scripts

### Users
| Script | Description |
|--------|-------------|
| `Users/New-ADUserBulk.ps1` | Create users from CSV with OU, groups, mailbox |
| `Users/Disable-InactiveUsers.ps1` | Disable accounts inactive for N days |
| `Users/Export-UserReport.ps1` | Full AD user report with last logon, group membership |

### Groups
| Script | Description |
|--------|-------------|
| `Groups/Sync-GroupMembership.ps1` | Sync group members from a CSV source of truth |
| `Groups/Get-NestedGroupMembers.ps1` | Recursively resolve nested group members |

### Onboarding
| Script | Description |
|--------|-------------|
| `Onboarding/Invoke-Onboarding.ps1` | Full user onboarding (create, add groups, home folder, email) |
| `Onboarding/Invoke-Offboarding.ps1` | Full offboarding (disable, move OU, remove groups, archive) |

### Reports
| Script | Description |
|--------|-------------|
| `Reports/Get-ADHealthReport.ps1` | DC replication, SYSVOL, FSMO roles status |
| `Reports/Get-PrivilegedAccounts.ps1` | Audit Domain Admins, Enterprise Admins, Schema Admins |

## Requirements

```powershell
# Install RSAT AD tools (Windows Server)
Install-WindowsFeature RSAT-AD-PowerShell

# Or on Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

## Quick Start

```powershell
Import-Module ActiveDirectory

# Bulk create users from CSV
.\Users\New-ADUserBulk.ps1 -CsvPath .\users.csv -DefaultPassword 'Welcome@2024!'

# Disable inactive users (90 days) — dry run first
.\Users\Disable-InactiveUsers.ps1 -DaysInactive 90 -WhatIf
```
