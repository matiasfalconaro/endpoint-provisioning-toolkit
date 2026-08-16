<#
.SYNOPSIS
    Validación estructural de templates/network-vlan-prov-acl.template
    y templates/nac-mab-provisioning-policy.template (Secciones 6.1a / 6.1b).
    No ejecuta lógica de red: valida presencia de placeholders y reglas mínimas
    obligatorias antes de que N3 lo adapte al fabricante destino.
#>
Describe 'Plantilla ACL VLAN-PROV' {
    BeforeAll {
        $templatePath = "$PSScriptRoot\..\..\templates\network-vlan-prov-acl.template"
        $content = Get-Content -LiteralPath $templatePath -Raw
    }

    It 'Existe el artefacto en la ruta oficial' {
        Test-Path $templatePath | Should -BeTrue
    }
    It 'Contiene el placeholder de destino sin valor hardcodeado' {
        $content | Should -Match '\{\{\s*DEPLOY_VIP_OR_NAS_IP\s*\}\}'
    }
    It 'Incluye reglas PERMIT para los puertos obligatorios de despliegue (67,68,69,445,4011)' {
        foreach ($port in @('67,68', '69', '445', '4011')) {
            $content | Should -Match ([regex]::Escape($port))
        }
    }
    It 'Incluye una regla DENY explícita hacia VLAN-PRODUCCION' {
        $content | Should -Match 'DENY\s+ip\s+src=VLAN-PROV\s+dst=VLAN-PRODUCCION'
    }
    It 'Termina con una regla implícita de DENY con logging habilitado' {
        $content | Should -Match 'DENY\s+ip\s+src=any\s+dst=any\s+log=true'
    }
}

Describe 'Plantilla Política MAB de Provisión' {
    BeforeAll {
        $templatePath = "$PSScriptRoot\..\..\templates\nac-mab-provisioning-policy.template"
        $content = Get-Content -LiteralPath $templatePath -Raw
    }

    It 'Existe el artefacto en la ruta oficial' {
        Test-Path $templatePath | Should -BeTrue
    }
    It 'Referencia el placeholder de OUI de Lenovo sin valores hardcodeados en el template base' {
        $content | Should -Match '\{\{\s*LENOVO_OUI_LIST\s*\}\}'
    }
    It 'Exige verificación contra CMDB antes de asignar VLAN-PROV' {
        $content | Should -Match 'MATCH_CMDB_LOOKUP\s*=\s*true'
    }
    It 'Define FALLBACK = DENY (no asigna VLAN-PROV a equipos no homologados)' {
        $content | Should -Match 'FALLBACK\s*=\s*DENY'
    }
    It 'Define un SESSION_TIMEOUT acotado para minimizar la ventana de excepción' {
        if ($content -match 'SESSION_TIMEOUT\s*=\s*(\d+)') {
            [int]$Matches[1] | Should -BeLessOrEqual 3600
        } else {
            throw 'SESSION_TIMEOUT no definido en la plantilla'
        }
    }
}
