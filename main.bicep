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
  properties: {
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/${fileShareName}'
  properties: {
    shareQuota: 12
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



/* ---------- CONTAINER APP ---------- */
// ── Container Apps Environment ────────────────────────────────
resource containerEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${containerAppName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'dedicated-d4'
        workloadProfileType: 'D4'        // 16 vCPU / 64 GB — covers your 2 vCPU + 32 GB request
        minimumCount: 1
        maximumCount: 2
      }
    ]
  }
}

// ── Azure Files Storage Extension ─────────────────────────────
resource envStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: 'files-storage'
  parent: containerEnv
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageKey
      shareName: fileShareName
      accessMode: 'ReadOnly'             // matches readOnly: true in your volume mount
    }
  }
}

// ── Container App ─────────────────────────────────────────────
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  dependsOn: [
    envStorage                           // storage must exist before app starts
  ]
  properties: {
    managedEnvironmentId: containerEnv.id
    workloadProfileName: 'dedicated-d4'
    configuration: {
      registries: [
        {
          server: 'index.docker.io'
          username: 'rkvarma4518'
          passwordSecretRef: 'registry-password'   // pulled from secrets below
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: 'Rahulkumar@4518'                 // ⚠️ move to Key Vault ref in production
        }
      ]
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: toLower('${containerAppName}-test')
          image: imageName
          resources: {
            cpu: json('2.0')
            memory: '32Gi'
          }
          ports: [
            {
              containerPort: 8080
            }
          ]
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
          storageName: envStorage.name   // references the environment-level storage
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2                   // pin to 1 if you need stateful/single-instance behaviour
      }
    }
  }
}
