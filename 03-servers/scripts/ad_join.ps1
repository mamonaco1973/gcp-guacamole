# ------------------------------------------------------------
# Join the Windows host to the mini-AD (first boot only)
# ------------------------------------------------------------
# GCP runs windows-startup-script-ps1 at every boot. After the
# join and its reboot the machine is in the domain: stop here.

if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
    Write-Output "Already joined to the domain; nothing to do."
    exit 0
}

# Suppress progress bars to speed up execution
$ProgressPreference = 'SilentlyContinue'

# ------------------------------------------------------------
# Install Active Directory Components
# ------------------------------------------------------------

Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

# ------------------------------------------------------------
# Join instance to active directory
# ------------------------------------------------------------
# The DC can still be settling when this VM boots, so retry.

$secretJson = gcloud secrets versions access latest --secret="${admin_secret}"
$secretObject = $secretJson | ConvertFrom-Json
$password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
$username = $secretObject.username
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password

for ($i=1; $i -le 10; $i++) {
    try {
        Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force -ErrorAction Stop
        Write-Output "Successfully joined the domain."
        break
    } catch {
        Write-Output "WARN: Join attempt $i failed - waiting 30 seconds..."
        if ($i -eq 10) { throw }
        Start-Sleep -Seconds 30
    }
}

# ------------------------------------------------------------
# Grant RDP Access to All Users in "mcloud-users" Group
# ------------------------------------------------------------

Write-Output "Add users to the Remote Desktop Users Group"
$domainGroup = "${netbios}\mcloud-users"

for ($i=1; $i -le 10; $i++) {
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $domainGroup -ErrorAction Stop
        Write-Output "SUCCESS: Added $domainGroup to Remote Desktop Users"
        break
    } catch {
        Write-Output "WARN: Attempt $i failed - waiting 30 seconds..."
        Start-Sleep -Seconds 30
    }
}

# ------------------------------------------------------------
# Final Reboot to Apply Changes
# ------------------------------------------------------------

Write-Output "Finalize join with a reboot"
shutdown /r /t 5 /c "Initial reboot to join domain" /f /d p:4:1
