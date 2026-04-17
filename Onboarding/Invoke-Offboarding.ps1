#Requires -RunAsAdministrator
#Requires -Module ActiveDirectory
<#
.SYNOPSIS
    Full offboarding workflow: disable account, remove groups, move OU, reset password.
.PARAMETER SamAccountName
    The user to offboard.
.PARAMETER DisabledOU
    Target OU for disabled accounts.
.PARAMETER ManagerNotify
    Email address to notify the user's manager.
.EXAMPLE
    .\Invoke-Offboarding.ps1 -SamAccountName jdoe -DisabledOU "OU=Disabled,DC=corp,DC=local"
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string] $SamAccountName,
    [string] $DisabledOU     = '',
    [string] $ManagerNotify  = '',
    [string] $SmtpServer     = 'smtp.corp.local'
)

$user = Get-ADUser -Identity $SamAccountName -Properties MemberOf, Manager, Mail, DisplayName, Description -ErrorAction Stop
Write-Host "Offboarding: $($user.DisplayName) ($SamAccountName)" -ForegroundColor Yellow

if ($PSCmdlet.ShouldProcess($user.DisplayName, 'Offboard user')) {

    # 1. Disable account
    Disable-ADAccount -Identity $SamAccountName
    Write-Host "[1/6] Account disabled" -ForegroundColor Green

    # 2. Reset to a random unguessable password
    $rndPass = ConvertTo-SecureString ([System.Web.Security.Membership]::GeneratePassword(24, 4)) -AsPlainText -Force
    Set-ADAccountPassword -Identity $SamAccountName -NewPassword $rndPass -Reset
    Write-Host "[2/6] Password randomized" -ForegroundColor Green

    # 3. Remove all group memberships (except Domain Users)
    $groups = $user.MemberOf
    foreach ($grp in $groups) {
        Remove-ADGroupMember -Identity $grp -Members $SamAccountName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Host "[3/6] Removed from $($groups.Count) group(s)" -ForegroundColor Green

    # 4. Stamp the description
    $note = "OFFBOARDED $(Get-Date -Format 'yyyy-MM-dd') by $env:USERNAME"
    Set-ADUser -Identity $SamAccountName -Description $note
    Write-Host "[4/6] Description updated" -ForegroundColor Green

    # 5. Move to disabled OU
    if ($DisabledOU) {
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $DisabledOU
        Write-Host "[5/6] Moved to: $DisabledOU" -ForegroundColor Green
    } else {
        Write-Host "[5/6] No DisabledOU specified — user stays in current OU" -ForegroundColor Yellow
    }

    # 6. Notify manager
    if ($ManagerNotify -or $user.Manager) {
        $to = $ManagerNotify
        if (-not $to -and $user.Manager) {
            $mgr = Get-ADUser -Identity $user.Manager -Properties Mail
            $to  = $mgr.Mail
        }
        if ($to) {
            $body = @"
The account for $($user.DisplayName) ($SamAccountName) has been disabled as part of the offboarding process on $(Get-Date -Format 'yyyy-MM-dd').

Actions taken:
- Account disabled
- Password randomized
- Group memberships removed

If you have any questions, contact the IT team.
"@
            Send-MailMessage -To $to -From "noreply@$env:USERDNSDOMAIN" -Subject "Offboarding: $($user.DisplayName)" `
                -Body $body -SmtpServer $SmtpServer -ErrorAction SilentlyContinue
            Write-Host "[6/6] Manager notified: $to" -ForegroundColor Green
        }
    }

    Write-Host "`nOffboarding complete for $SamAccountName" -ForegroundColor Cyan
}
