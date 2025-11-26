# Conventions Module

This module centralizes naming and tagging rules for The Trench.

Inputs:
- environment: dev, test, prod
- owner: owner tag value (default: adrian)
- cost_center: cost-center tag value (default: aks-lab)

Outputs:
- resource_groups: map of standard resource group names
- names: map of core resource names (VNets, AKS, ACR, Key Vault, Postgres, Service Bus, DNS zones)
- tags: default tag map applied to all resources
