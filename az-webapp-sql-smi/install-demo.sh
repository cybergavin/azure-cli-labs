#!/bin/bash
# Cybergavin (https://github.com/cybergavin/azure-cli-labs/blob/master/az-webapp-sql-smi/install-demo.sh)
# This script uses Azure CLI (az) to spin up a PHP webapp-database demo on Azure, using an Azure SQL Database 
# with a system-assigned managed identity (SMI).
#
#############################################################################################################################
script_location="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
script_name=`basename $0`
config=${script_location}/${script_name%%.*}.cfg
logfile=${script_location}/${script_name%%.*}.log; cat /dev/null > $logfile
exec 1> >(tee -a $logfile)
exec 2> ${script_location}/${script_name%%.*}.stderr
myrnd=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c5) # My random string to try to ensure unique names for Azure resources
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
# Variables
#
[[ -z "$resource_prefix" ]] && resource_prefix="myaz"
resource_group=${resource_prefix}-rg-webdb-${region_code}-${myrnd,,}
umi=${resource_prefix}-id-webdb-${myrnd,,}
app_service_plan=${resource_prefix}-plan-webdb-${region_code}-${myrnd,,}
app=${resource_prefix}-app-webdb-${region_code}-${myrnd,,}
webapp_deployment_user=${resource_prefix}-${myrnd,,}
db_server=${resource_prefix}-sql-webdb-${region_code}-${myrnd,,}
db=${resource_prefix}-sqldb-webdb-${region_code}-${myrnd,,}
#
# Basic validation
#
if [ -z "$my_public_ip" -o -z "$azure_ad_user" -o -z "$azure_subscription" -o -z "$region_name" -o -z "$region_code" ]; then
    echo "One or more variables (my_public_ip/azure_ad_user/azure_subscription/region_name/region_code) without value. Exiting!"
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
 # URLEncode password to cover special characters - for Git deployment of webapp
git_passwd=$(echo $azure_ad_password | perl -MURI::Escape -ne 'chomp;print uri_escape($_)')
#
# Azure CLI
#
# Login and switch subscription
az login -u $azure_ad_user -p $azure_ad_password >> $logfile
[[ $? -eq 0 ]] && echo -e "\nLogged in via Azure CLI\n" 
az account set -s $azure_subscription >> $logfile
[[ $? -eq 0 ]] && echo -e "Switched to subscription ${azure_subscription} \n" 
# Obtain Object ID for Azure AD user
azure_ad_user_oid=$(az ad user list --upn $azure_ad_user --query [].id -o tsv)
[[ $? -eq 0 ]] && echo -e "Obtained Object ID for ${azure_ad_user}\n" 
# Create resource group
az group create --location $region_name --name $resource_group >> $logfile
[[ $? -eq 0 ]] && echo -e "Created resource group ${resource_group}\n" 
# Create app service plan
az appservice plan create --name $app_service_plan --resource-group $resource_group --sku B2 --is-linux >> $logfile # Minimum SKU B2 to avoid frustration
[[ $? -eq 0 ]] && echo -e "Created app service plan ${app_service_plan}\n" 
# Create webapp deployment user
az webapp deployment user set --user-name $webapp_deployment_user --password $azure_ad_password >> $logfile
[[ $? -eq 0 ]] && echo -e "Created webapp deployment user ${webapp_deployment_user}\n" 
# Create Logical SQL Server for Azure SQL Database
az sql server create --name $db_server --resource-group $resource_group --enable-ad-only-auth --external-admin-principal-type User --external-admin-name $azure_ad_user --external-admin-sid $azure_ad_user_oid >> $logfile
[[ $? -eq 0 ]] && echo -e "Created logical SQL server ${db_server}\n" 
# Create firewall rules for Logical SQL Server
az sql server firewall-rule create --resource-group $resource_group --server $db_server --name myruleaz --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 >> $logfile
[[ $? -eq 0 ]] && echo -e "Created firewall rules for SQL Server to allow connectivity from Azure services\n" 
az sql server firewall-rule create --resource-group $resource_group --server $db_server --name myrule100 --start-ip-address $my_public_ip --end-ip-address $my_public_ip >> $logfile
[[ $? -eq 0 ]] && echo -e "Created firewall rules for SQL Server to allow connectivity from your public IP ${my_public_ip}\n" 
# Create Azure SQL Database
az sql db create --name $db --resource-group $resource_group --server $db_server --service-objective S0 >> $logfile
[[ $? -eq 0 ]] && echo -e "Created Azure SQL database ${db}\n" 
# Create web app
app_runtime=$(az webapp list-runtimes --query linux | grep PHP | sed "s/ .//g;s/\"//g;s/:/|/g;s/,//g" | head -1)
az webapp create --name $app --resource-group $resource_group --plan $app_service_plan --runtime $app_runtime --deployment-local-git >> $logfile
[[ $? -eq 0 ]] && echo -e "Created webapp ${app}\n" 
az webapp identity assign --name $app --resource-group $resource_group >> $logfile
[[ $? -eq 0 ]] && echo -e "Enabled system-assigned identity for webapp ${app}\n" 
# Configure environment variables
az webapp config appsettings set --resource-group $resource_group --name $app --settings DEPLOYMENT_BRANCH='main' >> $logfile
[[ $? -eq 0 ]] && echo -e "Configured environment variable DEPLOYMENT_BRANCH for webapp ${app}\n" 
az webapp config appsettings set --resource-group $resource_group --name $app --settings DB_SERVER=${db_server}.database.windows.net >> $logfile
[[ $? -eq 0 ]] && echo -e "Configured environment variable DB_SERVER for webapp ${app}\n" 
az webapp config appsettings set --resource-group $resource_group --name $app --settings DB_NAME=$db >> $logfile
[[ $? -eq 0 ]] && echo -e "Configured environment variable DB_NAME for webapp ${app}\n" 
az webapp config appsettings set --resource-group $resource_group --name $app --settings LOCATION=$region_name >> $logfile
[[ $? -eq 0 ]] && echo -e "Configured environment variable LOCATION for webapp ${app}\n" 
echo -e "Sleeping for 10 seconds...Zzzzz\n" 
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
[[ $? -eq 0 ]] && echo -e "Created contained user ${app} in database ${db}\n" 
#
# GIT DEPLOY
#
if [ -d ${script_location}/.git ]; then
   rm -rf ${script_location}/.git
   [[ $? -eq 0 ]] && echo -e "Removed any .git directory to prepare for deployment.\n"
fi
echo -e "Deploying webapp from local git...\n" 
git init
git switch -c main
git remote add azure "https://${webapp_deployment_user}:${git_passwd}@${app}.scm.azurewebsites.net/${app}.git"
git add * 
git commit -m "Initial commit - demo app"
git push azure main