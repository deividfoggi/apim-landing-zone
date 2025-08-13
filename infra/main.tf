// Main Terraform configuration for APIM Landing Zone

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "dc22d6d8-0495-4653-a69b-edfe16840f8e"
}
