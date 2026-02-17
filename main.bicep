param location string = resourceGroup().location
param storageAccountName string = 'flaskfilestore'
param containerAppName string = 'flask-csv-app'
param blobContainerName string = 'csvcontainer'
param imageRepository string = 'rkvarma4518/myflaskcsvapp'
param imageTag string

var imageName = '${imageRepository}:${imageTag}'

/* ---------- STORAGE ACCOUNT ---------- */

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

/* ---------- BLOB CONTAINER ---------- */

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${storageAccount.name}/default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/${blobContainerName}'
  properties: {
    publicAccess: 'None'
  }
}

var storageKey = storageAccount.listKeys().keys[0].value

/* ---------- LOG ANALYTICS ---------- */

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law-xyz'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

/* ---------- CONTAINER APP ENV ---------- */

resource containerEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${containerAppName}-env'
  location: location
  properties: {
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

/* ---------- ENV STORAGE (BLOB) ---------- */

resource envStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: 'csvstorage'
  parent: containerEnv
  properties: {
    azureBlob: {
      accountName: storageAccount.name
      accountKey: storageKey
      containerName: blobContainerName
      accessMode: 'ReadWrite'
    }
  }
}

/* ---------- CONTAINER APP ---------- */

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  dependsOn: [
    envStorage
  ]
  properties: {
    environmentId: containerEnv.id

    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
    }

    template: {
      containers: [
        {
          name: 'flask'
          image: imageName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          volumeMounts: [
            {
              volumeName: 'files'
              mountPath: '/mnt/files'
            }
          ]
        }
      ]

      volumes: [
        {
          name: 'files'
          storageType: 'AzureBlob'
          storageName: 'csvstorage'
        }
      ]
    }
  }
}

/* ---------- OUTPUT ---------- */

output appUrl string = containerApp.properties.configuration.ingress.fqdn
