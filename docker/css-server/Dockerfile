# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
# ARG SPARK_BASE_IMAGE=public.ecr.aws/myang-poc/spark:3.2.1_hadoop_3.3.1

FROM amazoncorretto:8 as rss-jdk8
ARG MAVEN_VERSION=3.8.6
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

# install maven
RUN yum update -y && yum install -y git tar
RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
 && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
 && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
 && rm -f /tmp/apache-maven.tar.gz \
 && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

# compile CSS server & client
RUN git clone https://github.com/bytedance/CloudShuffleService.git /tmp/CloudShuffleService
WORKDIR /tmp/CloudShuffleService
RUN ./build.sh

RUN mv css-*-bin.tgz css-bin.tgz \
    && mkdir -p /usr/share/css \
    && tar -xzf /tmp/CloudShuffleService/css-bin.tgz -C /usr/share/css --strip-components=1 \
    && rm -f /tmp/CloudShuffleService/css-bin.tgz

ENV CSS_HOME /usr/share/css
WORKDIR ${CSS_HOME}
# zookeeper mode
# RUN ./sbin/start-workers.sh
# standalone mode
# RUN ./sbin/start-all.sh

# # for client
# RUN cp $CSS_HOME/client/spark-3/*.jar to $SPARK_HOME/jars/

