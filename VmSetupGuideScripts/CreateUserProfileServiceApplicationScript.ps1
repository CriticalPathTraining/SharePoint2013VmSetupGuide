$snapin = Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue -PassThru
if ($snapin -eq $null) {
    Write-Error "Unable to load the Microsoft.SharePoint.PowerShell Snapin! Have you installed SharePoint?"
    return
}

Write-Host 
Write-Host "This script is running under the identity of $env:USERNAME"
Write-Host 

$serviceApplicationName = "User Profile Service Application"
$serviceAppPoolName = "SharePoint Web Services Default"
$server = "WingtipServer"
$profileDBName = "SharePoint_UserProfileDB"
$socialDBName = "SharePoint_UserProfileSocialDB"
$profileSyncDBName = "SharePoint_UserProfileSyncDB"
$mySiteHostLocation = "http://my.wingtip.com"
$mySiteManagedPath = "personal"


Write-Host "Checking to see if User Profile Service Application has already been created..." 
$serviceApplication = Get-SPServiceApplication | where {$_.Name -eq $serviceApplicationName}
if($serviceApplication -eq $null) {
    Write-Host "Creating the User Profile Service Application..."
    $serviceApplication = New-SPProfileServiceApplication `
                                -Name $serviceApplicationName `
                                -ApplicationPool $serviceAppPoolName `
                                -ProfileDBName $profileDBName `
                                -ProfileDBServer $server `
                                -SocialDBName $socialDBName `
                                -SocialDBServer $server `
                                -ProfileSyncDBName $profileSyncDBName `
                                -ProfileSyncDBServer $server `
                                -MySiteHostLocation $mySiteHostLocation `
                                -MySiteManagedPath $mySiteManagedPath `
                                -SiteNamingConflictResolution None
    
    $serviceApplicationProxyName = "User Profile Service Application"
    Write-Host "Creating the User Profile Service Proxy..."
    $serviceApplicationProxy = New-SPProfileServiceApplicationProxy `
                                    -Name $serviceApplicationProxyName `
                                    -ServiceApplication $serviceApplication `
                                    -DefaultProxyGroup 
  
    Write-Host "User Profile Service Application and Proxy have been created by the SP_Farm account"
    Write-Host 
}


# Check to ensure it worked 
Get-SPServiceApplication | ? {$_.TypeName -eq "User Profile Service Application"} 

Write-Host 
Write-Host "This script will end and this window will close in 10 seconds" -ForegroundColor Yellow
Write-Host 

Start-Sleep -Seconds 10