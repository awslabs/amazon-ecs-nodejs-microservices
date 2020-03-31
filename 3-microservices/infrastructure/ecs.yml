AWSTemplateFormatVersion: '2010-09-09'
Parameters:
  DesiredCapacity:
    Type: Number
    Default: '2'
    Description: Number of instances to launch in your ECS cluster.
  MaxSize:
    Type: Number
    Default: '2'
    Description: Maximum number of instances that can be launched in your ECS cluster.
  InstanceType:
    Description: EC2 instance type
    Type: String
    Default: t2.micro
    AllowedValues: [t2.micro, t2.small, t2.medium, t2.large, t2.xlarge, t3.micro, t3.small,
      t3.medium, t3.large, t3.xlarge, m4.large, m4.xlarge, m5.large, m5.xlarge, c4.large,
      c4.xlarge, c5.large, c5.xlarge, r4.large, r4.xlarge, r5.large, r5.xlarge, i3.large,
      i3.xlarge]
    ConstraintDescription: Please choose a valid instance type.
  ECSAMI:
    Description: AMI ID
    Type: AWS::SSM::Parameter::Value<String>
    Default: /aws/service/ecs/optimized-ami/amazon-linux/recommended/image_id
Mappings:
  SubnetConfig:
    VPC:
      CIDR: '10.0.0.0/16'
    PublicOne:
      CIDR: '10.0.0.0/24'
    PublicTwo:
      CIDR: '10.0.1.0/24'
