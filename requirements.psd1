@{
    PSDependOptions = @{
        Target = 'CurrentUser'
    }

    'PSScriptAnalyzer' = 'latest'
    'PSSQLite'          = 'latest'

    'Pester' = @{
        DependencyType = 'PSGalleryModule'
        Version        = '5.5.0'
        Parameters     = @{ SkipPublisherCheck = $true }
    }

    # Dependencias opcionales 

    'Az.KeyVault' = @{
        DependencyType = 'PSGalleryModule'
        Version        = 'latest'
        Tags           = 'Optional'
    }

    'Get-WindowsAutoPilotInfo' = @{
        DependencyType = 'PSGalleryScript'
        Version        = 'latest'
        Tags           = 'Optional'
    }
}
