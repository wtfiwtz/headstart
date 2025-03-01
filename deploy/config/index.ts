import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';
import * as yaml from 'js-yaml';

// Load environment variables from .env file
dotenv.config();

// Configuration interfaces
export interface Config {
  provider: 'aws' | 'azure' | 'gcp';
  framework: 'cdk' | 'cdktf';
  environment: string;
  region: string;
  application: ApplicationConfig;
  network: NetworkConfig;
  database: DatabaseConfig;
  monitoring: MonitoringConfig;
}

export interface NetworkConfig {
  vpcName: string;
  cidr: string;
  azCount: number;
  publicSubnets: string[];
  privateSubnets: string[];
  databaseSubnets: string[];
  enableNatGateway: boolean;
  singleNatGateway: boolean;
}

export interface DatabaseConfig {
  engine: string;
  engineVersion: string;
  instanceClass: string;
  allocatedStorage: number;
  multiAz: boolean;
  backupRetentionPeriod: number;
  databaseName: string;
  username: string;
  port: number;
}

export interface ApplicationConfig {
  name: string;
  containerImage: string;
  containerTag: string;
  containerPort: number;
  healthCheckPath: string;
  cpu: number;
  memory: number;
  desiredCount: number;
  autoscaling: {
    enabled: boolean;
    minCapacity: number;
    maxCapacity: number;
    cpuTargetUtilization: number;
    memoryTargetUtilization: number;
  };
  environment: Record<string, string>;
  secrets: Record<string, string>;
}

export interface MonitoringConfig {
  alarmEmail: string;
  enableDashboard: boolean;
  enableAlarms: boolean;
  logRetentionDays: number;
}

// Load configuration from YAML file
export function loadConfig(configFile: string): Config {
  try {
    const configPath = path.resolve(__dirname, configFile);
    if (!fs.existsSync(configPath)) {
      throw new Error(`Configuration file not found: ${configPath}`);
    }

    const fileContent = fs.readFileSync(configPath, 'utf8');
    const config = yaml.load(fileContent) as Config;

    // Validate required fields
    if (!config.provider) {
      throw new Error('Provider is required in configuration');
    }
    if (!config.framework) {
      throw new Error('Framework is required in configuration');
    }
    if (!config.environment) {
      throw new Error('Environment is required in configuration');
    }

    // Apply environment variables
    config.region = process.env.REGION || config.region;
    
    // Apply environment-specific overrides if they exist
    const envOverrides = loadEnvironmentOverrides(config.provider, config.framework, config.environment);
    return deepMerge(config, envOverrides);
  } catch (error) {
    console.error(`Error loading configuration: ${error.message}`);
    throw error;
  }
}

// Load environment-specific overrides
function loadEnvironmentOverrides(provider: string, framework: string, environment: string): Partial<Config> {
  try {
    const overridePath = path.resolve(__dirname, `${provider}-${framework}-${environment}.yaml`);
    if (fs.existsSync(overridePath)) {
      const fileContent = fs.readFileSync(overridePath, 'utf8');
      return yaml.load(fileContent) as Partial<Config>;
    }
  } catch (error) {
    console.warn(`Error loading environment overrides: ${error.message}`);
  }
  return {};
}

// Get configuration for the specified provider, framework, and environment
export function getConfig(provider: string, framework: string, environment: string): Config {
  const configFile = `${provider}-${framework}.yaml`;
  return loadConfig(configFile);
}

// Helper function for deep merging objects
function deepMerge<T>(target: T, source: Partial<T>): T {
  const output = { ...target };
  
  if (isObject(target) && isObject(source)) {
    Object.keys(source).forEach(key => {
      if (isObject(source[key as keyof Partial<T>])) {
        if (!(key in target)) {
          Object.assign(output, { [key]: source[key as keyof Partial<T>] });
        } else {
          output[key as keyof T] = deepMerge(
            target[key as keyof T],
            source[key as keyof Partial<T>] as any
          );
        }
      } else {
        Object.assign(output, { [key]: source[key as keyof Partial<T>] });
      }
    });
  }
  
  return output;
}

// Helper function to check if value is an object
function isObject(item: any): item is Record<string, any> {
  return (item && typeof item === 'object' && !Array.isArray(item));
} 