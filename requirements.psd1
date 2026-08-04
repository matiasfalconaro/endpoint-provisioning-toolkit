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
}
