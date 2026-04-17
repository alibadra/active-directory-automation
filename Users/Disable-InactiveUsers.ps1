#Requires -Version 5.1
#Requires -Module ActiveDirectory
<#
.SYNOPSIS
    Disable AD accounts that haven't logged on in N days.
    Moves them to a disabled OU and removes group memberships.
.PARAMETER DaysInactive
    Accounts not seen for this many days will be disabled. Default: 90
.PARAMETER DisabledOU
    OU where disabled accounts are moved. Default: OU=Disabled,DC=domain,DC=com
.PARAMETER ExcludeGroups
    Groups whose members are never disabled (e.g. service accounts).
.PARAMETER WhatIf
    Show what would happen without making changes.
.EXAMPLE
    .\Disable-InactiveUsers.ps1 -DaysInactive 90 -WhatIf
    .\Disable-InactiveUsers.ps1 -DaysInactive 90 -DisabledOU "OU=Disabled,DC=corp,DC=local"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [int]      $DaysInactive   = 90,
    [string]   $DisabledOU     = '',
    [string[]] $ExcludeGroups  = @('Service Accounts', 'Domain Admins')
)

$cutoff  = (Get-Date).AddDays(-$DaysInactive)
$domain  = Get-ADDomain
if (-not $DisabledOU) { $DisabledOU = "OU=Disabled,OU=Users,$($domain.DistinguishedName)" }

# Get excluded SIDs
$excludedSIDs = [System.Collections.Generic.HashSet[string]]::new()
foreach ($grp in $ExcludeGroups) {
    try {
        (Get-ADGroupMember -Identity $grp -Recursive).SID | ForEach-Object { $excludedSIDs.Add($_.Value) | Out-Null }
    } catch { Write-Warning "Could not resolve group: $grp" }
}

$inactive = Get-ADUser -Filter { Enabled -eq $true } -Properties LastLogonDate, MemberOf, Description |
    Where-Object {
        ($_.LastLogonDate -lt $cutoff -or -not $_.LastLogonDate) -and
        -not $excludedSIDs.Contains($_.SID.Value)
    }

Write-Host "Found $($inactive.Count) inactive account(s) (threshold: $DaysInactive days)" -ForegroundColor Yellow

$disabled = 0
foreach ($user in $inactive) {
    $lastLogon = if ($user.LastLogonDate) { $user.LastLogonDate.ToString('yyyy-MM-dd') } else { 'Never' }
    Write-Host "  $($user.SamAccountName) — last logon: $lastLogon"

    if ($PSCmdlet.ShouldProcess($user.SamAccountName, 'Disable account')) {
        # Stamp description before disabling
        Set-ADUser $user -Description "Disabled $(Get-Date -Format 'yyyy-MM-dd') — inactive $DaysInactive days. Was: $($user.Description)"

        # Remove from all groups (except Domain Users)
        $user.MemberOf | ForEach-Object {
            Remove-ADGroupMember -Identity $_ -Members $user.SamAccountName -Confirm:$false -ErrorAction SilentlyContinue
        }

        Disable-ADAccount -Identity $user
        if ($DisabledOU) {
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $DisabledOU -ErrorAction SilentlyContinue
        }
        $disabled++
    }
}

Write-Host "`nDisabled: $disabled account(s)" -ForegroundColor $(if ($disabled -gt 0) { 'Yellow' } else { 'Green' })