Resources:
  # VPC into which stack instances will be placed
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      EnableDnsSupport: true
      EnableDnsHostnames: true
      CidrBlock: !FindInMap ['SubnetConfig', 'VPC', 'CIDR']
  PublicSubnetOne:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
         Fn::Select:
         - 0
         - Fn::GetAZs: {Ref: 'AWS::Region'}
      VpcId: !Ref 'VPC'
      CidrBlock: !FindInMap ['SubnetConfig', 'PublicOne', 'CIDR']
      MapPublicIpOnLaunch: true
  PublicSubnetTwo:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
         Fn::Select:
         - 1
         - Fn::GetAZs: {Ref: 'AWS::Region'}
      VpcId: !Ref 'VPC'
      CidrBlock: !FindInMap ['SubnetConfig', 'PublicTwo', 'CIDR']
      MapPublicIpOnLaunch: true
  InternetGateway:
    Type: AWS::EC2::InternetGateway
  GatewayAttachement:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref 'VPC'
      InternetGatewayId: !Ref 'InternetGateway'
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref 'VPC'
  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: GatewayAttachement
    Properties:
      RouteTableId: !Ref 'PublicRouteTable'
      DestinationCidrBlock: '0.0.0.0/0'
      GatewayId: !Ref 'InternetGateway'
  PublicSubnetOneRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnetOne
      RouteTableId: !Ref PublicRouteTable
  PublicSubnetTwoRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnetTwo
      RouteTableId: !Ref PublicRouteTable

  # ECS Resources
  ECSCluster:
    Type: AWS::ECS::Cluster
  EcsSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: ECS Security Group
      VpcId: !Ref 'VPC'
  EcsSecurityGroupHTTPinbound:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'EcsSecurityGroup'
      IpProtocol: tcp
      FromPort: '80'
      ToPort: '80'
      CidrIp: 0.0.0.0/0
  EcsSecurityGroupSSHinbound:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'EcsSecurityGroup'
      IpProtocol: tcp
      FromPort: '22'
      ToPort: '22'
      CidrIp: 0.0.0.0/0
  EcsSecurityGroupALBports:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'EcsSecurityGroup'
      IpProtocol: tcp
      FromPort: '31000'
      ToPort: '61000'
      SourceSecurityGroupId: !Ref 'EcsSecurityGroup'
  CloudwatchLogsGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Join ['-', [ECSLogGroup, !Ref 'AWS::StackName']]
      RetentionInDays: 14
  ECSALB:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Scheme: internet-facing
      LoadBalancerAttributes:
      - Key: idle_timeout.timeout_seconds
        Value: '30'
      Subnets:
        - !Ref PublicSubnetOne
        - !Ref PublicSubnetTwo
      SecurityGroups: [!Ref 'EcsSecurityGroup']
  ECSAutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      VPCZoneIdentifier:
        - !Ref PublicSubnetOne
        - !Ref PublicSubnetTwo
      LaunchConfigurationName: !Ref 'ContainerInstances'
      MinSize: '1'
      MaxSize: !Ref 'MaxSize'
      DesiredCapacity: !Ref 'DesiredCapacity'
    CreationPolicy:
      ResourceSignal:
        Timeout: PT15M
    UpdatePolicy:
      AutoScalingReplacingUpdate:
        WillReplace: 'true'
  ContainerInstances:
    Type: AWS::AutoScaling::LaunchConfiguration
    Properties:
      ImageId: !Ref ECSAMI
      SecurityGroups: [!Ref 'EcsSecurityGroup']
      InstanceType: !Ref 'InstanceType'
      IamInstanceProfile: !Ref 'EC2InstanceProfile'
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash -xe
          echo ECS_CLUSTER=${ECSCluster} >> /etc/ecs/ecs.config
          yum install -y aws-cfn-bootstrap
          /opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource ECSAutoScalingGroup --region ${AWS::Region}
  ECSServiceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
        - Effect: Allow
          Principal:
            Service: [ecs.amazonaws.com]
          Action: ['sts:AssumeRole']
      Path: /
      Policies:
      - PolicyName: ecs-service
        PolicyDocument:
          Statement:
          - Effect: Allow
            Action:
              - 'elasticloadbalancing:DeregisterInstancesFromLoadBalancer'
              - 'elasticloadbalancing:DeregisterTargets'
              - 'elasticloadbalancing:Describe*'
              - 'elasticloadbalancing:RegisterInstancesWithLoadBalancer'
              - 'elasticloadbalancing:RegisterTargets'
              - 'ec2:Describe*'
              - 'ec2:AuthorizeSecurityGroupIngress'
            Resource: '*'
  EC2Role:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
        - Effect: Allow
          Principal:
            Service: [ec2.amazonaws.com]
          Action: ['sts:AssumeRole']
      Path: /
      Policies:
      - PolicyName: ecs-service
        PolicyDocument:
          Statement:
          - Effect: Allow
            Action:
              - 'ecs:CreateCluster'
              - 'ecs:DeregisterContainerInstance'
              - 'ecs:DiscoverPollEndpoint'
              - 'ecs:Poll'
              - 'ecs:RegisterContainerInstance'
              - 'ecs:StartTelemetrySession'
              - 'ecs:Submit*'
              - 'logs:CreateLogStream'
              - 'logs:PutLogEvents'
              - 'ecr:GetAuthorizationToken'
              - 'ecr:BatchGetImage'
              - 'ecr:GetDownloadUrlForLayer'
            Resource: '*'
  AutoscalingRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
        - Effect: Allow
          Principal:
            Service: [application-autoscaling.amazonaws.com]
          Action: ['sts:AssumeRole']
      Path: /
      Policies:
      - PolicyName: service-autoscaling
        PolicyDocument:
          Statement:
          - Effect: Allow
            Action:
              - 'application-autoscaling:*'
              - 'cloudwatch:DescribeAlarms'
              - 'cloudwatch:PutMetricAlarm'
              - 'ecs:DescribeServices'
              - 'ecs:UpdateService'
            Resource: '*'
  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Path: /
      Roles: [!Ref 'EC2Role']

Outputs:
  ClusterName:
    Description: The name of the ECS cluster, used by the deploy script
    Value: !Ref 'ECSCluster'
    Export:
      Name: !Join [':', [!Ref "AWS::StackName", "ClusterName" ]]
  Url:
    Description: The url at which the application is available
    Value: !Join ['', [!GetAtt 'ECSALB.DNSName']]
  ALBArn:
    Description: The ARN of the ALB, exported for later use in creating services
    Value: !Ref 'ECSALB'
    Export:
      Name: !Join [':', [!Ref "AWS::StackName", "ALBArn" ]]
  ECSRole:
    Description: The ARN of the ECS role, exports for later use in creating services
    Value: !GetAtt 'ECSServiceRole.Arn'
    Export:
      Name: !Join [':', [!Ref "AWS::StackName", "ECSRole" ]]
  VPCId:
    Description: The ID of the VPC that this stack is deployed in
    Value: !Ref 'VPC'
    Export:
      Name: !Join [':', [!Ref "AWS::StackName", "VPCId" ]]
