 #!/bin/bash
set -e

#expecting 2 parameters. First the uaa api endpoint, 2nd the uaa admin credential, and 3rd the exporter password
addExporterUaaUsers(){
    uaac target $1 --skip-ssl-validation
    uaac token client get admin -s $2
    uaac client add firehose_exporter \
        --name prometheus-firehose \
        --secret $3 \
        --authorized_grant_types client_credentials,refresh_token \
        --authorities doppler.firehose

    uaac client add cf_exporter \
        --name cf_exporter \
        --secret $4 \
        --authorized_grant_types client_credentials,refresh_token \
        --authorities cloud_controller.global_auditor
}

#expecting a single string input parameter
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

echo -n "The number of environment(s) to configure [ENTER]: "
read envNum
validateIntegerInput $envNum

for (( c=1; c<=$envNum; c++ )) do
    echo -n "Enter UAA endpoint url (https://uaa.sys.example.com): [ENTER]: "
    read uaaUrl
    validateStringInput $uaaUrl

    echo -n "Enter uaa admin client credential for the environment [ENTER]: "
    read adminCred
    validateStringInput $adminCred

    echo -n "Enter firehose_exporter password [ENTER]: "
    read firehose_exporterPassword
    validateStringInput $firehose_exporterPassword
    
    echo -n "Enter cf_exporter password [ENTER]: "
    read cf_exporterPassword
    validateStringInput $cf_exporterPassword

    addExporterUaaUsers $uaaUrl $adminCred $firehose_exporterPassword $cf_exporterPassword
    
done

