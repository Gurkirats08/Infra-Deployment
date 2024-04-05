function Get-BicepModuleParameters {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $TemplatePath

    )

    bicep build  $TemplatePath 
    $expectedJSONFilePath = Join-Path (Split-Path $TemplatePath -Parent) ('{0}.json' -f (Split-Path $TemplatePath -LeafBase))
    $templateContent = Get-Content $expectedJSONFilePath | ConvertFrom-Json
    $SectionContent = [System.Collections.ArrayList]@(
        'params: {'
    )
    $($templateContent.parameters).PSObject.Properties  | ForEach-Object {  
        switch ($key = $_.Name) { 
            "name" { $SectionContent += "    $key : '`${resourcePrefix.<$(( Split-Path -path $TemplatePath -Parent) | Split-Path -LeafBase)>}`${resourceInstance.name}'    //Customized locally "  ; Break }
            "location" { $SectionContent += "    $key : $key    //Customized locally" ; Break }
            "enableDefaultTelemetry" { $SectionContent += "    $key : $key    //Customized locally" ; Break }
            Default { $SectionContent += "    $key : resourceInstance.?$key" }
        }
    }
    $SectionContent += '}'
    Remove-Item -Path $expectedJSONFilePath -Force
    return $SectionContent
}