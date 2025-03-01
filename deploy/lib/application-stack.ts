import { Construct } from 'constructs';
import { TerraformStack, TerraformOutput } from 'cdktf';
import { AwsProvider } from '@cdktf/provider-aws/lib/provider';
import { EcsCluster } from '@cdktf/provider-aws/lib/ecs-cluster';
import { EcsService } from '@cdktf/provider-aws/lib/ecs-service';
import { EcsTaskDefinition } from '@cdktf/provider-aws/lib/ecs-task-definition';
import { IamRole } from '@cdktf/provider-aws/lib/iam-role';
import { IamRolePolicy } from '@cdktf/provider-aws/lib/iam-role-policy';
import { IamRolePolicyAttachment } from '@cdktf/provider-aws/lib/iam-role-policy-attachment';
import { Lb } from '@cdktf/provider-aws/lib/lb';
import { LbListener } from '@cdktf/provider-aws/lib/lb-listener';
import { LbTargetGroup } from '@cdktf/provider-aws/lib/lb-target-group';
import { CloudwatchLogGroup } from '@cdktf/provider-aws/lib/cloudwatch-log-group';
import { Vpc } from '@cdktf/provider-aws/lib/vpc';
import { SecurityGroup } from '@cdktf/provider-aws/lib/security-group';
import { ApplicationConfig } from '../config';

export interface ApplicationStackProps {
  environment: string;
  config: ApplicationConfig;
  vpc: Vpc;
  securityGroups: {
    application: SecurityGroup;
    loadBalancer: SecurityGroup;
  };
  database: {
    endpoint: string;
    username: string;
    password: string;
    name: string;
  };
}

export class ApplicationStack extends TerraformStack {
  public readonly applicationCluster: EcsCluster;
  public readonly loadBalancer: Lb;

