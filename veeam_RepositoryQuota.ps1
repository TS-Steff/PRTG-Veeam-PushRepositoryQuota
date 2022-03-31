<#

    .SYNOPSIS
    PRTG push Veeam all Job Status
    
    .DESCRIPTION
    Advanced Sensor will report Result of all jobs
    
    .EXAMPLE
    veeam-RepositoryQuota.ps1

    .EXAMPLE
    veeam-RepositoryQuota.ps1 -TenantName "tenant Name"

    .EXAMPLE
    veeam-RepositoryQuota.ps1 -DryRun

    .EXAMPLE
    veeam-RepositoryQuota.ps1 -TenantName "tenant Name" -DryRun

    .NOTES
    +---------------------------------------------------------------------------------------------+ 
    | ORIGIN STORY                                                                                |
    +---------------------------------------------------------------------------------------------| 
    |   DATE        : 2022.03.03                                                                  |
    |   AUTHOR      : TS-Management GmbH, Stefan Mueller                                          | 
    |   DESCRIPTION : PRTG Push Veeam Backup State                                                |
    +---------------------------------------------------------------------------------------------+

    .Link
    https://ts-man.ch
#>
<# TODO
    - PRTG XML Percent Min Max Value
#>
[cmdletbinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
        [string]$TenantName,
	[Parameter(Position=1, Mandatory=$false)]
		[switch]$DryRun = $false
)


##### COFNIG START #####
$probeIP = "PROBE"
$sensorPort = "PORT"
$sensorKey ="KEY"
$LimitWarninPercent = 80
$LimitErrorPercent = 90
#####  CONFIG END  #####

# check if veeam powershell snapin is loaded. if not, load it
if( (Get-PSSnapin -Name veeampssnapin -ErrorAction SilentlyContinue) -eq $nul){
    Add-PSSnapin veeampssnapin
}

if($TenantName){
    $Tenants = Get-VBRCloudTenant -Name $TenantName
    write-host "Tenant Name " $TenantName -ForegroundColor Green
}else{
    $Tenants = Get-VBRCloudTenant
}

$repoTable = @()

foreach($Tenant in $Tenants){
    $tenantResoucres = $Tenant.Resources

    if($tenantResoucres.Count -eq 1){
        foreach($tenantResoucre in $tenantResoucres){

            if($TenantName){
                $repoObj += [PSCustomObject]@{
                    "Tenant"     = $Tenant.Name
                    "Repository" = $tenantResoucre.RepositoryFriendlyName
                    "Size MB"    = $tenantResoucre.RepositoryQuota
                    "Used MB"    = $tenantResoucre.UsedSpace
                    "Used %"     = $tenantResoucre.UsedSpacePercentage
                }
            }else{
                $repoObj = [PSCustomObject]@{
                    "Tenant"     = $Tenant.Name
                    "Used %"     = $tenantResoucre.UsedSpacePercentage
                }
            }
            
            $repoTable += $repoObj
        }
    }elseif($tenantResoucres.Count -eq 0){
        write-verbose "Tenant does not have online Repository"
    
    }else{
        Write-Error "More then one Repository for this customer available"
        exit
    }
    
    write-host ""
}

if($DryRun){
    $repoTable | Format-Table * -Autosize
}



### PRTG XML Header ###
$prtgresult = @"
<?xml version="1.0" encoding="UTF-8" ?>
<prtg>
  <text></text>

"@


### PRTG CONTENT TENANT REPO ###
if($TenantName){



### PRTG CONTENT ALL REPOS ###   
}else{

foreach($repo in $repoTable){
    $rowName = $repo.Tenant
    $rowUsedPercent = $repo.'Used %'
    


$prtgresult += @"
  <result>
    <channel>$rowName</channel>
    <unit>Percent</unit>
    <value>$rowUsedPercent</value>
    <showChart>1</showChart>
    <showTable>1</showTable>

    <LimitMaxWarning>$LimitWarninPercent</LimitMaxWarning>
    <LimitMaxError>$LimitErrorPercent</LimitMaxError>
    
    <LimitWarningMsg>$LimitWarninPercent% Quota used</LimitWarningMsg>
    <LimitErrorMsg>$LimitErrorPercent% Quota used</LimitErrorMsg>

    <LimitMode>1</LimitMode>
    <float>1</float>
  </result>

"@
}

}


### PRTG XML Footer ###
$prtgresult += @"
</prtg>
"@

### Push to PRTG ###
function sendPush(){
    Add-Type -AssemblyName system.web

    write-host "result"-ForegroundColor Green
    write-host $prtgresult 

    #$Answer = Invoke-WebRequest -Uri $NETXNUA -Method Post -Body $RequestBody -ContentType $ContentType -UseBasicParsing
    $answer = Invoke-WebRequest `
       -method POST `
       -URI ("http://" + $probeIP + ":" + $sensorPort + "/" + $sensorKey) `
       -ContentType "text/xml" `
       -Body $prtgresult `
       -usebasicparsing

       #-Body ("content="+[System.Web.HttpUtility]::UrlEncode.($prtgresult)) `
    #http://prtg.ts-man.ch:5055/637D334C-DCD5-49E3-94CA-CE12ABB184C3?content=<prtg><result><channel>MyChannel</channel><value>10</value></result><text>this%20is%20a%20message</text></prtg>   
    if ($answer.statuscode -ne 200) {
       write-warning "Request to PRTG failed"
       write-host "answer: " $answer.statuscode
       exit 1
    }
    else {
       $answer.content
    }
}

if($DryRun){
    write-host $prtgresult
}else{
    sendPush
}