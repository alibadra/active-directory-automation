#Requires -Version 5.1
#Requires -Module ActiveDirectory
<#
.SYNOPSIS
    Create Active Directory users in bulk from a CSV file.
.PARAMETER CsvPath
    Path to the CSV file. Required columns: FirstName, LastName, Department, Title, OU
    Optional: Manager, Office, Phone, Groups (semicolon-separated)
.PARAMETER DefaultPassword
    Initial password set for all new accounts (user must change at next logon).
.PARAMETER Domain
    AD domain suffix for UPN. Defaults to current domain.
.EXAMPLE
    .\New-ADUserBulk.ps1 -CsvPath .\users.csv -DefaultPassword 'Welcome@2024!'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string] $CsvPath,
    [Parameter(Mandatory)][string] $DefaultPassword,
    [string] $Domain = (Get-ADDomain).DNSRoot
)

$secPass = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$users   = Import-Csv -Path $CsvPath
$created = 0; $skipped = 0; $errors = 0

foreach ($u in $users) {
    $samAccount = ($u.FirstName[0] + $u.LastName).ToLower() -replace '\s', ''
    $upn        = "$samAccount@$Domain"
    $displayName = "$($u.FirstName) $($u.LastName)"

    if (Get-ADUser -Filter { SamAccountName -eq $samAccount } -ErrorAction SilentlyContinue) {
        Write-Warning "User already exists: $samAccount — skipped"
        $skipped++
        continue
    }

    try {
        $params = @{
            SamAccountName        = $samAccount
            UserPrincipalName     = $upn
            GivenName             = $u.FirstName
            Surname               = $u.LastName
            DisplayName           = $displayName
            Name                  = $displayName
            Department            = $u.Department
            Title                 = $u.Title
            AccountPassword       = $secPass
            Enabled               = $true
            ChangePasswordAtLogon = $true
            Path                  = $u.OU
        }
        if ($u.Office)  { $params.Office      = $u.Office }
        if ($u.Phone)   { $params.OfficePhone = $u.Phone }
        if ($u.Manager) {
            $mgr = Get-ADUser -Filter { SamAccountName -eq $u.Manager } -ErrorAction SilentlyContinue
            if ($mgr) { $params.Manager = $mgr.DistinguishedName }
        }

        if ($PSCmdlet.ShouldProcess($displayName, 'Create AD user')) {
            New-ADUser @params
            Write-Host "Created: $samAccount ($displayName)" -ForegroundColor Green

            # Add to groups
            if ($u.Groups) {
                foreach ($grp in $u.Groups -split ';') {
                    $grp = $grp.Trim()
                    try {
                        Add-ADGroupMember -Identity $grp -Members $samAccount
                        Write-Host "  Added to group: $grp" -ForegroundColor Gray
                    } catch {
                        Write-Warning "  Could not add to group $grp`: $_"
                    }
                }
            }
            $created++
        }
    } catch {
        Write-Error "Failed to create $displayName`: $_"
        $errors++
    }
}

Write-Host "`nDone — Created: $created | Skipped: $skipped | Errors: $errors" -ForegroundColor Cyan
