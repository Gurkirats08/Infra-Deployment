// Parameters - Common
@description('Required. Location for all resources. Default: Current deployment location')
@allowed([
  'eastus'
  'eastus2'
  'centralus'
  'westcentralus'
  'westus'
  'westus2'
  'westus3'
])
param location string = 'eastus'

param environment string
param contextPrefix string
param resourcePrefix object = {}
param envServicePrincipalID string = ''
param tags object
param ASESubnet string
param PESubnet string 
// Parameters - Resource Specific
param storageAccounts object
param keyVaults object
param asename string
param appServicePlans object
param applicationInsights object
param logAnalyticsWorkspaces object
param functionApps array = []
param functionApps2 array = []
param ManagedIdentity object ={}
param vnetname string = ''

//////////////////////////
// Variables : Common   // 
//////////////////////////

var enableDefaultTelemetry = false
var contextTags = union(tags, { Environment: toUpper(environment) })

///////////////////////////////////////
// Deployments - Storage Account     // 
///////////////////////////////////////

module StorageAccounts '../Modules/storage/storage-accounts/main.bicep' = {
  name: 'storagedeploy'
  params: {
    // Required
    name: storageAccounts.stg1.name
    location: location
    // Optional
    enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
    allowBlobPublicAccess: storageAccounts.stg1.?allowBlobPublicAccess
    diagnosticStorageAccountId: storageAccounts.stg1.?diagnosticStorageAccountId
    diagnosticWorkspaceId: storageAccounts.stg1.?diagnosticWorkspaceId
    enableHierarchicalNamespace: storageAccounts.stg1.?enableHierarchicalNamespace
    enableNfsV3: storageAccounts.stg1.?enableNfsV3
    enableSftp: false
    privateEndpoints: storageAccounts.stg1.?privateEndpoints
    queueServices: storageAccounts.stg1.?queueServices
    requireInfrastructureEncryption: storageAccounts.stg1.?requireInfrastructureEncryption
    roleAssignments: storageAccounts.stg1.?roleAssignments
    sasExpirationPeriod: storageAccounts.stg1.?sasExpirationPeriod
    skuName: storageAccounts.stg1.?skuName
    systemAssignedIdentity: storageAccounts.stg1.?systemAssignedIdentity
    tableServices: storageAccounts.stg1.?tableServices
    tags: union(storageAccounts.stg1.?tags, contextTags)
  }
  dependsOn: [
    VirtualNetworkSubnets
    LogAnalyticsWorkspaces
  ]
}

// ///////////////////////////////////////
// Deployments - Key Vault           // 
///////////////////////////////////////

module KeyVaults '../Modules/key-vault/vaults/main.bicep' = {
  name: 'keyvaultdeploy'
  params: {
    // Required
    name: keyVaults.kv1.name //Customized locally
    location: location
    // Optional
    enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
    accessPolicies: keyVaults.kv1.?accessPolicies
    diagnosticEventHubAuthorizationRuleId: keyVaults.kv1.?diagnosticEventHubAuthorizationRuleId
    diagnosticEventHubName: keyVaults.kv1.?diagnosticEventHubName
    diagnosticLogsRetentionInDays: keyVaults.kv1.?diagnosticLogsRetentionInDays
    diagnosticStorageAccountId: keyVaults.kv1.?diagnosticStorageAccountId
    diagnosticWorkspaceId: keyVaults.kv1.?diagnosticWorkspaceId
    enablePurgeProtection: keyVaults.kv1.?enablePurgeProtection
    enableRbacAuthorization: keyVaults.kv1.?enableRbacAuthorization
    keys: keyVaults.kv1.?keys
    lock: keyVaults.kv1.?lock
    networkAcls: keyVaults.kv1.?networkAcls
    privateEndpoints: keyVaults.kv1.?privateEndpoints
    publicNetworkAccess : keyVaults.kv1.?publicNetworkAccess
//    roleAssignments: union(keyVaults.kv1.roleAssignments, envServicePrincipalKVRole)
    secrets: keyVaults.kv1.?secrets
    softDeleteRetentionInDays: keyVaults.kv1.?softDeleteRetentionInDays
    tags: union(keyVaults.kv1.?tags, contextTags)
  }
  dependsOn: [
    VirtualNetworkSubnets
    LogAnalyticsWorkspaces
  ]
}

