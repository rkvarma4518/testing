param location string = resourceGroup().location
param storageAccountName string = 'flaskfilestore'
param containerAppName string = 'flask-csv-app'
param fileShareName string = 'csvshare'
param imageName string = 'rkvarma4518/myflaskcsvapp:latest'

/* ---------- STORAGE ---------- */

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/${fileShareName}'
  properties: { shareQuota: 5 }
}

var storageKey = storageAccount.listKeys().keys[0].value

/* ---------- CONTAINER APP ENV ---------- */

resource containerEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${containerAppName}-env'
  location: location
}

/* ---------- ENV STORAGE (FILE SHARE) ---------- */

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

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
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
          storageType: 'AzureFile'
          storageName: 'csvstorage'
        }
      ]
    }
  }
}
