# Standalone remote shuffle service with EMR on EKS

Remote Shuffle Service provides the capability for Apache Spark applications to store shuffle data 
on remote servers. See more details on Spark community document: 
[[SPARK-25299][DISCUSSION] Improving Spark Shuffle Reliability](https://docs.google.com/document/d/1uCkzGGVG17oGC6BJ75TpzLAZNorvrAU3FRd2X-rVHSM/edit?ts=5e3c57b8).

The high level design for Uber's Remote Shuffle Service (RSS) can be found [here](https://github.com/uber/RemoteShuffleService/blob/master/docs/server-high-level-design.md), ByteDance's Cloud Shuffle Service (CSS) can be found [here](https://github.com/bytedance/CloudShuffleService), OPPO's Shuttle can be found [here](https://github.com/cubefs/shuttle/blob/master/docs/server-high-level-design.md)

## Infra Provision
If you do not have your own environment to run Spark, run the command. Change the region if needed.
```
export EKSCLUSTER_NAME=eks-rss
export AWS_REGION=us-east-1
./eks_provision.sh
```
which provides a one-click experience to create an EMR on EKS environment and OSS Spark Operator on a common EKS cluster. The EKS cluster contains the following managed nodegroups which are located in a single AZ within the same [Cluster placment strategy](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html) to achieve the low-latency network performance for the intercommunication between apps and shuffle servers:
- 1 - [`rss-i3en`](https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service/blob/99e7b2efbbd25a72435cc00a8bed6e14e91f415b/eks_provision.sh#L104) that scales i3en.6xlarge instances from 1 to 20. They are labelled as `app=rss` to host the RSS servers.
- 2 - [`css-i3en`](https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service/blob/99e7b2efbbd25a72435cc00a8bed6e14e91f415b/eks_provision.sh#L128) that scales i3en.6xlarge instances from 1 to 20. They are labelled as `app=css` to host the CSS servers.
- 2 - [`c59d`](https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service/blob/e81ed02da9a470889dd806a7be6ed9f160510563/eks_provision.sh#L111) that scales c5d.9xlarge instances from 1 to 50. They are labelled as `app=sparktest` to run both EMR on EKS and OSS Spark testings in parallel. The node group can also be used to run TPCDS source data generation job if needed.

## Quick Start: Run shuffle server with pre-built images
```bash
git clone https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service.git
cd emr-on-eks-remote-shuffle-service.git
```
### 1. Install Uber's RSS server on EKS

#### Helm install RSS
```bash
helm install rss ./charts/remote-shuffle-service -n remote-shuffle-service --create-namespace

# OPTIONAL: scale up or scale down the Shuffle server
kubectl scale statefulsets rss -n remote-shuffle-service  --replicas=0
kubectl scale statefulsets rss -n remote-shuffle-service  --replicas=3
```
```bash
#uninstall
helm uninstall rss
kubectl delete namespace remote-shuffle-service
```
Before the installation, take a look at the [charts/remote-shuffle-service/values.yaml](./charts/remote-shuffle-service/values.yaml). There are few configurations need to pay attention to: 

#### Node selector
```yaml
nodeSelector:
    app: rss
```    
It means the RSS Server will only be installed on EC2 instances that have the label `app=rss`. By doing this, we can assign RSS service to a specific instance type with SSD disk mounted, [`i3en.6xlarge`](https://github.com/melodyyangaws/emr-on-eks-remote-shuffle-service/blob/de77e588a2c89080e448f75321f4174a51c77799/eks_provision.sh#L98) in this case. Change the label name based on your EKS setup or simply remove these two lines to run RSS on any instances.

#### Access control to RSS data storage 
At RSS client (Spark applications), we use `Hadoop` to run jobs. They are also the user to write to the shuffle service disks on the server. For EMR on EKS, you should run the RSS server under 999:1000 permission.
```bash
# configure the shuffle service volume owner as Hadoop user (EMR on EKS is 999:1000, OSS Spark is 1000:1000)
volumeUser: 999
volumeGroup: 1000

```
#### Mount a high performant disk
The current RSS version only support a single disk for the storage. 
Without specify the `rootdir`, by default, RSS server uses a local EBS root volume to store the shuffle data. However, it is normally too small to handle a large volume of shuffling data. It is recommended to mount a larger size and high performant disk, such as a local nvme SSD disk or [FSx for Lustre storage](https://aws.amazon.com/blogs/big-data/run-apache-spark-with-amazon-emr-on-eks-backed-by-amazon-fsx-for-lustre-storage/).
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
  # the RSS only supports a single disk so far. Use storage optmized EC2 instance type.
  rootdir: "/rss1"
```

### 2. Build a custom image with RSS client
Build a custom docker image to include the [Spark benchmark utility](https://github.com/aws-samples/emr-on-eks-benchmark#spark-on-kubernetes-benchmark-utility) tool and a Remote Shuffle Service client

Login to ECR in your account and create a repository called `rss-spark-benchmark`:
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
aws ecr create-repository --repository-name rss-spark-benchmark --image-scanning-configuration scanOnPush=true
```

Build EMR om EKS image:
```bash
# The custom image includes Spark Benchmark Untility and RSS client. We use EMR 6.6 (Spark 3.2.0) as the base image
export SRC_ECR_URL=755674844232.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $SRC_ECR_URL
docker pull $SRC_ECR_URL/spark/emr-6.6.0:latest

docker build -t $ECR_URL/rss-spark-benchmark:emr6.6 -f docker/rss-emr-client/Dockerfile --build-arg SPARK_BASE_IMAGE=$SRC_ECR_URL/spark/emr-6.6.0:latest .
docker push $ECR_URL/rss-spark-benchmark:emr6.6
```

Build an OSS Spark docker image:
```bash
docker build -t $ECR_URL/rss-spark-benchmark:3.2.0 -f docker/rss-oss-client/Dockerfile --build-arg SPARK_BASE_IMAGE=public.ecr.aws/myang-poc/spark:3.2.0_hadoop_3.3.1 .
docker push $ECR_URL/rss-spark-benchmark:3.2.0
```

### 3. Install ByteDance's CSS server on EKS
#### Install Zookeeper via Helm Chart
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install zookeeper bitnami/zookeeper -n zk -f charts/zookeeper/values.yaml 
```
#### Helm install CSS
```bash
helm install css ./charts/cloud-shuffle-service -n css --create-namespace

# OPTIONAL: scale up or scale down the Shuffle server
kubectl scale statefulsets css -n css  --replicas=0
kubectl scale statefulsets css -n css  --replicas=3
```
Before the installation, take a look at the configuration [charts/cloud-shuffle-service/values.yaml](./charts/cloud-shuffle-service/values.yaml) and modify it based on your EKS setup.

```bash
#uninstall
helm uninstall css
kubectl delete namespace css
```

### 4. Build a custom image with CSS client on EMR

Login to ECR and create a repository called `css-spark-benchmark`:
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
aws ecr create-repository --repository-name css-spark-benchmark --image-scanning-configuration scanOnPush=true
```

Build EMR om EKS image
```bash
# The custom image includes Spark Benchmark Untility and CSS client. We use EMR 6.6 (Spark 3.2.0) as the base image
export SRC_ECR_URL=755674844232.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $SRC_ECR_URL
docker pull $SRC_ECR_URL/spark/emr-6.6.0:latest

docker build -t $ECR_URL/css-spark-benchmark:emr6.6 -f docker/css-emr-client/Dockerfile --build-arg SPARK_BASE_IMAGE=$SRC_ECR_URL/spark/emr-6.6.0:latest .
docker push $ECR_URL/css-spark-benchmark:emr6.6
```

### 5. Run Benchmark

#### OPTIONAL: generate the TCP-DS source data
The job will generate TPCDS source data at 3TB scale to your S3 bucket `s3://'$S3BUCKET'/BLOG_TPCDS-TEST-3T-partitioned/`. Alternatively, directly copy the source data from `s3://blogpost-sparkoneks-us-east-1/blog/BLOG_TPCDS-TEST-3T-partitioned` to your S3.
```bash
kubectl apply -f examples/tpcds-data-generation.yaml
```

#### Run EMR on EKS Spark benchmark test:
Update the docker image name to your ECR URL in the following file, then run:
```bash
./example/emr6.6-benchmark-rss.sh
```
Or
```bash
./example/emr6.6-benchmark-css.sh
```

**NOTE**:in RSS test, keep the server string like `rss-%s` for the config `spark.shuffle.rss.serverSequence.connectionString`, This is intended because `RssShuffleManager` can use it to format the connection string dynamically:
```bash
"spark.shuffle.manager": "org.apache.spark.shuffle.RssShuffleManager",
"spark.shuffle.rss.serviceRegistry.type": "serverSequence",
"spark.shuffle.rss.serverSequence.connectionString": "rss-%s.rss.remote-shuffle-service.svc.cluster.local:9338",
"spark.shuffle.rss.serverSequence.startIndex": "0",
"spark.shuffle.rss.serverSequence.endIndex": "1",
"spark.serializer": "org.apache.spark.serializer.KryoSerializer",
```
The setting`"spark.shuffle.rss.serviceRegistry.type": "serverSequence"` means the metadata will be stored in a cluster of standalone RSS servers.


#### OPTIONAL: Run OSS Spark benchmark
NOTE: some queries may not be able to complete, due to the limited resources alloated to run such a large scale test:
Update the docker image name to your ECR URL, then run
```bash
kubectl apply -f tpcds-benchmark.yaml
```