///////////////////////////////////////////
// Deployments - App Service Environment // 
///////////////////////////////////////

module AppServiceEnvironment '../Modules/web/hosting-environments/main.bicep' = {
  name: 'ASEDeploy'
  params: {
    name: asename
    subnetName: ASESubnet
    virtualNetworkName: vnetname
    vnetResourceGroupName: LogAnalyticsWorkspaces.outputs.resourceGroupName
    location: location
    kind: 'ASEv3'
  }
}

///////////////////////////////////////
// Deployments - App Service Plan    // 
///////////////////////////////////////
module AppServicePlans '../Modules/web/serverfarms/main.bicep' = {
  name: 'module-AppServicePlan-${contextPrefix}'
  params: {
    // Required
    name: appServicePlans.asp1.name //Customized locally 
    // Optional
    sku: appServicePlans.asp1.?sku
    location: appServicePlans.asp1.?location
    serverOS: appServicePlans.asp1.?serverOS
    appServiceEnvironmentId: AppServiceEnvironment.outputs.resourceId
    workerTierName: appServicePlans.asp1.?workerTierName
    perSiteScaling: appServicePlans.asp1.?perSiteScaling
    maximumElasticWorkerCount: appServicePlans.asp1.?maximumElasticWorkerCount
    targetWorkerCount: appServicePlans.asp1.?targetWorkerCount
    targetWorkerSize: appServicePlans.asp1.?targetWorkerSize
    lock: appServicePlans.asp1.?lock
    roleAssignments: appServicePlans.asp1.?roleAssignments
    tags: union(appServicePlans.asp1.?tags, contextTags)
    enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
    zoneRedundant: appServicePlans.asp1.?zoneRedundant
    diagnosticWorkspaceId: LogAnalyticsWorkspaces.outputs.resourceId
  }
  dependsOn: [    
    LogAnalyticsWorkspaces  
    AppServiceEnvironment
  ]
}

////////////////////////////////////////
// Deployments - Function App // 
////////////////////////////////////////

var functionApps_custom = [for (resourceInstance, i) in functionApps: {
  name: '${resourcePrefix.functionapp}${resourceInstance.name}'
  shortname: resourceInstance.name
  index: '${i}'
  serverFarmResourceId: contains(resourceInstance.serverFarmResourceId, 'Microsoft.Web/serverfarms') ? resourceInstance.serverFarmResourceId : resourceId('Microsoft.Web/serverfarms', '${resourcePrefix.appServicePlan}${resourceInstance.serverFarmResourceId}')
  siteConfig: {
    alwaysOn: 'true'
    ftpsState: 'FtpsOnly'
    vnetRouteAllEnabled: true
  }
  storageAccountResourceId: contains(resourceInstance.storageAccountResourceId, 'Microsoft.Storage/storageAccounts') ? resourceInstance.storageAccountResourceId : resourceId('Microsoft.Storage/storageAccounts', '${replace(toLower('${resourcePrefix.storageAccount}${resourceInstance.storageAccountResourceId}'), '-', '')}')
}]
var functionApps_custom_index = toObject(functionApps_custom, resourceInstance => resourceInstance.shortname)

