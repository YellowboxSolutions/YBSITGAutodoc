# Input bindings are passed in via param block.
param($Timer)


########################## Autotask ############################
write-host "Loading Autotask settings."
$ATSecurePassword = ConvertTo-securestring $ENV:ATPassword -AsPlainText -Force
$ATCredential = New-Object System.Management.Automation.PSCredential($ENV:ATUser, $ATSecurePassword)
$ATIntegrationCode = $ENV:ATIntegrationCode
Add-AutotaskAPIAuth -ApiIntegrationCode $ATIntegrationCode -credentials $ATCredential
$ATContracts = Get-AutotaskAPIResource -resource contracts -search '{"filter":[{"op":"in","field":"contractcategory","value":[11,12,13]},{"op":"contains","field":"Managed Services","value":"AzureAd","udf":true}],"includefields":["companyid","contractname","contractcategory","M365 Tenant ID",]}' `
                | select companyid,contractname,@{N='TenantId';E={$_.userDefinedFields.value}} 
########################## /Autotask ############################

########################## IT-Glue ############################
write-host "Loading ITGlue settings."
$APIKEy = $ENV:ITGKey
$APIEndpoint = $ENV:ITGEndpoint
$FlexAssetName = "Azure AD - AutoDoc v2"
$Description = "A network one-page document that shows the Azure AD settings."

Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
########################## /IT-Glue ############################

########################## Graph API ###########################
write-host "Loading PartnerCenter settings."
$ApplicationId         = $ENV:SAMApplicationId
$ApplicationSecret     = $ENV:SAMApplicationSecret 
$TenantID              = $ENV:SAMTenantId
$RefreshToken          = $ENV:SAMRefreshToken
$upn                   = $ENV:SAMUserPrincipleName

$PartnerToken = Get-AccessToken -TokenType 'Graph'
########################## /Graph API ###########################

write-host "Checking if Flexible Asset exists in IT-Glue." -foregroundColor green
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if (!$FilterID) { 
    write-host "Does not exist, creating new." -foregroundColor green
    $NewFlexAssetData = 
    @{
        type          = 'flexible-asset-types'
        attributes    = @{
            name        = $FlexAssetName
            icon        = 'sitemap'
            description = $description
        }
        relationships = @{
            "flexible-asset-fields" = @{
                data = @(
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 1
                            name            = "Primary Domain Name"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $true
                            "use-for-title" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 2
                            name           = "Users"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Guest Users"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Domain admins"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Applications"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "Devices"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 7
                            name           = "Domains"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    }
                )
            }
        }
    }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData 
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
}

write-host "Start documentation process." -foregroundColor green


foreach ($ATContract in $ATContracts) {
    $TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
    $Whitespace = "<br/>"
    $TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"

    $ATCompanyName = (Get-AutotaskAPIResource -Resource Companies -ID $ATContract.CompanyID).CompanyName
    write-host "Getting AzureAD Info for Autotask $($ATCompanyName) contract $($ATContract.ContractName)" -ForegroundColor green

    $CustomerGraphToken = Get-AccessToken -TenantId $ATContract.TenantId
    Connect-MgGraph -AccessToken $CustomerGraphToken|Out-null

    $AzureADPrimaryDomain = $null
    $AzureADHTMLDomains = $null
    $AzureADDomains = Get-MgDomain -All:$true
    $AzureADPrimaryDomain = ($AzureADDomains | Where-Object { $_.IsDefault -eq $true }).Id
    $AzureADHTMLDomains = $AzureADDomains | Select-Object Id, IsDefault, IsInitial, Isverified | ConvertTo-Html -Fragment | Out-String
    $AzureADHTMLDomains = $TableHeader + ($AzureADHTMLDomains -replace $TableStyling) + $Whitespace

    $AzureADNormalUsers = $null
    $AzureADUsers = Get-MgUser -Property "DisplayName,UserPrincipleName,UserType,Mail,ProxyAddresses" -All:$true
    $AzureADNormalUsers = $AzureADUsers | Where-Object { $_.UserType -eq "Member" } | Select-Object DisplayName, Mail, @{N='ProxyAddresses';E={$_.proxyaddresses|out-string}} | ConvertTo-Html -Fragment | Out-String
    $AzureADNormalUsers = $TableHeader + ($AzureADNormalUsers -replace $TableStyling) + $Whitespace
    
    $AzureADGuestUsers = $null
    $AzureADGuestUsers = $AzureADUsers | Where-Object { $_.UserType -ne "Member" } | Select-Object DisplayName, Mail | ConvertTo-Html -Fragment | Out-String
    $AzureADGuestUsers =  $TableHeader + ($AzureADGuestUsers -replace $TableStyling) + $Whitespace

    $AzureADAdminUsers = $null
    $AdminRole = Get-MgDirectoryRole | Where-Object { $_.Displayname -eq "Company Administrator"}
    if ($AdminRole) {
        $AzureADAdminUsers = $AdminRole|Get-MgDirectoryRoleMember
        $AzureADAdminUsers = $AzureADAdminUsers | Select-Object Displayname, mail | ConvertTo-Html -Fragment | Out-String
        $AzureADAdminUsers = $TableHeader + ($AdminUsers  -replace $TableStyling) + $Whitespace
    }

    $AzureADDevices = Get-MgDevice -All:$true -property "displayname,operatingsystem,operatingsystemversion,approximatelastsignindatetime,deviceversion,registeredowners"
    $AzureADDevices = $AzureADDevices | select-object DisplayName, OperatingSystem, OperatingSystemVersion, ApproximateLastSigninDateTime, DeviceVersion, RegisteredOwners | ConvertTo-Html -Fragment | Out-String
    $AzureADDevices = $TableHeader + ($AzureADDevices -replace $TableStyling) + $Whitespace

    $AzureADApplications = Get-MgApplication -All:$true
    $AzureADApplications = $AzureADApplications | Select-Object Displayname, PublisherDomain | ConvertTo-Html -Fragment | Out-String
    $AzureADApplications = $TableHeader + ($AzureADApplications -replace $TableStyling) + $Whitespace

    Disconnect-MgGraph

    $FlexAssetBody =
    @{
        type       = 'flexible-assets'
        attributes = @{
            traits = @{
                'primary-domain-name' = $AzureADPrimaryDomain
                'users'               = $AzureADNormalUsers
                'guest-users'         = $AzureADGuestUsers
                'domain-admins'       = $AzureADAdminUsers
                'applications'        = $AzureADApplications
                'devices'             = $AzureADDevices
                'domains'             = $AzureADHTMLDomains
            }
        }
    }

    $org = Get-ITGlueOrganizations -filter_psa_id $($ATContract.CompanyId) -filter_psa_integration_type 'autotask'
    $OrgID = $org.data.id
    $OrgName = $org.data.attributes.name

    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $OrgId).data | Where-Object { $_.attributes.traits.'primary-domain-name' -eq $AzureADPrimaryDomain }
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if (!$ExistingFlexAsset) {
        $FlexAssetBody.attributes.add('organization-id', $OrgId)
        $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
        write-host "Creating new Azure AD $($OrgName) into IT-Glue organisation $OrgId" -ForegroundColor Green
        New-ITGlueFlexibleAssets -data $FlexAssetBody
    }
    else {
        write-host "Updating Azure AD $($OrgName) into IT-Glue organisation $OrgId"  -ForegroundColor Green
        $ExistingFlexAsset = $ExistingFlexAsset[-1]
        Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
    }
}