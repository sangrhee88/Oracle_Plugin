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

4. Start the GCP stack driver:

service stackdriver-agent start
