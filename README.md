# QuickStart .NET agent deployed using azd

This project uses [Azure Developer command-line (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/) tools to simplify creating the [QuickStart sample .NET agent](https://github.com/microsoft/Agents/tree/main/samples/dotnet/quickstart).

## Prerequisites

+ [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local?pivots=programming-language-typescript#install-the-azure-functions-core-tools)
+ [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)

## Permissions required to provision the resources in Azure

The account running `azd` must have at least the following roles to successfully provision the resources:

+ Azure role [`Contributor`](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/privileged#contributor): To create all the resources needed
+ Azure role [`Role Based Access Control Administrator`](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator): To assign roles to the managed identities created.

## How-to use this project

1. Initialize the project:

    ```shell
    mkdir "azd-copilot-agent-quickstart-dotnet" && cd "azd-copilot-agent-quickstart-dotnet"
    azd init --template "Yvand/azd-copilot-agent-quickstart-dotnet"
    ```

1. Review the file `infra/main.parameters.json` to customize the parameters used for provisioning the resources in Azure. Review [this article](https://learn.microsoft.com/azure/developer/azure-developer-cli/manage-environment-variables) to manage the azd's environment variables.

1. Provision the resources in Azure and deploy the function app package by running command `azd up`.


