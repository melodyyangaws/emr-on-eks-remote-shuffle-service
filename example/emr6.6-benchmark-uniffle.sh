#!/bin/bash
# SPDX-FileCopyrightText: Copyright 2021 Amazon.com, Inc. or its affiliates.
# SPDX-License-Identifier: MIT-0

# "spark.kubernetes.executor.podTemplateFile": "s3://'$S3BUCKET'/app_code/pod-template/executor-heapvolume.yaml",
# "spark.executor.extraJavaOptions": "-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/dumps/oom.hprof",

# export EMRCLUSTER_NAME=emr-on-eks-rss          
# export AWS_REGION=us-east-1
export ACCOUNTID=$(aws sts get-caller-identity --query Account --output text)
export VIRTUAL_CLUSTER_ID=$(aws emr-containers list-virtual-clusters --query "virtualClusters[?name == '$EMRCLUSTER_NAME' && state == 'RUNNING'].id" --output text)
export EMR_ROLE_ARN=arn:aws:iam::$ACCOUNTID:role/$EMRCLUSTER_NAME-execution-role
export S3BUCKET=${EMRCLUSTER_NAME}-${ACCOUNTID}-${AWS_REGION}
export ECR_URL="$ACCOUNTID.dkr.ecr.$AWS_REGION.amazonaws.com"

aws emr-containers start-job-run \
  --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
  --name em66-3uniffle-adjsnappy \
  --execution-role-arn $EMR_ROLE_ARN \
  --release-label emr-6.6.0-latest \
  --job-driver '{
  "sparkSubmitJobDriver": {
      "entryPoint": "local:///usr/lib/spark/examples/jars/eks-spark-benchmark-assembly-1.0.jar",
      "entryPointArguments":["s3://'$S3BUCKET'/BLOG_TPCDS-TEST-3T-partitioned","s3://'$S3BUCKET'/EMRONEKS_TPCDS-TEST-3T-RESULT","/opt/tpcds-kit/tools","parquet","3000","1","false","q23a-v2.4,q23b-v2.4","true"],
      "sparkSubmitParameters": "--class com.amazonaws.eks.tpcds.BenchmarkSQL --conf spark.driver.cores=2 --conf spark.driver.memory=3g --conf spark.executor.cores=4 --conf spark.executor.memory=6g --conf spark.executor.instances=47"}}' \
  --configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.kubernetes.container.image": "'$ECR_URL'/uniffle-spark-benchmark:emr6.6",
          "spark.kubernetes.executor.podNamePrefix": "emr-eks-uniffle",
          "spark.serializer": "org.apache.spark.serializer.KryoSerializer",
          "spark.executor.memoryOverhead": "2G",


          "spark.shuffle.manager": "org.apache.spark.shuffle.RssShuffleManager",
          "spark.rss.coordinator.quorum": "rss-coordinator-uniffle-rss-0.uniffle.svc.cluster.local:19997,rss-coordinator-uniffle-rss-1.uniffle.svc.cluster.local:19997",
          "spark.rss.storage.type": "MEMORY_LOCALFILE",
          "spark.rss.remote.storage.path": "/rss1/rssdata,/rss2/rssdata",
          "spark.rss.writer.buffer.size": "1100k",
          "spark.rss.client.send.threadPool.keepalive": "240",
          "spark.rss.client.read.buffer.size": "20m",
          "spark.rss.client.io.compression.codec": "SNAPPY",
  
          "spark.kubernetes.node.selector.eks.amazonaws.com/nodegroup": "c59b"

      }},
      {
        "classification": "spark-log4j",
        "properties": {
          "log4j.rootCategory":"WARN, console"
        }
      }
    ],
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {"logUri": "s3://'$S3BUCKET'/elasticmapreduce/emr-containers"}}}'
