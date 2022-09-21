@description('Specifies the location for all resources.')
param location string

@description('Used to name the Azure resources that are created')
param nameseed string

@description('Indicates if we should deploy the Dapr components to an existing environment')
param environmentAlreadyExists bool = false

@description('Specifies the name of the container app environment.')
param containerAppEnvName string = 'env-${nameseed}'

@maxLength(8)
@description('The application relevant name for the dapr component you are implementing')
param applicationEntityName string = nameseed

@allowed([
  'pubsub.azure.servicebus'
  'state.azure.blobstorage'
  'state.azure.cosmosdb'
])
@description('The dapr application component type to configure in the Environment')
param daprComponentType string

@description('The name of the dapr component, this will be autogenerated if not provided')
param daprComponentName string = ''

@description('Names of container apps that can use this dapr component')
param daprComponentScopes array = []

@description('Any tags that are to be applied to the Environment Components')
param tags object = {}

@description('Provides a default name lookup for the different dapr components')
var autoDaprComponentNameMap  = {
  'pubsub.azure.servicebus' : '${applicationEntityName}pubsub'
  'state.azure.blobstorage' : '${applicationEntityName}statestore'
  'state.azure.cosmosdb' : '${applicationEntityName}statestore'
}

@description('Chooses a good default name for the dapr component')
var autoDaprComponentName = empty(daprComponentName) ? autoDaprComponentNameMap[daprComponentType] : daprComponentName

module containerAppEnv 'containerAppEnv.bicep' = if(!environmentAlreadyExists) {
  name: 'containerAppEnv-${nameseed}'
  params: {
    location: location
    nameseed: nameseed
    tags: tags
  }
}

resource existingEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = if(environmentAlreadyExists) {
  name: containerAppEnvName
}

module daprComponentSb 'daprComponent-sb.bicep' = if (daprComponentType=='pubsub.azure.servicebus') {
  name: 'dapr-sb-${nameseed}'
  params: {
    componentName: autoDaprComponentName
    location: location
    containerAppEnvName: environmentAlreadyExists ? existingEnvironment.name  : containerAppEnv.outputs.containerAppEnvironmentName
    entityName: applicationEntityName
  }
}

module daprComponentStateStor 'daprComponent-stor.bicep' = if (daprComponentType=='state.azure.blobstorage') {
  name: 'dapr-state-stor-${nameseed}'
  params: {
    name: autoDaprComponentName
    location: location
    containerAppEnvName: environmentAlreadyExists ? existingEnvironment.name  : containerAppEnv.outputs.containerAppEnvironmentName
    entityName: applicationEntityName
    scopes: daprComponentScopes
  }
}

module daprComponentStateCosmos 'daprComponent-cosmosdb.bicep' = if (daprComponentType=='state.azure.cosmosdb') {
  name: 'dapr-state-cosmos-${nameseed}'
  params: {
    location: location
    containerAppEnvName: environmentAlreadyExists ? existingEnvironment.name  : containerAppEnv.outputs.containerAppEnvironmentName
    componentName: autoDaprComponentName
    entityName: applicationEntityName
    scopes: daprComponentScopes
  }
}

@description('The name of the created Azure Container Apps Environment')
output containerAppEnvironmentName string = environmentAlreadyExists ? existingEnvironment.name  : containerAppEnv.outputs.containerAppEnvironmentName

@description('The Azure Applications Insights (telemetry) instrumentation key')
output appInsightsInstrumentationKey string = environmentAlreadyExists ? ''  : containerAppEnv.outputs.appInsightsInstrumentationKey
