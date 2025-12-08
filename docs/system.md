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

## Domain Model

The domain is intentionally small. The goal is to provide realistic data flows and failure points, not rich business features.

- **User**
  - Logical application user authenticated via Entra External ID.
  - Identified by an external identity subject (OIDC sub / object id) rather than a local password.

- **Product**
  - Basic catalog item: `id`, `name`, `description`, `price` (and optionally a simple `stock` field for labs).
  - Owned by `catalog-api` and stored in the Postgres `catalog` database.

- **Cart** / **CartItem**
  - Per-user shopping cart containing selected products and quantities.
  - Owned by `orders-api` and stored in the Postgres `orders` database.

- **Order** / **OrderItem**
  - Snapshot of what the user bought at checkout time.
  - Contains a stable total price and copy of product details needed for history.
  - Owned by `orders-api` and stored in the Postgres `orders` database.

- **OrderEvent** (timeline / audit document)
  - Represents derived events such as `OrderPlaced`, `OrderConfirmed`, or synthetic notifications.
  - Owned by `order-worker` and stored in Cosmos DB as documents to enable flexible querying and lab scenarios.

Relationships are deliberately simple:

- A `User` has one active `Cart` and many `Orders`.
- An `Order` has many `OrderItems`.
- An `Order` can have many `OrderEvents` in Cosmos DB.

---

## Key Flows

These flows are chosen to exercise HTTP APIs, Postgres, Service Bus, Cosmos DB, identity, ingress, observability, and GitOps without adding unnecessary business complexity.

### 1. Browse products

- `shop-ui` calls `catalog-api` (`GET /products`, `GET /products/{id}`).
- `catalog-api` reads from the Postgres `catalog` database.
- No state is written; this flow is primarily for ingress, caching, and observability exercises.

### 2. Manage cart

- Authenticated user interacts with `shop-ui`.
- `shop-ui` calls `orders-api`:
  - `GET /cart` to retrieve current cart.
  - `POST /cart/items` to add/update/remove items.
- `orders-api` persists the cart in the Postgres `orders` database keyed by the external user id.
- This flow is used to explore CRUD patterns, Postgres connectivity, and failure modes (e.g. DB unavailable, network policies).

### 3. Checkout and order creation

- `shop-ui` calls `orders-api` `POST /checkout`.
- `orders-api`:
  - Reads the user cart from Postgres.
  - Calls `catalog-api` to resolve product details/prices.
  - Writes an `Order` + `OrderItems` to the Postgres `orders` database.
  - Publishes an `OrderPlaced` message to the Service Bus `orders` queue.
- This flow exercises synchronous HTTP between services, Postgres writes, and Service Bus producer behavior.

### 4. Order event processing (worker)

- `order-worker` listens to the Service Bus `orders` queue.
- For each `OrderPlaced` message it:
  - Parses the payload and writes an `OrderEvent` document into Cosmos DB.
  - Optionally emits a synthetic "email sent" event or structured log for observability labs.
- This flow provides hooks for failure labs (message dead-lettering, poison messages, transient failures, retries, and scaling the worker).

### 5. View order history

- `shop-ui` calls `orders-api` (`GET /orders`, `GET /orders/{id}`).
- `orders-api` primarily reads from the Postgres `orders` database.
- Optionally, `orders-api` can enrich responses with data from Cosmos DB `OrderEvent` documents to show a coarse timeline.
- This flow is used to demonstrate read patterns, indexing, and failure cases where either Postgres or Cosmos is degraded.

---

## Infrastructure Exercise Coverage

This minimal system drives the full infra stack:

- Private AKS cluster
- System/user node pool separation planned but deferred until after initial platform stabilisation.
- Hub/spoke VNet + Firewall
- Cloudflare DNS + Tunnel ingress path
- NGINX ingress within cluster
- Entra External ID authentication flow
- Workload Identity implemented for one representative workload initially; full adoption deferred to future phase.
- Key Vault (CSI) for secrets
- Postgres Flexible Server (managed PaaS)
- Azure Cosmos DB (NoSQL document store)
- Azure Service Bus for async messaging
- OTEL, Prometheus, Grafana for observability
- Initial platform implements minimal viable telemetry pipelines; extended exporters and multi-backend routing deferred.
- ArgoCD GitOps
- GitHub Actions CI
- Terraform provisioning for all Azure resources

---

## Goal

The goal is not to build a full product but to create a realistic, multi-service application that forces meaningful infrastructure decisions and teaches hands-on AKS and Azure platform skills.

---

## Future Enhancements

- Terraform module refactor
- Backend migration
- Full Workload Identity rollout
- Multi-environment GitOps
- Detailed firewall/egress policy set
- Node pool optimisation and autoscaling tuning