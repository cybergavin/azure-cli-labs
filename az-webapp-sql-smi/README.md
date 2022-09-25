# PHP Web Application (Azure App Service) with Azure SQL DB

- A demo of a simple, single-page PHP web application deployed on an Azure App Service Plan and connects to an Azure SQL Database using a system-assigned managed identity (enabled for the web application).
- Creates the following Azure resources:
    - Resource Group for all the required resources
    - A Linux App Service Plan (B2 SKU) to host the web application
    - Web Application (App Service)
    - Logical SQL Server
    - Azure SQL Database
- As Azure PaaS services are used, these services are public by default. However, the Azure SQL Server will deny connectivity by default and allow only Azure services (e.g. App Service webapp) and your public IP to connect.
- All azure resources will be suffixed by a random 5-character string to attempt uniqueness for their names.

---


## Requirements

The following requirements must be met to launch this lab/demo successfully:
- **Linux** (any distro, WSL)
- **Perl** (usually available with any modern Linux distro)
- **sqlcmd** command line utility for connecting to Azure SQL must be installed.  Refer the [Microsoft docs](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools?view=sql-server-ver15). Ensure that *sqlcmd* is in the PATH.
- **Azure CLI** must be installed
- **git** must be installed
- Unrestricted **Internet connectivity** for Azure services
- An Azure AD user with **Contributor** privileges on a subscription or with a custom role that allows the creation of all the required resources (keep it simple with 'Contributor' for a demo).

---

## Usage
- Clone the git repo - `git clone https://github.com/cybergavin/azure-cli-labs.git`
- Switch directory - `cd azure-cli-labs\az-webapp-sql-smi`
- Modify the config `install-demo.cfg` as required. 
- Launch demo - `bash install-demo.sh`


**Launching demo**

![](https://github.com/cybergavin/azure-cli-labs/blob/master/images/01-az-cli-php-sql-demo.PNG) 

**Resources created on Azure**

![](https://github.com/cybergavin/azure-cli-labs/blob/master/images/02-az-cli-php-sql-demo.PNG) 

**PHP Web Application**

![](https://github.com/cybergavin/azure-cli-labs/blob/master/images/03-az-cli-php-sql-demo.PNG) 

---

## Environment Tested
This lab was tested in the following environment:

- WSL 1 (Fedora Remix) on Windows 10 / Rocky Linux 9 VM on VMware Workstation 15 Pro
- Azure AD user with Contributor role on an Azure subscription
- Internet connectivity allowing my workstation to connect to Azure services