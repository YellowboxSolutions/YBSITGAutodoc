# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
# if ($env:MSI_SECRET) {
    # Disable-AzContextAutosave -Scope Process | Out-Null
    # Connect-AzAccount -Identity
# }

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

# You can also define functions or aliases that can be referenced in any of your PowerShell functions.

# import-module '.\Modules\ITGlueAPI\ITGlueAPI'
$DefaultBaseUri = 'https://graph.microsoft.com/v1.0'

function Get-AccessToken {
    param (
        [Parameter()]
        [ValidateSet('Graph')]
        [string]
        $TokenType = 'Graph',

        [Parameter()]
        [string]
        $TenantId
    )

    if ($TokenType -eq 'Graph') {
        $RequestBody = @{
                client_id     = $ApplicationId
                client_secret = $ApplicationSecret
                scope         = 'https://graph.microsoft.com/.default'
                refresh_token = $RefreshToken
                grant_type    = 'refresh_token'
        }
    }
    
    if (!$TenantId) {$TenantId = $ENV:SAMTenantId}
    
    $ResponseBody = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$($tenantid)/oauth2/v2.0/token" -Body $RequestBody -ErrorAction Stop

    $ResponseBody.access_token
    
}

function Invoke-MGRequest  {
    [CmdletBinding()]
    param (
        # Access Token
        [string]
        $AccessToken,

        # Resource
        [Parameter(Mandatory)]
        [string]
        $Resource,

        # Select fields
        [String[]]
        $Select
    )
    
    begin {
        $headers = @{
            'Authorization' = "bearer $($AccessToken)"
            'Content-type' = "application/json"
        }
    }
    
    process {
        $uri = "$DefaultBaseUri/$($Resource)"
        if ($Select) {
            $Select = $Select -join ","
            $uri = "$($uri)?`$select=$($Select)"
        }
        $response = Invoke-RestMethod -method get -uri $uri -Headers $headers
        $response.value
    }
    
    end {
        $headers = $null
    }
}