module FunctionApps '../Modules/web/sites/main.bicep' = [for (resourceInstance, i) in functionApps: {
  name: 'module-FunctionApp-${contextPrefix}-${resourceInstance.name}'
  params: {
    // Required
    name: functionApps_custom[i].name //Customized locally 
    location: location //Customized locally
    kind: resourceInstance.?kind
    serverFarmResourceId: functionApps_custom[i].serverFarmResourceId
    // Optional
    httpsOnly: resourceInstance.?httpsOnly
    clientAffinityEnabled: resourceInstance.?clientAffinityEnabled
    appServiceEnvironmentResourceId: resourceInstance.?appServiceEnvironmentResourceId
    systemAssignedIdentity: resourceInstance.?systemAssignedIdentity
//    userAssignedIdentities: {
//      '${managedidentityID}': {}
//    }
    keyVaultAccessIdentityResourceId: resourceInstance.?keyVaultAccessIdentityResourceId
    storageAccountRequired: resourceInstance.?storageAccountRequired
    siteConfig: union(resourceInstance.?siteConfig, functionApps_custom[i].siteConfig)
    storageAccountResourceId: functionApps_custom[i].storageAccountResourceId
    appInsightResourceId: ApplicationInsights.outputs.resourceId
    setAzureWebJobsDashboard: resourceInstance.?setAzureWebJobsDashboard
    appSettingsKeyValuePairs: union(resourceInstance.?appSettingsKeyValuePairs, {
        vnetRouteAllEnabled: true
        WEBSITE_ENABLE_SYNC_UPDATE_SITE: true
        XDT_MicrosoftApplicationInsights_Mode: 'default'
        ASPNETCORE_ENVIRONMENT: toUpper(environment)
        ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
         'SmtpSettings:FromAddress' : 'SWP@em.myflorida.com'
        FUNCTIONS_EXTENSION_VERSION: '~4'
      })
    authSettingV2Configuration: resourceInstance.?authSettingV2Configuration
    lock: resourceInstance.?lock
    slots: [
      {
        name: 'staging'
        kind: resourceInstance.?kind
        serverFarmResourceId: functionApps_custom[i].serverFarmResourceId
        // Optional
        httpsOnly: resourceInstance.?httpsOnly
        clientAffinityEnabled: resourceInstance.?clientAffinityEnabled
        appServiceEnvironmentResourceId: resourceInstance.?appServiceEnvironmentResourceId
        systemAssignedIdentity: resourceInstance.?systemAssignedIdentity
//        userAssignedIdentities: {
//          '${managedidentityID}': {}
//        }
        keyVaultAccessIdentityResourceId: resourceInstance.?keyVaultAccessIdentityResourceId
        storageAccountRequired: resourceInstance.?storageAccountRequired
        VirtualNetworkSubnetId: functionApps_custom[i].?VirtualNetworkSubnetId
        siteConfig: union(resourceInstance.?siteConfig, functionApps_custom[i].siteConfig)
        storageAccountResourceId: functionApps_custom[i].storageAccountResourceId
        appInsightResourceId: ApplicationInsights.outputs.resourceId
        setAzureWebJobsDashboard: resourceInstance.?setAzureWebJobsDashboard
        appSettingsKeyValuePairs: union(resourceInstance.?appSettingsKeyValuePairs, {
            vnetRouteAllEnabled: true
            WEBSITE_ENABLE_SYNC_UPDATE_SITE: true
            XDT_MicrosoftApplicationInsights_Mode: 'default'
            ASPNETCORE_ENVIRONMENT: toUpper(environment)
            ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
            'SmtpSettings:FromAddress' : 'SWP@em.myflorida.com'
            FUNCTIONS_EXTENSION_VERSION: '~4'
          })
        authSettingV2Configuration: resourceInstance.?authSettingV2Configuration
        lock: resourceInstance.?lock
        slots: resourceInstance.?slots
        tags: union(resourceInstance.?tags, contextTags)
        enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
        roleAssignments: resourceInstance.?roleAssignments
        cloningInfo: resourceInstance.?cloningInfo
        containerSize: resourceInstance.?containerSize
        customDomainVerificationId: resourceInstance.?customDomainVerificationId
        dailyMemoryTimeQuota: resourceInstance.?dailyMemoryTimeQuota
        enabled: resourceInstance.?enabled
        hostNameSslStates: resourceInstance.?hostNameSslStates
        hyperV: resourceInstance.?hyperV
        redundancyMode: resourceInstance.?redundancyMode
        basicPublishingCredentialsPolicies: resourceInstance.?basicPublishingCredentialsPolicies
        vnetRouteAllEnabled: true
      }
    ]
    tags: union(resourceInstance.?tags, contextTags)
    enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
    roleAssignments: resourceInstance.?roleAssignments
    cloningInfo: resourceInstance.?cloningInfo
    containerSize: resourceInstance.?containerSize
    customDomainVerificationId: resourceInstance.?customDomainVerificationId
    dailyMemoryTimeQuota: resourceInstance.?dailyMemoryTimeQuota
    enabled: resourceInstance.?enabled
    hostNameSslStates: resourceInstance.?hostNameSslStates
    hyperV: resourceInstance.?hyperV
    redundancyMode: resourceInstance.?redundancyMode
    basicPublishingCredentialsPolicies: resourceInstance.?basicPublishingCredentialsPolicies
  }
  dependsOn: [
    AppServicePlans
    StorageAccounts
    VirtualNetworkSubnets
  ]
}]
///////////////////////////////////////
// Deployments - Function App2 // 
////////////////////////////////////////

