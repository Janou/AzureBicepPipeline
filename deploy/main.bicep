@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('The type of environment. This must be nonprod or prod.')
@allowed([
  'nonprod'
  'prod'
])
param environmentType string

@description('Indicates whether to deploy the storage account for jmUCare manuals.')
param deployJMUCareTestStorageAccount bool

@description('A unique suffix to add to resource names that need to be globally unique.')
@maxLength(13)
param resourceNameSuffix string = uniqueString(resourceGroup().id)

var appServiceAppName = 'jm-ucare-website-test-${resourceNameSuffix}'
var appServicePlanName = 'jm-ucare-website-test-plan'
var jmUCareTestStorageAccountName = 'jmucareweb${resourceNameSuffix}'

// Define the SKUs for each component based on the environment type.
var environmentConfigurationMap = {
  nonprod: {
    appServiceApp: {
      alwaysOn: false
    }
    appServicePlan: {
      sku: {
        name: 'F1'
        capacity: 1
      }
    }
    jmUCareManualsStorageAccount: {
      sku: {
        name: 'Standard_LRS'
      }
    }
  }
  prod: {
    appServiceApp: {
      alwaysOn: true
    }
    appServicePlan: {
      sku: {
        name: 'S1'
        capacity: 2
      }
    }
    jmUCareManualsStorageAccount: {
      sku: {
        name: 'Standard_ZRS'
      }
    }
  }
}

var jmUCareTestStorageAccountConnectionString = deployJMUCareTestStorageAccount ? 'DefaultEndpointsProtocol=https;AccountName=${jmUCareTestStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${jmUCareTestStorageAccount.listKeys().keys[0].value}' : ''

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: environmentConfigurationMap[environmentType].appServicePlan.sku
}

resource appServiceApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: environmentConfigurationMap[environmentType].appServiceApp.alwaysOn
      appSettings: [
        {
          name: 'JMUCareManualsStorageAccountConnectionString'
          value: jmUCareTestStorageAccountConnectionString
        }
      ]
    }
  }
}

resource jmUCareTestStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = if (deployJMUCareTestStorageAccount) {
  name: jmUCareTestStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: environmentConfigurationMap[environmentType].jmUCareManualsStorageAccount.sku
}
