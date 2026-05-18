# ⚡ Quick KYB

> Streamlined merchant onboarding for payment providers.

Quick KYB accelerates the merchant onboarding process for payment providers. Traditionally, collecting "Know Your Business" (KYB) data involves fragmented PDFs and manual data entry. Quick KYB transforms this experience by allowing providers to generate personalized digital forms, automate data collection, and sync validated merchant profiles directly into their CRM. It bridges the gap between client document submission and back-office data readiness.

[About](#-about) • [Key Features](#-key-features) • [Tech Stack](#-tech-stack) • [Getting Started](#-getting-started) • [Architecture](#-architecture) • [Documentation](#-documentation)

---

## 📖 About

Quick KYB is designed for payment providers who need to onboard merchants quickly and accurately. It offers a seamless transition from legacy PDF-based processes to digital, CRM-integrated workflows.

## ✨ Key Features

*   **📄 PDF-to-Form Engine**: Instantly convert existing onboarding PDFs into interactive, web-native forms.
*   **🔗 Smart CRM Linkage**: Premium users can connect HubSpot directly; our engine automatically maps form responses to custom CRM fields.
*   **📦 Flexible Data Export**: Export merchant data in JSON/CSV formats, ready for any internal ingestion pipeline.
*   **⚡ Modern Frontend**: Powered by **Svelte 5** and **Inertia.js** for a reactive, single-page application experience within a Rails environment.
*   **🏢 Client Portal**: A dedicated space for merchants to securely fill, save, and submit their onboarding progress.

## 🛠 Tech Stack

*   **Backend:** [Ruby on Rails 8.1](https://rubyonrails.org/) (Solid Cable, Solid Cache, Solid Queue)
*   **Frontend:** [Svelte 5](https://svelte.dev/), [Inertia.js](https://inertiajs.com/), [Vite](https://vitejs.dev/), [Tailwind CSS](https://tailwindcss.com/)
*   **Database:** PostgreSQL
*   **Integrations:** HubSpot API, Stripe

## 🚀 Getting Started

### Prerequisites

- **Ruby**: 3.4.8 (see `.ruby-version`)
- **Rails**: 8.1+
- **Node.js**: 20+ (for Vite and Svelte 5)
- **PostgreSQL**

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-repo/quick-kyb.git
   cd quick-kyb
   ```

2. **Setup dependencies:**
   ```bash
   bundle install
   npm install
   ```

3. **Prepare the database:**
   ```bash
   bin/rails db:prepare db:seed
   ```

4. **Run the development server:**
   ```bash
   bin/setup
   ```
   Visit [http://localhost:3100](http://localhost:3100) to see the app in action.

## 📁 Architecture

The project follows a hybrid monolith approach using **Inertia.js** to bridge Rails and Svelte.

- `app/frontend/`: Contains all Svelte 5 components, pages, and frontend logic.
- `app/models/`: ActiveRecord models for merchants, forms, and CRM mappings.
- `app/services/`: Core logic for CRM synchronization and PDF processing.
- `app/controllers/`: Rails controllers handling routing and Inertia rendering.

## 📚 Documentation

Detailed documentation can be found in the [docs/](docs/) directory:

- [Architecture Overview](docs/ARCHITECTURE.md)
- [HubSpot Integration](docs/hubspot.md)
- [KYB/KYC Flow](docs/kyb-kyc.md)
- [Frontend Guide](docs/frontend/)

## 🗺 Roadmap

- [ ] Salesforce & Zoho CRM Integrations
- [X] AI-powered field extraction from uploaded documents
- [ ] Fully automatic merchant onboarding

## 📄 License

Private repository. All rights reserved.