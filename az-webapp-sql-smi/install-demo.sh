#!/bin/bash
# Cybergavin - 22-FEB-2022
# This script uses Azure CLI (az) to spin up a demo on Azure of a PHP web app deployed
# on an Azure App Service Plan and using an Azure SQL Database with a system-assigned managed identity (SMI).
#
#############################################################################################################################
#
# Record script output
#
script_location="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
script_name=`basename $0`
config=${script_location}/${script_name%%.*}.cfg
logfile=${script_location}/${script_name%%.*}.log; cat /dev/null > $logfile
exec 2> ${script_location}/${script_name%%.*}.stderr
#
# Source config
#
if [ -s $config ]; then
    source $config
else
    echo "Missing config file ${config}. Exiting!"
    exit 100
fi
#
# Basic validation
#
if [ -z "$my_public_ip" -o -z "$azure_ad_user" -o -z "$azure_subscription" ]; then
    echo "One or more variables (my_public_ip/azure_ad_user/azure_subscription) without value. Exiting!"
    exit 200
fi
#
# Obtain required credentials
#
# Password for Azure AD User
while [ -z "$azure_ad_password" ]
do
  echo -n "Enter password for your Azure AD user (${azure_ad_user}) : "
  read -s azure_ad_password
done
#
# Azure CLI
#
# Login and switch subscription
az login -u $azure_ad_user -p $azure_ad_password >> $logfile
[[ $? -eq 0 ]] && echo -e "\nLogged in via Azure CLI\n" | tee -a $logfile
az account set -s $azure_subscription >> $logfile
[[ $? -eq 0 ]] && echo -e "Switched to subscription ${azure_subscription} \n" | tee -a $logfile
# Obtain Object ID for Azure AD user
azure_ad_user_oid=$(az ad user list --upn $azure_ad_user --query [].objectId -o tsv)
[[ $? -eq 0 ]] && echo -e "Obtained Object ID for ${azure_ad_user}\n" | tee -a $logfile
# Create resource group
az group create --location $location --name $resource_group >> $logfile
[[ $? -eq 0 ]] && echo -e "Created resource group ${resource_group}\n" | tee -a $logfile
# Create app service plan
az appservice plan create --name $app_service_plan --resource-group $resource_group --is-linux >> $logfile
[[ $? -eq 0 ]] && echo -e "Created app service plan ${app_service_plan}\n" | tee -a $logfile
# Create webapp deployment user
az webapp deployment user set --user-name $webapp_deployment_user --password $azure_ad_password >> $logfile
[[ $? -eq 0 ]] && echo -e "Created webapp deployment user ${webapp_deployment_user}\n" | tee -a $logfile
# Create Logical SQL Server for Azure SQL Database
az sql server create --name $db_server --resource-group $resource_group --enable-ad-only-auth --external-admin-principal-type User --external-admin-name $azure_ad_user --external-admin-sid $azure_ad_user_oid >> $logfile
[[ $? -eq 0 ]] && echo -e "Created logical SQL server ${db_server}\n" | tee -a $logfile
# Create firewall rules for Logical SQL Server
az sql server firewall-rule create --resource-group $resource_group --server $db_server --name myruleaz --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 >> $logfile
[[ $? -eq 0 ]] && echo -e "Created firewall rules for SQL Server to allow connectivity from Azure services\n" | tee -a $logfile
az sql server firewall-rule create --resource-group $resource_group --server $db_server --name myrule100 --start-ip-address $my_public_ip --end-ip-address $my_public_ip >> $logfile
[[ $? -eq 0 ]] && echo -e "Created firewall rules for SQL Server to allow connectivity from your public IP ${my_public_ip}\n" | tee -a $logfile
# Create Azure SQL Database
az sql db create --name $db --resource-group $resource_group --server $db_server --service-objective S0 >> $logfile
[[ $? -eq 0 ]] && echo -e "Created Azure SQL database ${db}\n" | tee -a $logfile
# Create web app
az webapp create --name $app --resource-group $resource_group --plan $app_service_plan --runtime $app_runtime --deployment-local-git >> $logfile
[[ $? -eq 0 ]] && echo -e "Created webapp ${app}\n" | tee -a $logfile
az webapp identity assign --name $app --resource-group $resource_group >> $logfile
[[ $? -eq 0 ]] && echo -e "Enabled system-assigned identity for webapp ${app}\n" | tee -a $logfile
# Configure environment variables
az webapp config appsettings set --resource-group $resource_group --name $app --settings DEPLOYMENT_BRANCH='main' >> $logfile
[[ $? -eq 0 ]] && echo -e "Configured environment variable DEPLOYMENT_BRANCH for webapp ${app}\n" | tee -a $logfile
az webapp config appsettings set --resource-group $resource_group --name $app --settings DB_SERVER=${db_server}.database.windows.net >> $logfile
[[ $? -eq 0 ]] && echo -e "Configured environment variable DB_SERVER for webapp ${app}\n" | tee -a $logfile
az webapp config appsettings set --resource-group $resource_group --name $app --settings DB_NAME=$db >> $logfile
[[ $? -eq 0 ]] && echo -e "Configured environment variable DB_NAME for webapp ${app}\n" | tee -a $logfile
echo -e "Sleeping for 10 seconds...Zzzzz\n" | tee -a $logfile
sleep 10
# Create contained user in Azure SQL Database for user-assigned managed identity (Requires sqlcmd')
sqlcmd -S ${db_server}.database.windows.net -d $db -G -C -U $azure_ad_user -P $azure_ad_password <<EOSQL
CREATE USER [${app}] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [${app}];
ALTER ROLE db_datawriter ADD MEMBER [${app}];
ALTER ROLE db_ddladmin ADD MEMBER [${app}];
GO
exit
EOSQL
[[ $? -eq 0 ]] && echo -e "Created contained user ${app} in database ${db}\n" | tee -a $logfile
#
# GIT DEPLOY
#
echo -e "Deploying webapp from local git...\n" | tee -a $logfile
git init
git switch -c main
git remote add azure "https://${webapp_deployment_user}@${app}.scm.azurewebsites.net/${app}.git"
git add * 
git commit -m "Initial commit - demo app"
git push azure main