var functionApps2_custom = [for (resourceInstance, i) in functionApps2: {
  name: '${resourcePrefix.functionapp}${resourceInstance.name}'
  shortname: resourceInstance.name
  index: '${i}'
  serverFarmResourceId: contains(resourceInstance.serverFarmResourceId, 'Microsoft.Web/serverfarms') ? resourceInstance.serverFarmResourceId : resourceId('Microsoft.Web/serverfarms', '${resourcePrefix.appServicePlan}${resourceInstance.serverFarmResourceId}')
  privateEndpoints: [
    {
      service: 'sites'
      subnetResourceId: resourceId('Microsoft.Network/VirtualNetworks/subnets/', VirtualNetwork.name, 'default')
      tags: tags
    }
  ]
  siteConfig: {
    alwaysOn: 'true'
    ftpsState: 'FtpsOnly'
    vnetRouteAllEnabled: true
  }
  VirtualNetworkSubnetId: resourceId('Microsoft.Network/VirtualNetworks/subnets/', VirtualNetwork.name, 'VirtualNetworkIntegration-subnet')
  storageAccountResourceId: contains(resourceInstance.storageAccountResourceId, 'Microsoft.Storage/storageAccounts') ? resourceInstance.storageAccountResourceId : resourceId('Microsoft.Storage/storageAccounts', '${replace(toLower('${resourcePrefix.storageAccount}${resourceInstance.storageAccountResourceId}'), '-', '')}')
}]
var functionApps2_custom_index = toObject(functionApps2_custom, resourceInstance => resourceInstance.shortname)

