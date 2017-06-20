$snapin = Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue -PassThru
if ($snapin -eq $null) {
    Write-Error "Unable to load the Microsoft.SharePoint.PowerShell Snapin! Have you installed SharePoint?"
    return
}

$currentScriptPath = $MyInvocation.MyCommand.Path
$scriptFolder = Split-Path $currentScriptPath
$targetScriptPath = Join-Path $scriptFolder "\CreateUserProfileServiceApplicationScript.ps1"

function Create-UserProfileServiceApplication {

    $service = Get-SPServiceInstance | where {$_.TypeName -eq "User Profile Service"}

    if ($service -eq $null) {
        Write-Warning "Unable to locate the user profile service! Did you run the configuration wizard to create a new farm?"
        return
    }
    if ($service.Status -ne "Online") {
        Write-Host "Starting User Profile Service instance" -NoNewline
        $service | Start-SPServiceInstance | Out-Null

        # ensure the service is online before attempting to add a svc app.
        while ($true) {
            Start-Sleep 2
            Write-Host "." -NoNewLine
            $svc = Get-SPServiceInstance | where {$_.TypeName -eq "User Profile Service"}
            if ($svc.Status -eq "Online") { break }
        }
        Write-Host
    }

    # call to script which can run as WINGTIP\SP_Farm with administrator privledges
    # this will require you to choose OK when prompted about elevation
    Write-Host "Executing script $targetScriptPath using credentials of SP_Workflow"

    # Get the Farm Account Creds 
    $servicesAccountName = "WINGTIP\SP_Farm"
    $servicesAccountPassword = "Password1"
    $servicesAccountecureStringPassword = ConvertTo-SecureString -String $servicesAccountPassword -AsPlainText -Force
    $farmAccountCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicesAccountName, $servicesAccountecureStringPassword 

    # Create a new process with UAC elevation 
    Start-Process $PSHOME\powershell.exe `
                  -Credential $farmAccountCredentials `
                  -ArgumentList "-Command Start-Process $PSHOME\powershell.exe -ArgumentList `"'$targetScriptPath'`" -Verb Runas" -Wait 

}

function Start-UserProfileSynchronizationService {

    $svc = Get-SPServiceInstance | where {$_.TypeName -eq "User Profile Synchronization Service"}
    $app = Get-SPServiceApplication -Name "User Profile Service Application"

    if ($svc -eq $null) {
        Write-Warning "Unable to locate the user profile synchronization service! Did you run the configuration wizard to create a new farm?"
        return
    }
    if ($app -eq $null) {
        Write-Warning "Unable to locate the user profile service application!"
        return
    }
    if ($svc.Status -ne "Online") {
        Write-Host "Starting the User Profile Service Synchronization instance (cross your fingers)" -NoNewline
        $svc.Status = "Provisioning"
        $svc.IsProvisioned = $false
        $svc.UserProfileApplicationGuid = $app.Id
        $svc.Update()

        $app.SetSynchronizationMachine("WingtipServer", $svc.Id, "WINGTIP\SP_Farm", "Password1")
          
        $svc | Start-SPServiceInstance | Out-Null
        
        # ensure the service is online before attempting to add a svc app.
        # blocking on service start disable to reach end of script
        while ($true) {
            Start-Sleep 5
            Write-Host "." -NoNewLine
            $svc = Get-SPServiceInstance $svc.Id
            if ($svc.Status -eq "Online") { break }
        }

        Write-Host
    }
}

function Set-UPSConnectionPermission{
    $accountName = "WINGTIP\Administrator"
    Write-Host "Setting connection permissions for $accountName"

    $claimType = "http://schemas.microsoft.com/sharepoint/2009/08/claims/userlogonname"
    $claimValue = $accountName
    $claim = New-Object Microsoft.SharePoint.Administration.Claims.SPClaim($claimType, $claimValue, "http://www.w3.org/2001/XMLSchema#string", [Microsoft.SharePoint.Administration.Claims.SPOriginalIssuers]::Format("Windows"))
    $claim.ToEncodedString()
 
    $permission = [Microsoft.SharePoint.Administration.AccessControl.SPIisWebServiceApplicationRights]"FullControl"
 
    $SPAclAccessRule = [Type]"Microsoft.SharePoint.Administration.AccessControl.SPAclAccessRule``1"
    $specificSPAclAccessRule = $SPAclAccessRule.MakeGenericType([Type]"Microsoft.SharePoint.Administration.AccessControl.SPIisWebServiceApplicationRights")
    $ctor = $SpecificSPAclAccessRule.GetConstructor(@([Type]"Microsoft.SharePoint.Administration.Claims.SPClaim",[Type]"Microsoft.SharePoint.Administration.AccessControl.SPIisWebServiceApplicationRights"))
    $accessRule = $ctor.Invoke(@([Microsoft.SharePoint.Administration.Claims.SPClaim]$claim, $permission))
 
    $ups = Get-SPServiceApplication | ? { $_.TypeName -eq 'User Profile Service Application' }
    if ($ups -eq $null) {
        Write-Warning "Unable to locate the user profile service application!"
        return
    }

    $accessControl = $ups.GetAccessControl()
    $accessControl.AddAccessRule($accessRule)
    $ups.SetAccessControl($accessControl)
    $ups.Update()
}

Create-UserProfileServiceApplication

Start-UserProfileSynchronizationService

Set-UPSConnectionPermission


Write-Host 
Read-Host -Prompt "Press ENTER to continue"