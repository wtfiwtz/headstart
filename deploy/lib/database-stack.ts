import { Construct } from 'constructs';
import { TerraformStack, TerraformOutput } from 'cdktf';
import { AwsProvider } from '@cdktf/provider-aws/lib/provider';
import { DbInstance } from '@cdktf/provider-aws/lib/db-instance';
import { DbSubnetGroup } from '@cdktf/provider-aws/lib/db-subnet-group';
import { DbParameterGroup } from '@cdktf/provider-aws/lib/db-parameter-group';
import { SsmParameter } from '@cdktf/provider-aws/lib/ssm-parameter';
import { RandomPassword } from '@cdktf/provider-random/lib/password';
import { Vpc } from '@cdktf/provider-aws/lib/vpc';
import { SecurityGroup } from '@cdktf/provider-aws/lib/security-group';
import { Subnet } from '@cdktf/provider-aws/lib/subnet';
import { DatabaseConfig } from '../config';

export interface DatabaseStackProps {
  environment: string;
  config: DatabaseConfig;
  vpc: Vpc;
  securityGroups: {
    database: SecurityGroup;
  };
}

export class DatabaseStack extends TerraformStack {
  public readonly databaseInstance: DbInstance;
  public readonly databaseEndpoint: string;
  public readonly databaseUsername: string;
  public readonly databasePassword: string;
  public readonly databaseName: string;

  constructor(scope: Construct, id: string, props: DatabaseStackProps) {
    super(scope, id);

    // Define AWS provider
    new AwsProvider(this, 'aws', {
      region: process.env.AWS_REGION || 'us-east-1',
    });

    // Generate a random password for the database
    const dbPassword = new RandomPassword(this, 'db-password', {
      length: 16,
      special: false,
    });

    // Store the password in SSM Parameter Store
    const dbPasswordParam = new SsmParameter(this, 'db-password-param', {
      name: `/${props.environment}/database/password`,
      type: 'SecureString',
      value: dbPassword.result,
    });

    // Create DB subnet group
    const dbSubnetGroup = new DbSubnetGroup(this, 'db-subnet-group', {
      name: `${props.environment}-db-subnet-group`,
      subnetIds: [], // This would be populated with actual subnet IDs
      description: `Subnet group for ${props.environment} database`,
      tags: {
        Environment: props.environment,
      },
    });

    // Create DB parameter group
    const dbParameterGroup = new DbParameterGroup(this, 'db-parameter-group', {
      name: `${props.environment}-db-parameter-group`,
      family: props.config.engine === 'postgres' ? 'postgres13' : 'mysql8.0',
      description: `Parameter group for ${props.environment} database`,
      parameter: [
        {
          name: props.config.engine === 'postgres' ? 'max_connections' : 'max_connections',
          value: '100',
        },
        {
          name: props.config.engine === 'postgres' ? 'shared_buffers' : 'innodb_buffer_pool_size',
          value: props.config.engine === 'postgres' ? '128MB' : '256M',
        },
      ],
      tags: {
        Environment: props.environment,
      },
    });

    // Create RDS instance
    this.databaseInstance = new DbInstance(this, 'db-instance', {
      identifier: `${props.environment}-db`,
      engine: props.config.engine,
      engineVersion: props.config.engineVersion,
      instanceClass: props.config.instanceClass,
      allocatedStorage: props.config.allocatedStorage,
      name: props.config.databaseName,
      username: props.config.username,
      password: dbPassword.result,
      dbSubnetGroupName: dbSubnetGroup.name,
      vpcSecurityGroupIds: [props.securityGroups.database.id],
      parameterGroupName: dbParameterGroup.name,
      backupRetentionPeriod: props.config.backupRetentionPeriod,
      multiAz: props.config.multiAz,
      skipFinalSnapshot: props.environment !== 'production',
      finalSnapshotIdentifier: props.environment === 'production' ? `${props.environment}-db-final-snapshot` : null,
      deletionProtection: props.environment === 'production',
      tags: {
        Name: `${props.environment}-db`,
        Environment: props.environment,
      },
    });

    // Set public properties
    this.databaseEndpoint = this.databaseInstance.endpoint;
    this.databaseUsername = props.config.username;
    this.databasePassword = dbPassword.result;
    this.databaseName = props.config.databaseName;

    // Outputs
    new TerraformOutput(this, 'db-endpoint', {
      value: this.databaseInstance.endpoint,
      description: 'The endpoint of the database',
    });

    new TerraformOutput(this, 'db-name', {
      value: props.config.databaseName,
      description: 'The name of the database',
    });

    new TerraformOutput(this, 'db-username', {
      value: props.config.username,
      description: 'The username for the database',
    });

    new TerraformOutput(this, 'db-password-param', {
      value: dbPasswordParam.name,
      description: 'The SSM parameter name for the database password',
    });
  }
} 