module FunctionApps2 '../Modules/web/sites/main.bicep' = [for (resourceInstance, i) in functionApps2: {
  name: 'module-FunctionApp2-${contextPrefix}-${resourceInstance.name}'
  params: {
    // Required
    name: functionApps2_custom[i].name //Customized locally 
    location: location //Customized locally
    kind: resourceInstance.?kind
    serverFarmResourceId: functionApps2_custom[i].serverFarmResourceId
    // Optional
    httpsOnly: resourceInstance.?httpsOnly
    clientAffinityEnabled: resourceInstance.?clientAffinityEnabled
    appServiceEnvironmentResourceId: resourceInstance.?appServiceEnvironmentResourceId
    systemAssignedIdentity: resourceInstance.?systemAssignedIdentity
//    userAssignedIdentities: {
//      '${managedidentityID}': {}
//    }
    keyVaultAccessIdentityResourceId: resourceInstance.?keyVaultAccessIdentityResourceId
    storageAccountRequired: resourceInstance.?storageAccountRequired
    siteConfig: union(resourceInstance.?siteConfig, functionApps2_custom[i].siteConfig)
    storageAccountResourceId: functionApps2_custom[i].storageAccountResourceId
    appInsightResourceId: ApplicationInsights.outputs.resourceId
    setAzureWebJobsDashboard: resourceInstance.?setAzureWebJobsDashboard
    appSettingsKeyValuePairs: union(resourceInstance.?appSettingsKeyValuePairs, {
        vnetRouteAllEnabled: true
        WEBSITE_ENABLE_SYNC_UPDATE_SITE: true
        XDT_MicrosoftApplicationInsights_Mode: 'default'
        ASPNETCORE_ENVIRONMENT: toUpper(environment)
        ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
         DbProvider: 'SqlServer'
         FUNCTIONS_EXTENSION_VERSION: '~4'
      })
    authSettingV2Configuration: resourceInstance.?authSettingV2Configuration
    lock: resourceInstance.?lock
    privateEndpoints: functionApps2_custom[i].privateEndpoints
    slots: [
      {
        name: 'staging'
        kind: resourceInstance.?kind
        serverFarmResourceId: functionApps2_custom[i].serverFarmResourceId
        // Optional
        httpsOnly: resourceInstance.?httpsOnly
        clientAffinityEnabled: resourceInstance.?clientAffinityEnabled
        appServiceEnvironmentResourceId: resourceInstance.?appServiceEnvironmentResourceId
        systemAssignedIdentity: resourceInstance.?systemAssignedIdentity
//        userAssignedIdentities: {
//          '${managedidentityID}': {}
//        }
        keyVaultAccessIdentityResourceId: resourceInstance.?keyVaultAccessIdentityResourceId
        storageAccountRequired: resourceInstance.?storageAccountRequired
        VirtualNetworkSubnetId: functionApps2_custom[i].?VirtualNetworkSubnetId
        siteConfig: union(resourceInstance.?siteConfig, functionApps2_custom[i].siteConfig)
        storageAccountResourceId: functionApps2_custom[i].storageAccountResourceId
        appInsightResourceId: ApplicationInsights.outputs.resourceId
        setAzureWebJobsDashboard: resourceInstance.?setAzureWebJobsDashboard
        appSettingsKeyValuePairs: union(resourceInstance.?appSettingsKeyValuePairs, {
            vnetRouteAllEnabled: true
            WEBSITE_ENABLE_SYNC_UPDATE_SITE: true
            XDT_MicrosoftApplicationInsights_Mode: 'default'
            ASPNETCORE_ENVIRONMENT: toUpper(environment)
            ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
            FUNCTIONS_EXTENSION_VERSION: '~4'
          })
        authSettingV2Configuration: resourceInstance.?authSettingV2Configuration
        lock: resourceInstance.?lock
        privateEndpoints: functionApps2_custom[i].privateEndpoints
        slots: resourceInstance.?slots
        tags: union(resourceInstance.?tags, contextTags)
        enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
        roleAssignments: resourceInstance.?roleAssignments
        cloningInfo: resourceInstance.?cloningInfo
        containerSize: resourceInstance.?containerSize
        customDomainVerificationId: resourceInstance.?customDomainVerificationId
        dailyMemoryTimeQuota: resourceInstance.?dailyMemoryTimeQuota
        enabled: resourceInstance.?enabled
        hostNameSslStates: resourceInstance.?hostNameSslStates
        hyperV: resourceInstance.?hyperV
        redundancyMode: resourceInstance.?redundancyMode
        basicPublishingCredentialsPolicies: resourceInstance.?basicPublishingCredentialsPolicies
        vnetRouteAllEnabled: true
      }
    ]
    tags: union(resourceInstance.?tags, contextTags)
    enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
    roleAssignments: resourceInstance.?roleAssignments
    cloningInfo: resourceInstance.?cloningInfo
    containerSize: resourceInstance.?containerSize
    customDomainVerificationId: resourceInstance.?customDomainVerificationId
    dailyMemoryTimeQuota: resourceInstance.?dailyMemoryTimeQuota
    enabled: resourceInstance.?enabled
    hostNameSslStates: resourceInstance.?hostNameSslStates
    hyperV: resourceInstance.?hyperV
    redundancyMode: resourceInstance.?redundancyMode
    basicPublishingCredentialsPolicies: resourceInstance.?basicPublishingCredentialsPolicies
  }
  dependsOn: [
    AppServicePlans
    StorageAccounts
    VirtualNetworkSubnets
  ]
}]

