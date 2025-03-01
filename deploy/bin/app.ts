import { App } from 'cdktf';
import { NetworkStack } from '../lib/network-stack';
import { DatabaseStack } from '../lib/database-stack';
import { ApplicationStack } from '../lib/application-stack';
import { MonitoringStack } from '../lib/monitoring-stack';
import { getConfig } from '../config';

// Initialize the CDKTF application
const app = new App();

// Get the environment-specific configuration
const environment = process.env.ENVIRONMENT || 'development';
const config = getConfig(environment);

// Create a unique ID for this deployment
const deploymentId = `dwelling-${environment}`;

// Create the network stack (VPC, subnets, etc.)
const networkStack = new NetworkStack(app, `${deploymentId}-network`, {
  environment,
  config: config.network,
});

// Create the database stack
const databaseStack = new DatabaseStack(app, `${deploymentId}-database`, {
  environment,
  config: config.database,
  vpc: networkStack.vpc,
  securityGroups: {
    database: networkStack.databaseSecurityGroup,
  },
});

// Create the application stack
const applicationStack = new ApplicationStack(app, `${deploymentId}-application`, {
  environment,
  config: config.application,
  vpc: networkStack.vpc,
  securityGroups: {
    application: networkStack.applicationSecurityGroup,
    loadBalancer: networkStack.loadBalancerSecurityGroup,
  },
  database: {
    endpoint: databaseStack.databaseEndpoint,
    username: databaseStack.databaseUsername,
    password: databaseStack.databasePassword,
    name: databaseStack.databaseName,
  },
});

// Create the monitoring stack
const monitoringStack = new MonitoringStack(app, `${deploymentId}-monitoring`, {
  environment,
  config: config.monitoring,
  resources: {
    database: databaseStack.databaseInstance,
    application: applicationStack.applicationCluster,
    loadBalancer: applicationStack.loadBalancer,
  },
});

// Synthesize the application
app.synth(); 