  constructor(scope: Construct, id: string, props: ApplicationStackProps) {
    super(scope, id);

    // Define AWS provider
    new AwsProvider(this, 'aws', {
      region: process.env.AWS_REGION || 'us-east-1',
    });

    // Create CloudWatch log group
    const logGroup = new CloudwatchLogGroup(this, 'app-log-group', {
      name: `/ecs/${props.environment}-app`,
      retentionInDays: 30,
      tags: {
        Environment: props.environment,
      },
    });

    // Create ECS cluster
    this.applicationCluster = new EcsCluster(this, 'app-cluster', {
      name: `${props.environment}-app-cluster`,
      tags: {
        Environment: props.environment,
      },
    });

    // Create IAM roles for ECS task execution and task role
    const taskExecutionRole = new IamRole(this, 'task-execution-role', {
      name: `${props.environment}-task-execution-role`,
      assumeRolePolicy: JSON.stringify({
        Version: '2012-10-17',
        Statement: [
          {
            Action: 'sts:AssumeRole',
            Effect: 'Allow',
            Principal: {
              Service: 'ecs-tasks.amazonaws.com',
            },
          },
        ],
      }),
      tags: {
        Environment: props.environment,
      },
    });

    const taskRole = new IamRole(this, 'task-role', {
      name: `${props.environment}-task-role`,
      assumeRolePolicy: JSON.stringify({
        Version: '2012-10-17',
        Statement: [
          {
            Action: 'sts:AssumeRole',
            Effect: 'Allow',
            Principal: {
              Service: 'ecs-tasks.amazonaws.com',
            },
          },
        ],
      }),
      tags: {
        Environment: props.environment,
      },
    });

    // Attach policies to roles
    new IamRolePolicyAttachment(this, 'task-execution-role-policy-attachment', {
      role: taskExecutionRole.name,
      policyArn: 'arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy',
    });

    new IamRolePolicy(this, 'task-role-policy', {
      role: taskRole.id,
      policy: JSON.stringify({
        Version: '2012-10-17',
        Statement: [
          {
            Effect: 'Allow',
            Action: [
              'ssm:GetParameters',
              'secretsmanager:GetSecretValue',
              'kms:Decrypt',
            ],
            Resource: '*',
          },
        ],
      }),
    });

    // Create load balancer
    this.loadBalancer = new Lb(this, 'app-lb', {
      name: `${props.environment}-app-lb`,
      internal: false,
      loadBalancerType: 'application',
      securityGroups: [props.securityGroups.loadBalancer.id],
      subnets: [], // This would be populated with actual subnet IDs
      enableDeletionProtection: props.environment === 'production',
      tags: {
        Environment: props.environment,
      },
    });

    // Create target group
    const targetGroup = new LbTargetGroup(this, 'app-target-group', {
      name: `${props.environment}-app-tg`,
      port: props.config.containerPort,
      protocol: 'HTTP',
      vpcId: props.vpc.id,
      targetType: 'ip',
      healthCheck: {
        enabled: true,
        path: props.config.healthCheckPath,
        port: 'traffic-port',
        healthyThreshold: 3,
        unhealthyThreshold: 3,
        timeout: 5,
        interval: 30,
        matcher: '200-299',
      },
      tags: {
        Environment: props.environment,
      },
    });

    // Create listener
    const listener = new LbListener(this, 'app-listener', {
      loadBalancerArn: this.loadBalancer.arn,
      port: 80,
      protocol: 'HTTP',
      defaultAction: [
        {
          type: 'forward',
          targetGroupArn: targetGroup.arn,
        },
      ],
      tags: {
        Environment: props.environment,
      },
    });

    // Create task definition
    const taskDefinition = new EcsTaskDefinition(this, 'app-task-definition', {
      family: `${props.environment}-app`,
      cpu: props.config.cpu.toString(),
      memory: props.config.memory.toString(),
      networkMode: 'awsvpc',
      requiresCompatibilities: ['FARGATE'],
      executionRoleArn: taskExecutionRole.arn,
      taskRoleArn: taskRole.arn,
      containerDefinitions: JSON.stringify([
        {
          name: 'app',
          image: `${props.config.containerImage}:${props.config.containerTag}`,
          essential: true,
          portMappings: [
            {
              containerPort: props.config.containerPort,
              hostPort: props.config.containerPort,
              protocol: 'tcp',
            },
          ],
          environment: Object.entries(props.config.environment).map(([name, value]) => ({
            name,
            value,
          })),
          secrets: Object.entries(props.config.secrets).map(([name, valueFrom]) => ({
            name,
            valueFrom,
          })),
          logConfiguration: {
            logDriver: 'awslogs',
            options: {
              'awslogs-group': logGroup.name,
              'awslogs-region': process.env.AWS_REGION || 'us-east-1',
              'awslogs-stream-prefix': 'ecs',
            },
          },
        },
      ]),
      tags: {
        Environment: props.environment,
      },
    });

    // Create ECS service
    const ecsService = new EcsService(this, 'app-service', {
      name: `${props.environment}-app-service`,
      cluster: this.applicationCluster.id,
      taskDefinition: taskDefinition.arn,
      desiredCount: props.config.desiredCount,
      launchType: 'FARGATE',
      schedulingStrategy: 'REPLICA',
      deploymentMinimumHealthyPercent: 100,
      deploymentMaximumPercent: 200,
      networkConfiguration: {
        subnets: [], // This would be populated with actual subnet IDs
        securityGroups: [props.securityGroups.application.id],
        assignPublicIp: false,
      },
      loadBalancer: [
        {
          targetGroupArn: targetGroup.arn,
          containerName: 'app',
          containerPort: props.config.containerPort,
        },
      ],
      healthCheckGracePeriodSeconds: 60,
      tags: {
        Environment: props.environment,
      },
    });

    // Outputs
    new TerraformOutput(this, 'app-url', {
      value: `http://${this.loadBalancer.dnsName}`,
      description: 'The URL of the application',
    });

    new TerraformOutput(this, 'app-cluster-name', {
      value: this.applicationCluster.name,
      description: 'The name of the ECS cluster',
    });

    new TerraformOutput(this, 'app-service-name', {
      value: ecsService.name,
      description: 'The name of the ECS service',
    });
  }
} 