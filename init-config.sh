 #!/bin/bash
set -e
PARAM_FILE="prometheus-params.yml"
EXPORTER_OPS_FILE="prometheus-exporter-ops.yml"

validateStringInput(){
    if [ -z $1 ]; then
        echo "Invalid parameter entered" >&2; exit 1
    fi
}

#expecting a single integer input parameter
validateIntegerInput(){
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] ; then
        echo "Invalid parameter entered: Not a number" >&2; exit 1
    fi
}

if [ ! -f ./${PARAM_FILE} ] && [ ! -f ./ops/${EXPORTER_OPS_FILE} ]; then
  echo -n "The number of environment(s) to monitor [ENTER]: "
  read envNum
  validateIntegerInput $envNum

  # echo -n "Enter bosh url: [ENTER]: "
  # read boshUrl
  # validateStringInput $boshUrl

  # echo -n "Enter bosh client secret: [ENTER]: "
  # read boshSecret
  # validateStringInput $boshSecret

  # echo -n "Enter bosh client ca cert: [ENTER]: "
  # read boshCert
  # validateStringInput "$boshCert"

  cat > ./${PARAM_FILE} <<EOL
# Will be auto-generated if not specified
alertmanager_mesh_password: 
# Will be auto-generated if not specified
alertmanager_password: 

# Required only for alert manager slack integration
alertmanager_slack_api_url: 
alertmanager_slack_channel: 

# Required. Recommend to create the bosh_exporter UAA client with refresh_token grant type
bosh_url: 
uaa_bosh_exporter_client_id: bosh_exporter
uaa_bosh_exporter_client_secret: 
bosh_ca_cert: |
  -----BEGIN CERTIFICATE-----
 
  -----END CERTIFICATE-----
bosh_metrics_environment: Bosh

# Password to login grafana dashboard. Default user id is admin
grafana_password: 

# Will be auto-generated if not specified
grafana_secret_key: 
postgres_grafana_password: 

# Password to login prometheus server directly
prometheus_password:

# Required only for blackbox monitoring 
probe_endpoints:
- 

skip_ssl_verify: true
EOL

  cat > ./ops/${EXPORTER_OPS_FILE} <<EOL
- type: replace
  path: /instance_groups/name=prometheus/jobs/-
  value:
    name: bosh_exporter
    release: prometheus
    properties:
      bosh_exporter:
        bosh:
          url: "((bosh_url))"
          username: "((bosh_username))"
          password: "((bosh_password))"
          ca_cert: "((bosh_ca_cert))"
        metrics:
          environment: "((bosh_metrics_environment))"
EOL

  for (( c=1; c<=$envNum; c++ )) do
    echo -n "Enter environment name: [ENTER]: "
    read pcfName
    validateStringInput $pcfName

    echo -n "Enter pcf system domain (Ex: sys.example.com): [ENTER]: "
    read sysDomain
    #validateStringInput $sysDomain

    echo -n "Enter cf exporter secret: [ENTER]: "
    read cfExporterSecret
    #validateStringInput $cfExporterSecret

    echo -n "Enter firehose exporter secret: [ENTER]: "
    read firehoseExporterSecret
    #validateStringInput $firehoseExporterSecret
    echo "-----------------"

    cat >> ./${PARAM_FILE} <<EOL
${pcfName}_metrics_environment: $pcfName
${pcfName}_metron_deployment_name: cf
${pcfName}_system_domain: $sysDomain
${pcfName}_traffic_controller_external_port: 443
${pcfName}_uaa_clients_cf_exporter_secret: $cfExporterSecret
${pcfName}_uaa_clients_firehose_exporter_secret: $firehoseExporterSecret
EOL

    cat >> ./ops/${EXPORTER_OPS_FILE} <<EOL
- type: replace
  path: /instance_groups/-
  value:
    name: $pcfName
    azs:
      - z1
    instances: 1
    vm_type: default
    stemcell: default
    networks:
      - name: default
    jobs:
      - name: firehose_exporter
        release: prometheus
        properties:
          firehose_exporter:
            doppler:
              url: wss://doppler.((${pcfName}_system_domain)):((${pcfName}_traffic_controller_external_port))
              subscription_id: "((${pcfName}_metrics_environment))"
              max_retry_count: 300
            uaa:
              url: https://uaa.((${pcfName}_system_domain))
              client_id: firehose_exporter
              client_secret: "((${pcfName}_uaa_clients_firehose_exporter_secret))"
            metrics:
              environment: "((${pcfName}_metrics_environment))"
            skip_ssl_verify: ((skip_ssl_verify))
      - name: cf_exporter
        release: prometheus
        properties:
          cf_exporter:
            cf:
              api_url: https://api.((${pcfName}_system_domain))
              client_id: cf_exporter
              client_secret: "((${pcfName}_uaa_clients_cf_exporter_secret))"
              deployment_name: ((${pcfName}_metron_deployment_name))
            metrics:
              environment: "((${pcfName}_metrics_environment))"
            skip_ssl_verify: ((skip_ssl_verify))
EOL

  done

else 
   echo -e "\nAbort. Param file: ${PARAM_FILE} and/or exporter ops file: ./ops/${EXPORTER_OPS_FILE} already exist(s)."
fi
