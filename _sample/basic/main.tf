terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-sample-basic-renamed"
  location = "Southeast Asia"
  
  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

