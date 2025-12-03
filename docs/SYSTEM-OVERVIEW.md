# System Overview

TinyShop is a deliberately minimal e-commerce style application built to exercise the AKS platform and supporting Azure infrastructure.  
The focus is the infrastructure, not the business logic.  
The domain is intentionally simple but realistic enough to require HTTP APIs, async messaging, relational and document stores, identity, ingress, observability, and GitOps.

---

## Core Concept

Users can:
1. Browse products  
2. Add items to a cart  
3. Checkout to create an order  
4. View their previous orders  

No payments, no complex inventory logic, no advanced workflows.

---

## Services

### 1. catalog-api (Node.js, Postgres)
Purpose:
- Serve product data.

Responsibilities:
- Store products in Postgres.
- Expose:
  - GET /products
  - GET /products/{id}

Tech:
- Node.js 20
- Express or Fastify
- Postgres Flexible Server
- OTEL for traces/metrics

---

### 2. orders-api (Python, Postgres, Service Bus)
Purpose:
- Manage carts and orders.

Responsibilities:
- Maintain a user’s cart in Postgres.
- On checkout:
  - Read cart items
  - Fetch product details from catalog-api
  - Create an order + order_items
  - Emit `OrderPlaced` to Service Bus
- Expose:
  - GET /cart
  - POST /cart/items
  - POST /checkout
  - GET /orders
  - GET /orders/{id}

Tech:
- Python 3.12
- FastAPI
- Postgres Flexible Server
- Azure Service Bus (producer)
- OTEL

---

### 3. order-worker (Node.js, Cosmos DB, Service Bus)
Purpose:
- Background processing for order events.

Responsibilities:
- Subscribe to `OrderPlaced` messages.
- Insert order event documents into Cosmos DB.
- Simulate an email confirmation by writing a notification document or structured log entry.

Tech:
- Node.js 20
- Azure Cosmos DB (NoSQL)
- Service Bus consumer
- OTEL

---

### 4. shop-ui (Next.js + Entra External ID)
Purpose:
- User interface for the entire flow.

Responsibilities:
- Sign-in via Entra External ID (Google login).
- Show product list.
- Manage cart.
- Trigger checkout.
- Display order history.

Tech:
- Next.js (TypeScript)
- OIDC auth via Entra External ID
- Calls catalog-api and orders-api

---

## Infrastructure Exercise Coverage

This minimal system drives the full infra stack:

- Private AKS cluster
- Hub/spoke VNet + Firewall
- Cloudflare DNS + Tunnel ingress path
- NGINX ingress within cluster
- Entra External ID authentication flow
- Workload Identity for all services
- Key Vault (CSI) for secrets
- Postgres Flexible Server (managed PaaS)
- Azure Cosmos DB (NoSQL document store)
- Azure Service Bus for async messaging
- OTEL, Prometheus, Grafana for observability
- ArgoCD GitOps
- GitHub Actions CI
- Terraform provisioning for all Azure resources

---

## Goal

The goal is not to build a full product but to create a realistic, multi-service application that forces meaningful infrastructure decisions and teaches hands-on AKS and Azure platform skills.