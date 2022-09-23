# Uber Remote Shuffle Service (RSS) with EMR on EKS

Uber Remote Shuffle Service provides the capability for Apache Spark applications to store shuffle data 
on remote servers. See more details on Spark community document: 
[[SPARK-25299][DISCUSSION] Improving Spark Shuffle Reliability](https://docs.google.com/document/d/1uCkzGGVG17oGC6BJ75TpzLAZNorvrAU3FRd2X-rVHSM/edit?ts=5e3c57b8).

The high level design for Remote Shuffle Service could be found [here](https://github.com/uber/RemoteShuffleService/blob/master/docs/server-high-level-design.md).

## Infra Provision
If you do not have your own environment to run Spark, run the command:
```
./eks_provision.sh
```
which provides a one-click experience to create an EMR on EKS environment and OSS Spark Operator on a common EKS cluster. The EKS cluster contains two managed nodegroups in the same AZ (to avoid the network latency between jobs and RSS):
- 1 - [`rss-c5d4`](https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service/blob/e81ed02da9a470889dd806a7be6ed9f160510563/eks_provision.sh#L92) that scales c5d.4clarge instances from 1 to 30. They are labelled as `app=rss` to host the RSS server specifically.
- 2 - [`c59d`](https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service/blob/e81ed02da9a470889dd806a7be6ed9f160510563/eks_provision.sh#L111) that scales c5d.9xlarge instances from 1 to 50. They are labelled as `app=sparktest` for running EMR on EKS and OSS Spark performance tests in parallel.

## Quick Start: Run Spark Application With Pre-Built Images

### Deploy RSS server to EKS using Helm

Run following command under root directory of this project:

```bash
git clone https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service.git
cd emr-on-eks-remote-shuffle-service.git

helm install remote-shuffle-service charts/remote-shuffle-service -f charts/remote-shuffle-service/values.yaml -n remote-shuffle-service --create-namespace
```

Before the installation, take a look at the [charts/remote-shuffle-service/values.yaml](./charts/remote-shuffle-service/values.yaml). There are few configs need to pay attention to. 

#### 1. Node selector was set
```yaml
nodeSelector:
    app: rss
```    
It means the RSS Server will be installed on EC2 instances(nodes) that have the label of `app=rss` on EKS. By doing this, we can assign RSS service to a sepcific instance type with scalable SSD disk mounted, [`c5d.4xlarge`](https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service/blob/10c17b35cc37d4984d6c562c19666aa31e32b3b4/eks_provision.sh#L98) in this case. Change the label name based on your EKS setup or simply remove these two lines to run RSS on any instances.

#### 2. Access control to RSS data storage 
At RSS client (Spark applications), we use `Hadoop` to run jobs. They are also the user to write to the shuffle service disks on the server. For EMR on EKS, you should run the RSS server under 999:1000 permission.
```bash
# configure the shuffle service volume owner as Hadoop user (EMR on EKS is 999:1000, OSS Spark is 1000:1000)
volumeUser: 999
volumeGroup: 1000

```
#### 3. Mount a high performant disk
The current RSS version only support a single disk for the storage. 
Without specify the `rootdir`, by default, your RSS server will use a local EBS root volume to store the shuffle data. Generally, it is too small to handle a large scale of data IO. It is recommended to mount a larger size and high performant disk, such as your local nvme SSD disk or EFS or FSx storage.

```bash
volumeMounts:
  - name: spark-local-dir-1
    mountPath: /rss1
volumes:
  - name: spark-local-dir-1
    hostPath:
      path: /local1
command:
  jvmHeapSizeOption: "-Xmx800M"
  # point to a nmve SSD volume as the shuffle data storage, not use root volume.
  # only support a single disk by the RSS so far
  rootdir: "/rss1"
```

### Run Spark benchmark With RSS client

#### Build a custom docker image including the benchmark utility tool and Remote Shuffle Service client jar

Login to ECR in your account and create a repository called `rss-spark-benchmark`:
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
aws ecr create-repository --repository-name rss-spark-benchmark --image-scanning-configuration scanOnPush=true
```

Build EMR om EKS image:
```bash
export SRC_ECR_URL=755674844232.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $SRC_ECR_URL
docker pull $SRC_ECR_URL/spark/emr-6.7.0:latest

docker build -t $ECR_URL/rss-spark-benchmark:emr6.7 -f docker/emr-jdk8/Dockerfile --build-arg SPARK_BASE_IMAGE=$SRC_ECR_URL/spark/emr-6.7.0:latest .
docker push $ECR_URL/rss-spark-benchmark:emr6.7
```

Build an OSS Spark docker image:
```bash
docker build -t $ECR_URL/rss-spark-benchmark:3.2.1 -f docker/oss-jdk11/Dockerfile --build-arg SPARK_BASE_IMAGE=public.ecr.aws/a0x7p3j1/spark:3.2.1 .
docker push $ECR_URL/rss-spark-benchmark:3.2.1
```

Add configure to your Spark application like following, keep string like `rss-%s` inside value for `spark.shuffle.rss.serverSequence.connectionString`, since `RssShuffleManager` will use that to format connection string for different RSS server instances:

```bash
"spark.shuffle.manager": "org.apache.spark.shuffle.RssShuffleManager",
"spark.shuffle.rss.serviceRegistry.type": "serverSequence",
"spark.shuffle.rss.serverSequence.connectionString": "rss-%s.rss.remote-shuffle-service.svc.cluster.local:9338",
"spark.shuffle.rss.serverSequence.startIndex": "0",
"spark.shuffle.rss.serverSequence.endIndex": "4",
"spark.serializer": "org.apache.spark.serializer.KryoSerializer",
"spark.dynamicAllocation.enabled": "true",
"spark.dynamicAllocation.minExecutors": "1",
"spark.dynamicAllocation.maxExecutors": "50",
"spark.dynamicAllocation.shuffleTracking.enabled": "true",
"spark.dynamicAllocation.shuffleTracking.timeout": "1"
```

Please note the value for "spark.shuffle.rss.serverSequence.connectionString" contains string like "rss-%s". This is intended because 
RssShuffleManager will use it to generate actual connection string like rss-0.xxx and rss-1.xxx.

`"spark.shuffle.rss.serviceRegistry.type": "serverSequence",` means the metadata will be stored in memory, this is suitable to a quick start testing. For production workloads, it is recommended to use the zookeeper, similar to this Spark config:
```bash
"spark.shuffle.rss.serviceRegistry.type": "zookeeper",
"spark.shuffle.rss.serviceRegistry.zookeeper.servers": "zkServer1:2181"
```


### Run Benchmark

#### Generate the TCP-DS source data
```bash
kubectl apply -f examples/tpcds-data-generation.yaml
```

#### Run EMR on EKS Spark benchmark test:
```bash
./example/emr6.8-benchmark-c5.sh
````

#### Run OSS Spark benchmark:
```bash
kubectl apply -f tpcds-benchmark.yaml
```
