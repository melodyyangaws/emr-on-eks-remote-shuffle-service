<configuration>

      if [ -z "${CSS_HOME}" ]; then
        export CSS_HOME="$(cd "`dirname "$0"`"/..; pwd)"
      fi

      export CSS_CONF_DIR="${CSS_CONF_DIR:-"${CSS_HOME}/conf"}"


      # mark default conf here
      # export CSS_MASTER_HOST=localhost
      export CSS_MASTER_PORT=9099

      # export CSS_WORKER_HOST=localhost
      export CSS_WORKER_PORT=0

      # no need to set this (use random port instead)
      export CSS_WORKER_PUSH_PORT=0
      export CSS_WORKER_FETCH_PORT=0

      export MASTER_JAVA_OPTS="-Xmx8192m"
      export WORKER_JAVA_OPTS="-Xmx8192m -XX:MaxDirectMemorySize=100000m"

      export CSS_WORKER_INSTANCES= f{{- if not (index .Env  "HIVE_WAREHOUSE_DIR")  }}

      # standalone mode
      CSS_MASTER_HOST=<HOST_IP>
      MASTER_JAVA_OPTS="-Xmx8192m"
      WORKER_JAVA_OPTS="-Xmx8192m -XX:MaxDirectMemorySize=100000m"
       
      # zookeeper mode
      WORKER_JAVA_OPTS="-Xmx8192m -XX:MaxDirectMemorySize=100000m"
       

        <property>
          <name>metastore.expression.proxy</name>
          <value>org.apache.hadoop.hive.metastore.DefaultPartitionExpressionProxy</value>
        </property>
        <property>
          <name>metastore.task.threads.always</name>
          <value>org.apache.hadoop.hive.metastore.events.EventCleanerTask,org.apache.hadoop.hive.metastore.MaterializationsCacheCleanerTask</value>
        </property>
        <property>
          <name>hive.metastore.uris</name>
          <value>{{ $metastore_uris }}</value>
        </property>
        {{- if not (index .Env  "HIVE_WAREHOUSE_DIR")  }}
        <property>
          <name>hive.metastore.warehouse.dir</name>
          <value>file:///tmp/</value>
        </property>
        {{- else }}
         <property>
          <name>hive.metastore.warehouse.dir</name>
          <value>{{ .Env.HIVE_WAREHOUSE_DIR }}</value>
        </property>  
      {{- end }}
     {{- if (index .Env "HIVE_CONF_PARAMS")  }}
        {{- $conf_list := .Env.HIVE_CONF_PARAMS | strings.Split ";" }}
        {{- range $parameter := $conf_list}}
            {{- $key := regexp.Replace "(.*):.*" "$1" $parameter }}
            {{- $value := regexp.Replace ".*:(.*)" "$1" $parameter }}
        <property>
          <name>{{ $key }}</name>
          <value>{{ $value }}</value>
        </property>
       {{- end }}
     {{- end }}

</configuration>