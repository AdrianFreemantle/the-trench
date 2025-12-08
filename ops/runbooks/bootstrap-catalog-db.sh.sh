#!/usr/bin/env bash
set -euo pipefail

# --- config: change these to match your env once, then reuse ---

# Postgres flexible server name (from conventions.names.postgres)
PG_SERVER="trench-pg-flex-dev"

# Database and AAD admin user
PG_DB="catalog"
AAD_ADMIN_UPN="adrianfreemantle_gmail.com#EXT#@adrianfreemantlegmail.onmicrosoft.com"

# User Assigned Managed Identity for catalog-api
UAMI_NAME="trench-aks-cluster-dev-catalog-api"
UAMI_RG="rg-trench-aks-dev"

# --- derived values ---

echo "Resolving UAMI objectId for ${UAMI_NAME}..."
UAMI_OBJECT_ID=$(
  az identity show \
    --name "${UAMI_NAME}" \
    --resource-group "${UAMI_RG}" \
    --query "principalId" -o tsv
)

echo "UAMI objectId: ${UAMI_OBJECT_ID}"

echo "Getting AAD access token for Postgres..."
ACCESS_TOKEN=$(
  az account get-access-token \
    --resource-type oss-rdbms \
    --query accessToken -o tsv
)

export PGPASSWORD="${ACCESS_TOKEN}"

echo "Bootstrapping catalog database schema and role..."
psql "host=${PG_SERVER}.postgres.database.azure.com \
      port=5432 \
      dbname=${PG_DB} \
      user=${AAD_ADMIN_UPN} \
      sslmode=require" <<SQL

-- Ensure role exists and is mapped to the current UAMI objectId
CREATE ROLE catalog_api_mi LOGIN;

SECURITY LABEL FOR "pgaadauth"
  ON ROLE "catalog_api_mi"
  IS 'aadauth,oid=${UAMI_OBJECT_ID},type=service';

-- Schema: products table
CREATE TABLE IF NOT EXISTS public.products (
  id          uuid PRIMARY KEY,
  name        text NOT NULL,
  description text,
  price       numeric(10,2) NOT NULL
);

-- Grants
GRANT CONNECT ON DATABASE ${PG_DB} TO catalog_api_mi;
GRANT USAGE ON SCHEMA public TO catalog_api_mi;
GRANT SELECT ON TABLE public.products TO catalog_api_mi;

-- Seed data (idempotent)
INSERT INTO public.products (id, name, description, price)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Coffee Mug', 'Simple mug', 9.99),
  ('22222222-2222-2222-2222-222222222222', 'Tiny T-Shirt', 'TinyShop shirt', 19.99)
ON CONFLICT (id) DO NOTHING;

SQL

echo "Bootstrap complete."