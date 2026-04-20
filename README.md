# ExpenseGuard

ExpenseGuard is an enterprise-grade, B2B SaaS platform designed to automate corporate expense management and prevent financial fraud using Artificial Intelligence. 

The system leverages cloud-native architecture to provide multi-tenant isolation, asynchronous receipt processing via OCR, automated fraud detection, and role-based financial workflows. It is built to handle high-volume enterprise data with strict adherence to security and compliance standards.

## Architecture & Technology Stack

The platform is designed with a service-oriented architecture (SOA), segregating the core API, AI processing engine, and caching layers to ensure horizontal scalability.

### Backend (.NET 9)
- **Framework:** ASP.NET Core Web API
- **ORM:** Entity Framework Core (Code-First)
- **Database:** PostgreSQL (with 3NF normalization and pgcrypto for sensitive data encryption)
- **Authentication:** JWT (JSON Web Tokens) with Refresh Token Rotation
- **Architecture Pattern:** Onion Architecture / Clean Architecture (Domain, Application, Infrastructure, API)
- **Dependency Injection:** Built-in Microsoft.Extensions.DependencyInjection

### AI & Data Processing (Python)
- **Framework:** FastAPI
- **AI Integration:** OpenAI GPT-4 Vision API (for OCR and semantic fraud analysis)
- **Message Broker:** RabbitMQ (for asynchronous background processing of receipts)

### Infrastructure & DevOps
- **Containerization:** Docker & Docker Compose
- **Caching:** Redis (Distributed caching for budgets and temporary tokens)
- **Cloud Storage:** AWS S3 (Secure document and image storage)
- **Billing:** Stripe Integration (Customer and subscription management)
- **Reverse Proxy:** Nginx
- **Observability:** Serilog (Structured logging for Elasticsearch/Kibana integration)

### Frontend
- **Web App:** HTML5, Vanilla JavaScript, CSS3 (Custom Design System, Glassmorphism UI)
- **Mobile App:** Flutter (Cross-platform field application for receipt capture)

## Core Features

- **AI-Powered OCR & Fraud Detection:** Extracts vendor, date, amount, and tax details from receipt images. Analyzes metadata against business rules (e.g., weekend spending, duplicate receipts, abnormal sector averages) to flag potential fraud.
- **Multi-Tenant Architecture:** Strict data isolation using EF Core Global Query Filters. A single deployment serves multiple organizations securely.
- **Role-Based Access Control (RBAC):** Granular permissions for System Admins, Department Managers, Employees, and Finance Auditors.
- **Real-Time Budget Tracking:** Departmental budget limits tracked via Redis. Automatically warns or prevents spending that exceeds allocated monthly budgets.
- **Security Hardening:** Implementation of Rate Limiting, IDOR prevention, SSRF protection via internal network secrets, and Magic Bytes file validation to prevent RCE attacks.
- **Accounting Integration:** Export approved receipts directly to CSV format for seamless integration with ERP systems (SAP, Oracle, etc.).

## Getting Started

### Prerequisites
- Docker and Docker Compose
- .NET 9 SDK
- Python 3.10+
- AWS Account Credentials (S3)
- Stripe Account Credentials
- OpenAI API Key

### Environment Configuration
Create a `.env` file in the root directory and configure the necessary environment variables:

```env
# Database
POSTGRES_DB=expenseguard
POSTGRES_USER=admin
POSTGRES_PASSWORD=your_secure_password

# Authentication & Security
Jwt__Secret=YOUR_LONG_SECURE_JWT_SECRET
InternalApiSecret=SECURE_RANDOM_STRING_FOR_MICROSERVICES

# AI Service
OPENAI_API_KEY=sk-your-openai-api-key

# AWS S3
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_REGION=eu-central-1
S3_BUCKET_NAME=expenseguard-receipts

# Stripe Billing
Stripe__SecretKey=sk_test_your_stripe_key
```

### Running with Docker Compose
The easiest way to run the entire infrastructure locally is via Docker Compose:

```bash
docker-compose up -d --build
```

This command will spin up PostgreSQL, Redis, RabbitMQ, the .NET Core API, and the Python AI Service. The database schema will be automatically initialized via the provided `01_schema.sql` script.

### Accessing the Services
- **Web Interface:** `http://localhost:3000` (or open `index.html` directly)
- **.NET API Swagger:** `http://localhost:8080/swagger`
- **RabbitMQ Management:** `http://localhost:15672` (guest / guest)

## Database Schema Highlights

The PostgreSQL database utilizes advanced features for enterprise security:
- `pgcrypto` extension is used to symmetrically encrypt sensitive financial columns (`amount_encrypted`, `tax_amount_encrypted`) at rest.
- Strict foreign key constraints and `ON DELETE CASCADE` rules ensure referential integrity across the multi-tenant hierarchy (`Tenants` -> `Departments` -> `Users` -> `Receipts`).
- `UUID` generation is handled natively via `gen_random_uuid()` for distributed system compatibility.

## License

This project is proprietary and confidential. Unauthorized copying, distribution, or use of this source code is strictly prohibited.
