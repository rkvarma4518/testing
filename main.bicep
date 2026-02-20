param location string = resourceGroup().location
param storageAccountName string = 'flaskfilestore'
param containerAppName string = 'flask-csv-app'
param fileShareName string = 'csvshare'
param imageRepository string = 'rkvarma4518/myflaskcsvapp'
param imageTag string

var imageName = '${imageRepository}:${imageTag}'


/* ---------- STORAGE ---------- */

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/${fileShareName}'
  properties: {
    shareQuota: 5
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


/* ---------- ENV STORAGE ---------- */

resource envStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: 'csvstorage'
  parent: containerEnv
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageKey
      shareName: fileShareName
      accessMode: 'ReadWrite'
    }
  }
}

/* ---------- CONTAINER APP ---------- */

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerAppName
  location: location

  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    diagnostics: {
      logAnalytics: {
        workspaceId: logAnalytics.properties.customerId
        workspaceKey: logAnalytics.listKeys().primarySharedKey
        logType: 'ContainerInsights'
      }
    }
    containers: [
      {
        name: 'flask'
        properties: {
          image: imageName

          ports: [
            {
              port: 8080
            }
          ]

          resources: {
            requests: {
              cpu: 0.5
              memoryInGB: 1
            }
          }

          volumeMounts: [
            {
              name: 'files'
              mountPath: '/mnt/files'
              readOnly: false
            }
          ]
        }
      }
    ]

    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 8080
        }
      ]
    }

    volumes: [
      {
        name: 'files'
        azureFile: {
          shareName: 'csvstorage'          // file share name
          storageAccountName: 'mystorageaccount'
          storageAccountKey: storageKey
        }
      }
    ]
  }
}

/* ---------- OUTPUT ---------- */

output appUrl string = containerApp.properties.configuration.ingress.fqdn
