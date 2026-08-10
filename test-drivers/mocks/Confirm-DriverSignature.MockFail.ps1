[CmdletBinding()]
param()

$global:GetDriverInventoryOverride = {
    param([switch]$Online, [string]$Path)
    [PSCustomObject]@{
        OriginalFileName = 'unsigned_legacy.inf'
        ProviderName     = 'Generic'
        ClassName        = 'Unknown'
        Signed           = $false
    }
}