/////////////////////////////////////////
// Deployments - Application Insights  // 
/////////////////////////////////////////

module ApplicationInsights '../Modules/insights/components/main.bicep' = {
  name: 'module-ApplicationInsights-${contextPrefix}'
  params: {
    name: applicationInsights.insight1.name //Customized locally 
    applicationType: applicationInsights.insight1.?applicationType
    workspaceResourceId: LogAnalyticsWorkspaces.outputs.resourceId
    publicNetworkAccessForIngestion: applicationInsights.insight1.?publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: applicationInsights.insight1.?publicNetworkAccessForQuery
    retentionInDays: applicationInsights.insight1.?retentionInDays
    samplingPercentage: applicationInsights.insight1.?samplingPercentage
    kind: applicationInsights.insight1.?kind
    location: location //Customized locally
    roleAssignments: applicationInsights.insight1.?roleAssignments
    tags: union(applicationInsights.insight1.?tags, contextTags)
    enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
  }
   dependsOn: [
    LogAnalyticsWorkspaces
  ]
}

///////////////////////////////////////////
// Deployments - Log Analytics Workspace // 
///////////////////////////////////////////

module LogAnalyticsWorkspaces '../Modules/operational-insights/workspaces/main.bicep' = {
  name: 'module-LogAnalyticsWorkspace-${contextPrefix}'
  params: {
    name: logAnalyticsWorkspaces.log1.name //Customized locally
    location: location //Customized locally
    enableDefaultTelemetry: enableDefaultTelemetry //Customized locally
    storageInsightsConfigs: logAnalyticsWorkspaces.log1.?storageInsightsConfigs
    linkedServices: logAnalyticsWorkspaces.log1.?linkedServices
    linkedStorageAccounts: logAnalyticsWorkspaces.log1.?linkedStorageAccounts
    savedSearches: logAnalyticsWorkspaces.log1.?savedSearches
    dataExports: logAnalyticsWorkspaces.log1.?dataExports
    dataSources: logAnalyticsWorkspaces.log1.?dataSources
    tables: logAnalyticsWorkspaces.log1.?tables
    gallerySolutions: logAnalyticsWorkspaces.log1.?gallerySolutions
    tags: union(logAnalyticsWorkspaces.log1.?tags, contextTags)
  }
  dependsOn: [
    VirtualNetworkSubnets
  ]
}

////////////////////////////
// Private EndpointSubnet // 
///////////////////////////

resource VirtualNetworkSubnets 'Microsoft.Network/VirtualNetworks/subnets@2023-09-01' existing = {
  name: PESubnet
}

/////////////////////////////////
// AppServiceEnvironmentSubnet // 
////////////////////////////////

resource VirtualNetworkSubnets1 'Microsoft.Network/VirtualNetworks/subnets@2023-09-01' existing = {
  name: ASESubnet
}

resource VirtualNetwork 'Microsoft.Network/VirtualNetworks@2023-09-01' existing = {
  name: vnetname
}
/*
resource managedidentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${ManagedIdentity.name}'
  scope: resourceGroup('${ManagedIdentity.scope}')
}
var managedidentityID = managedidentity.id
/////////////////////
// Permissions     // 
////////////////////
/
//Keyvault
module Keyvault_001_RBAC '../Modules/key-vault/vaults/.bicep/nested_roleAssignments.bicep' = {
  name: '${uniqueString(deployment().name, location)}-KeyVault-001-RBAC'
  params: {
    resourceId: KeyVaults[int(keyVaults_custom_index['001'].index)].outputs.resourceId
    roleDefinitionIdOrName: 'Key Vault Secrets User'
    principalIds: [
      WebApps[int(webApps_custom_index['001'].index)].outputs.systemAssignedPrincipalId
      FunctionApps[int(functionApps_custom_index['001'].index)].outputs.systemAssignedPrincipalId
      FunctionApps2[int(functionApps2_custom_index['101'].index)].outputs.systemAssignedPrincipalId

    ]
    principalType: 'ServicePrincipal'
  }
}
*/
