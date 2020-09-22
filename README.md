# Oracle_Plugin for GCP custom Metrics

1. Requirements:

1-1. Install Oracle_Home
1-2. Create TNS entry
1-3. Check your Primary Oracle group, typically oinstall or dba

2. Installation :

run as a root with 3 variables passing in exact sequence. $ORACLE_HOME, Primary Oracle GROUP, $TNS_ADIM
./installStackDriverOraclePlugin.sh /opt/oracle/product/19c/dbhome_1 oinstall /opt/oracle/product/19c/dbhome_1/network/admin

3. Add Oracle collectd config :

create the file "oracle.conf" under /opt/stackdriver/collectd/etc/collectd.d

Add these example of lines:
###########################

LoadPlugin oracle
<Plugin oracle>
    <Query "disk_rw_bytes">
      Statement "SELECT sum(vf.PHYBLKRD)*8192 AS PHY_BLK_R, \
                      'bytes_read' AS r_prefix, \
                      sum(vf.PHYBLKWRT)*8192 AS PHY_BLK_W, \
                      'bytes_written' AS w_prefix, \
                      dt.tablespace_name \
                   FROM ((dba_data_files dd JOIN v$filestat vf ON dd.file_id = vf.file# ) \
                         JOIN dba_tablespaces dt ON dd.tablespace_name = dt.tablespace_name) \
                   GROUP BY dt.tablespace_name"
      <Result>
       Type "derive"
       InstancesFrom "r_prefix" "TABLESPACE_NAME"
       ValuesFrom "PHY_BLK_R"
     </Result>
     <Result>
       Type "derive"
       InstancesFrom "w_prefix" "TABLESPACE_NAME"
       ValuesFrom "PHY_BLK_W"
     </Result>
    </Query>
    <Query "uptime">
      Statement "select sysdate-startup_time as UP_TIME, 'DB_UP_TIME_DAYS' as i_prefix, INSTANCE_NAME from v$instance"
        <Result>
          Type "gauge"
          InstancesFrom "i_prefix" "INSTANCE_NAME"
          ValuesFrom "UP_TIME"
        </Result>
    </Query>
     <Query "tbs_free">
      Statement "select round(100 * (fs.freespace / df.totalspace)) as PCT_FREE, 'tablespace_free' AS i_prefix, fs.tablespace_name
from (select tablespace_name, round(sum(bytes) / 1048576) TotalSpace from dba_data_files group by tablespace_name) df, (select tablespace_name, round(sum(bytes) / 1048576) FreeSpace from dba_free_space group by tablespace_name) fs where df.tablespace_name = fs.tablespace_name order by PCT_FREE"
        <Result>
          Type "gauge"
          InstancesFrom "i_prefix" "TABLESPACE_NAME"
          ValuesFrom "PCT_FREE"
        </Result>
    </Query>
    <Query "top_5_sqlelaps">
      Statement "SELECT * FROM (SELECT sql_id SQL_ID, 'TOP_5_SQL_ORDER_BY_ELAPSED_TIME' as i_prefix, elapsed_time FROM v$sql ORDER BY elapsed_time DESC) WHERE ROWNUM < 6"
        <Result>
          Type "gauge"
          InstancesFrom "i_prefix" "SQL_ID"
          ValuesFrom "ELAPSED_TIME"
        </Result>
    </Query>
    <Query "top_5_waits">
      Statement "select * from ( Select a.average_wait AS AVERAGE_WAIT, 'top_5_waits' AS i_prefix, REPLACE(a.event, ' ', '') as waitevent From v$system_event a, v$event_name b, v$system_wait_class c Where a.event_id=b.event_id And b.wait_class#=c.wait_class# And c.wait_class in ('Application','Concurrency') order by average_wait desc) where rownum <6"
        <Result>
          Type "gauge"
          InstancesFrom "i_prefix" "WAITEVENT"
          ValuesFrom "AVERAGE_WAIT"
        </Result>
    </Query>
    <Query "top_io_waits">
      Statement "select round(10*m.time_waited/nullif(m.wait_count,0),3) avg_ms, 'io_waits' AS i_prefix, n.name from v$eventmetric m, v$event_name n where m.event_id=n.event_id and n.name in ('db file sequential read','db file scattered read','direct path read','direct path read temp','direct path write','direct path write temp','log file sync','log file parallel write')"
        <Result>
          Type "gauge"
          InstancesFrom "i_prefix" "NAME"
          ValuesFrom "AVG_MS"
        </Result>
    </Query>
    <Query "session_count_by_user">
      Statement "select count(1) as NUM_USERS, 'session_count_by_user' as i_prefix, username from v$session where username is NOT NULL group by username"
        <Result>
          Type "gauge"
          InstancesFrom "i_prefix" "USERNAME"
          ValuesFrom "NUM_USERS"
        </Result>
    </Query>
     <Database "oracledb_oraclepdb1">
       #Plugin "warehouse"
       ConnectID "orclpdb1"
       Username "your oracle user name"
       Password "your oracle epassword"
       Query "disk_rw_bytes"
       Query "tbs_free"
       Query "uptime"
       Query "top_5_sqlelaps"
       Query "top_5_waits"
       Query "top_io_waits"
       Query "session_count_by_user"
     </Database>
</Plugin>
LoadPlugin match_regex
LoadPlugin target_set
LoadPlugin target_replace
PreCacheChain "PreCache"
<Chain "PreCache">
  <Rule "jump_to_custom_metrics_from_oracle">
    <Match regex>
      Plugin "^oracle$"
    </Match>
    <Target "jump">
      Chain "PreCache_oracle"
    </Target>
  </Rule>
</Chain>
<Chain "PreCache_oracle">
  <Rule "rewrite_oracle_my_special_metric">
    <Match regex>
      Plugin "^oracle$"
      Type "^(gauge|derive|counter)$"
     # TypeInstance "^I_prefix
    </Match>
    <Target "set">
      MetaData "__metric_name" "%{type_instance}"
      MetaData "__label" "%{type_instance}"
    </Target>
    <Target "replace">
      MetaData "__metric_name" "-.*$" ""
      MetaData "__label" "^.*-" ""
    </Target>
    <Target "set">
      MetaData "stackdriver_metric_type" "custom.googleapis.com/oracle/%{meta:__metric_name}"
      MetaData "label:database" "%{plugin_instance}"
      MetaData "label:name" "%{meta:__label}"
    </Target>
  </Rule>
  <Rule "go_back">
    Target "return"
  </Rule>
</Chain>

##

4. Start the GCP stack driver:
service stackdriver-agent start
