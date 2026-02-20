routes update in the frontend: https://github.com/railsware/js-routes (rails generate js_routes:middleware)
bin/setup 


? add security: https://medium.com/jungletronics/omniauth-with-keycloak-in-rails-8-e777161a2c2b
https://medium.com/@ilya.kovalkov/keycloak-another-way-to-migrate-users-from-your-legacy-system-e62fd29c2e21


https://github.com/SheldonGrant/copilot-subagents
https://github.com/ThibautBaissac/rails_ai_agents

https://github.com/marckohlbrugge/unofficial-37signals-coding-style-guide
https://gist.github.com/marckohlbrugge/d363fb90c89f71bd0c816d24d7642aca


**To Do**:
- add layout (https://inertia-rails.dev/guide/pages#creating-layouts)
  - sidebar
  - loader (after login, before the dashboard)
- form fields mapping
  - updatable in the form builder (creation/after the form is created)
  - example data preview in the form builder 

- ! magic link login ? (remove password? https://railsdesigner.com/saas/magic-links-for-rails-authentication/)
  - https://www.geeksforgeeks.org/ruby/ruby-on-rails-how-to-send-emails/
  - use job
  - Gmail
  - Mailjet 
    rails config: https://gist.github.com/jeffdelara/14a8c0d7c0110c5837981865f8bec4c2
    https://dev.mailjet.com/email/guides/,
    https://dev.mailjet.com/smtp-relay/configuration/ 
  - SendGrid, Mailgun?)

- e2e tests (https://github.com/LynchzDEV/poc_e2e_test)
- basic 0-9 / premium 10-99
- add stripe (revenue share? Stripe connect)
- logo (?)
- quick-kyb.com website (marketing, documentation, support)
- deploy (domain, hosting, kamal, aws, google oauth, stripe, email)
  - https://kamal-deploy.org/

-> ! upload tasks using the crm docs (start by oauth) 

- loader on login
- add to form builder:
  - pre-fetech / loader when opening form builder 

- leaving the client portal (url update in the navigating browser) got 
"
Content-Security-Policy: The page’s settings blocked an inline script (script-src-elem) from being executed because it violates the following directive: “script-src 'self' https: 'unsafe-eval' http://localhost:3036”. Consider using a hash ('sha256-ieoeWczDHkReVBsRBqaal5AFMlBtNjMzgwKvLqi/tSU=') or a nonce.
"

- tests the "buttons" in the form


- clients
  rspec ./spec/requests/clients_spec.rb:182 # Clients API GET /clients/:id/export returns 404 for another user's client export
  rspec ./spec/requests/clients_spec.rb:39 # Clients API GET /clients returns empty props when unauthenticated
  rspec ./spec/requests/clients_spec.rb:60 # Clients API GET /clients/:id returns 404 for a client not owned by current_user
  rspec ./spec/requests/clients_spec.rb:110 # Clients API GET /clients/:id/edit returns 404 when editing another user's client



- login use omniauth (https://github.com/omniauth/omniauth/wiki)
  - https://useful.codes/configuring-environment-variables-and-secrets-in-ruby-on-rails/
  - google
  - ?
  - normal auth / error handling ( do the e2e tests)




## Stripe - use bolt
- use account
- use bolt if leftover credits
- 1 mcp server (roo code)

- integration tests: https://guides.rubyonrails.org/testing.html#integration-testing

- e2e tests for:
  - The small test/ directory that exists appears to be leftover scaffold from Rails generators (identity controllers). The real test coverage is all in spec/.
  - https://github.com/teamcapybara/capybara
  - https://reintech.io/blog/capybara-rails-end-to-end-testing-best-practices
  - auth
  - form creation (all fields) / update / deletion
  - client creation
  - client form access (on portal) / partial save / submission / expiration after submission
  - form response submission


## deploy
- where
  - from kamal doc
  - EU hosting container+db (OVH? Hetzner? Scaleway? Kamatera?)
  - domain?
- use kamal
  https://alec-c4.com/posts/2025-04-02-kamal
  OVH: https://medium.com/@gregoire.renaldo/how-to-deploy-a-basic-rails-8-app-on-ovh-with-kamal-a57b32e326a5


- remove the inertia example
- layout -> https://inertia-rails.dev/guide/pages#creating-layouts / persistent layout

- the file storage for the uploaded files (aws s3 / local fs / other)
  - https://pragmaticstudio.com/tutorials/using-active-storage-in-rails -> info on validate / transform image / s3 deploy
  - how to handle the bucket directories?
    - testing
    - production bucket



## CRM - API References

Goal:
- integrate with 3rd party CRM APIs (Salesforce, HubSpot, Zoho) to export client and form data for onboarding workflows.
- read if exist (find by website for account/customer object OR email address for individual) / write data to the crm (client + form data + files) in the right CRM fields/objects
- create client in the crm if he doesn't exist
- create clients in the crm from the app / from the crm to the app


UX (incomplete):
- connect CRM account via Oauth flow
- create/update a form
- create/import a client 
- link client to form
- share the form with the client (client portal access)
- submit the form (with file uploads)
- the data is sent to the CRM (client + form data + files) in the right CRM fields/objects


Left to decide:
-> where do you link the form fields and the crm fields to export to?
  - default mapping for each crm?
  - make the connection in the form builder? use ai?
-> where to write the information?
  - the location where the form data should go is different for each crm


/speckit.specify Let's integrate csv data export to 3rd party data via their REST API. It should work for salesforce, hubspot and zoho.

! **CRM**: 
  - to 3 articles on how to integrate with the CRM APIs (hubspot, zoho, salesforce) with rails / inertia
  - retrieve the code from the past commits, use ai to summarize the mandatory changes, bug solving...
- ! hide the crm integration behind a service layer (e.g. CrmService) that can be extended to support multiple CRMs and **abstract** away the differences in their APIs.


next step:
- create the information (in the form) linked to the client in the app -> export (client + info) to the crm (see **export overview**)




### Hubspot CRM
docs/hubspot.md

### Zoho CRM
docs/zoho.md

### Salesforce
docs/salesforce.md


- retrieve lost password / 2FA OR passwordless login (magic link) ?
  - from admin dashboard 
  - you need the mailer setup
  - Two factor authentication + recovery codes (--two-factor)
  
- admin dashboard
  - list users
  - delete user
  - reset user password


## Do Basic + tier
- fetch the data from the api e-justice.europa.eu
  - https://webgate.ec.europa.eu/e-justice/searchBris.do -> doesn't work
  - https://openbris.eu/ -> paid service (> 50 requests / month)
- with CRM ?

## Useful links for company search in EU
https://webgate.ec.europa.eu/e-justice/489/EN/business_registers__search_for_a_company_in_the_eu?EUROPEAN_UNION&action=maximize&idSubpage=1&member=1

https://www.globaldatabase.com/how-to-search-for-company-information-in-the-eu-the-complete-guide-to-european-company-registers

UBO
https://e-justice.europa.eu/topics/registers-business-insolvency-land/beneficial-ownership-registers-interconnection-system-boris/general-information-finding-beneficial-owners_en




Password Reveal

Client: inactive form

Form: fghjc
Access URL
/client_portal/login/NkU39VvV13odajU7JtaM3XN7
One-time password (showed once)
NrSQqmq76j5M


Password Reveal

Client: updated form

Form: fghjc
Access URL
/client_portal/login/QV3JaoS6t9kbN2scs1ERtxC7
One-time password (showed once)
kqiAzeuNxMB7

Password Reveal

Client: validated form

Form: zahdazjlf
Access URL
/client_portal/login/cXow5GTtoYgVz84CTm1Kh5ki
One-time password (showed once)
s72CNeb76dDc


The client 
Password Reveal

Client: other test

Form: first (second revoked?)
Access URL
/client_portal/login/EKoomB7JsKgYzCh41uz7S3iC
One-time password (showed once)
mgXma6DWoeMb

Password Reveal


Summary

Ran: 251 examples
Failures: 50 examples (listed below by group)
Primary root causes observed: authentication/session cookie handling in request/system specs; stricter User password validation; RuboCop style failures; some missing/stubbed methods and redirects from auth flows.
Failing groups (top-level)

Authentication / cookies in request specs:

Many request specs fail with: NoMethodError: undefined method 'signed' for an instance of Rack::Test::CookieJar
Affected tests: clients_spec.rb (many examples), form_responses_spec.rb (redirects to login), and multiple others that depend on setting cookies.signed[:session_token].
Likely fix: in request specs use a request-level cookie (set Cookie header) or helper that works with Rack::Test; or adjust tests to use controller specs where cookies.signed exists. Alternatively, make test helper set a signed cookie via Rails.application.message_verifier(:signed_cookie).generate(...) or use rack_test helpers to set signed cookies.
Password validation failures (User creation):

Many specs fail with: ActiveRecord::RecordInvalid: Validation failed: Password is too short (minimum is 12 characters)
Affected tests: many service/spec files that create users with password: 'password'.
Likely fix: update test factories/specs to use a password at least 12 chars (e.g. password123456) or relax User model validation if intended.
Client portal session/redirect logic:

Failing examples: form_responses_spec.rb (validate flow expects redirect to confirmation but got redirect to login; expired flow returns 410 instead of redirect)
Likely fix: ensure ClientPortal::SessionService.set_cookie sets cookies usable in test env (non-secure in tests) and that ClientPortal::BaseController#authenticate_client_form! path/response matches spec expectations. I attempted to make secure: Rails.env.production? but tests still need cookie-compatibility; update SessionService and re-run tests.
Capybara/system tests (UI flows):

Failures: many system specs (clients_create, clients_dashboard, clients_show, forms features) where expected UI elements are missing or JSON endpoints return HTML.
Root cause: often the app redirected to sign-in or returned HTML login page (see JSON parse errors). Fixing authentication/session cookie and ensuring test sign-in helpers produce valid sessions should resolve many of these.
RuboCop/style check:

rubocop_spec.rb failing due to many style offenses (215 offenses reported).
Fix: run rubocop -A or apply targeted autocorrections and update .rubocop.yml for new cops.
FormService / method stubs:

One failure: Form does not implement has_submissions_for_field? expected by a test that stubs it; adjust implementation or tests to stub method correctly.
Affected specs: form_service_update_spec.rb and related service specs.
Specific failing examples (representative; full list is long)

spec/controllers/clients_controller_spec.rb: index/show/edit expectations (IDs nil / wrong counts) — symptom of auth/cookie issues.
spec/requests/client_portal/form_responses_spec.rb: validation redirect to confirmation vs login; expired flow expecting a redirect but getting 410.
spec/requests/form_preview_spec.rb: JSON parsing error (HTML login page returned).
spec/features/* and spec/system/*: Capybara element not found (Add client, New Form, Edit link missing).
spec/services/form_service_spec.rb: multiple failures (user creation password validation).
spec/rubocop_spec.rb: style offenses.
Files touched during this work

session_service.rb — cookie secure behavior is relevant to tests.
client.rb — added form_status enum.
client_serializer.rb — exposes status.
client_form.rb — updates client status on save.
client_invitation_service.rb — updates client status on link.
Frontend pages updated: Show.svelte, Dashboard.svelte.
Recommended next steps (prioritized)

Fix test user creation (fastest win): update factories/specs to create users with password length >= 12 (e.g. password123456). This will unblock many service/spec failures.
Fix request-spec cookie handling:
Replace cookies.signed[:session_token] = session.id in request specs with a request-compatible approach (set Cookie header or use helper that signs cookie for Rack::Test).
Alternatively, adjust ClientPortal::SessionService in test env so set_cookie writes a cookie format test suite expects.
Apply rubocop autocorrections:
Run bundle exec rubocop -A and re-run rubocop_spec.rb.
Re-run the failing request spec(s) for client_portal and the system specs after (1) and (2) to confirm progress.
Address remaining service-specific failures (e.g., implement/stub Form.has_submissions_for_field?) once authentication and factories are fixed.
If you want I can:

Apply fix (1) now (update factories/specs to use longer password) and re-run the test subset.
Apply fix (2) to SessionService and show the patch, then re-run the failing request specs.
Which should I do next?



Below is the requested Markdown table (27 EU member states) with official register/API links and pricing notes.

| Country | API / Register URL | API / Docs (endpoint) | Pricing / Notes |
|---------|-------------------|----------------------|-----------------|
| Austria | https://www.justiz.gv.at/service/datenbanken/firmenbuch/firmenbuchabfrage.2c9484852308c2a601240b693e1c0860.de.html | JustizOnline Firmenbuch (web queries / extracts) | Paid certified extracts; web queries often paid |
| Belgium | https://kbopub.economie.fgov.be/kbopub/ | KBO Public Search (web UI) | Public search free; commercial access/feeds via gov channels (fees vary) |
| Bulgaria | https://portal.registryagency.bg/home-cr | Commercial Register portal / e‑services | Certified extracts / e‑services typically paid |
| Croatia | https://sudreg.pravosudje.hr | Sudreg public search | Basic search free; certified documents paid |
| Cyprus | https://www.mcit.gov.cy/en/registrar_of_companies | Registrar portal | Certified extracts / filings usually paid; no unified open REST API |
| Czechia | https://wwwinfo.mfcr.cz/ares/ares_xml.htm | ARES XML web service | Open / free |
| Denmark | https://datacvr.virk.dk/data/ | CVR data endpoints (open data) | Core data open/free; some limits or commercial feeds |
| Estonia | https://ettevotjaportaal.rik.ee/ | e‑Business Register portal (RIK) | Many lookups free; certified extracts/restricted via X‑Road |
| Finland | https://avoindata.prh.fi/ | PRH / YTJ Open Data APIs (Swagger) | Open / free |
| France | SIRENE: https://entreprise.data.gouv.fr/api_doc — Infogreffe: https://www.infogreffe.fr/ | SIRENE API (open); Infogreffe commercial services | SIRENE free (API key/registration); Infogreffe paid for certified docs |
| Germany | https://www.unternehmensregister.de/ | Unternehmensregister / Bundesanzeiger | Document extracts often paid; metadata/search sometimes free/commercial |
| Greece | https://www.businessregistry.gr/ | GEMI / Business Registry portal | Public search varying; certified extracts usually paid |
| Hungary | https://www.e-cegjegyzek.hu/ | e‑Cégjegyzék portal | Basic info free/indicative; certified extracts paid |
| Ireland | https://core.cro.ie/ / https://cro.ie/ | CRO / CORE search | Some data free; downloads/certified docs paid |
| Italy | https://www.registroimprese.it/ | Registro Imprese / InfoCamere APIs | API access typically paid/subscription (InfoCamere) |
| Latvia | https://www.ur.gov.lv/en/ | Register of Enterprises / open data | Basic open data free; certified extracts paid |
| Lithuania | https://www.registrucentras.lt/en/ | Centre of Registers / e‑services | Certified extracts / many services paid |
| Luxembourg | https://rcsluxembourg.public.lu/en.html | RCS Luxembourg portal | Extracts/documents typically paid; limited metadata public |
| Malta | https://mbr.mt | Malta Business Registry (MBR) portal | Filings/extracts usually paid |
| Netherlands | https://developers.kvk.nl/documentation | KVK Developer APIs (docs) | Subscription + per‑query fees; free sandbox/testing |
| Poland | https://prs.ms.gov.pl/krs (ekrs) | KRS / REGON / CEIDG portals | Many lookups free; certified extracts/advanced APIs may require registration/fees |
| Portugal | https://eportugal.gov.pt/ / https://www.portaldaempresa.pt/ | Portal da Empresa / ePortugal services | Some services free; certified extracts paid |
| Romania | https://portal.onrc.ro/ (redirects to myportal.onrc.ro) | ONRC / MyPortal | Certified extracts and many services paid |
| Slovakia | https://www.orsr.sk/ | ORSR public search & e‑services | Basic search free; certified extracts paid |
| Slovenia | https://www.ajpes.si/ | AJPES / Poslovni register | Some open data; many services paid/subscription |
| Spain | https://www.registradores.org/ / Registro Mercantil | Colegio de Registradores / Registro Mercantil portals | Many APIs/services commercial/paid |
| Sweden | https://www.bolagsverket.se/en/ | Bolagsverket e‑services / APIs | Document/extract fees apply; some APIs available (paid/subscription) |
Notes:

BRIS itself does not expose a single public REST API; it interconnects national registers and provides the e‑Justice BRIS search UI for humans: https://webgate.ec.europa.eu/e-justice/initialBris.do?plang=en
For programmatic cross‑country access consider: OpenCorporates API (https://opencorporates.com/info/api) — commercial tiers available and broad coverage.



**export overview**

Steps
1. Extract and normalize form data into two levels: business (entity) and person (individuals/contacts).  
2. Map entity -> CRM Account/Company, person -> Contact, onboarding status -> Deal/Opportunity (optional).  
3. Push documents and proofs to a Documents/Files store or CRM custom object, link to Account/Contact.  
4. Record verification results, screening metadata, and audit trail as structured fields + timeline events.

Canonical mapping (use this model across CRMs)
- `Company/Account` (business-level): legal name, trade name, registration number, incorporation date, country, registered address, business address, tax ID/VAT, industry (NAICS/SIC), website, legal entity type, status.  
- `Contact` (person-level): full name, role/title, email, phone, DOB, nationality, address, government ID type & number (store hashed/encrypted), ID expiry, email/phone consent flags, ownership percentage, signatory flag.  
- `KYC/KYB Profile` (custom object/module): verification status (pending/verified/rejected), verification provider ID, verification timestamp, verification operator, risk score, AML/sanctions screening result, last review date, next review due, source of data (form id).  
- `Documents` (related records or files): document type (passport, certificate of incorporation, proof of address), upload date, storage link, checksum, expiration (if any), verifier notes.  
- `Deal/Onboarding Pipeline`: onboarding stage, expected close/onboarding completion date, assigned owner, priority, linked Account and Contact(s).  
- `Activities/Timeline`: events for submission, document upload, verification steps, manual reviews, compliance decisions, and exported-to-CRM timestamp.

HubSpot (recommended) **hubspot data mapping**
- **`Company`**: legal name, domain, registration number, tax ID, incorporation date, industry, main address, status.  
- **`Contact`**: name, email, phone, DOB, nationality, role, owner flag, UBO/beneficial-owner links.  
- **`Deal`**: onboarding pipeline stage, estimated onboarding completion, assigned rep.  
- **Custom objects**: create `KYC Profile` and `KYC Document` objects for structured verification records and file metadata.  
- **Files & timeline**: store docs in HubSpot Files or external blob store and link; create timeline events for verification actions.  
- **Properties**: add `verification_status`, `risk_score`, `screening_result`, `verification_provider_id`, `consent_timestamp`.

Salesforce (recommended)
- **`Account`**: map company info to `Account` fields (use custom fields for registration/tax numbers).  
- **`Contact`**: personal identity fields, contact role lookup to `Account`.  
- **`Opportunity`**: use an `Onboarding` opportunity record or a custom `Onboarding__c` object for pipeline logic.  
- **Custom objects**: add `KYC__c` (master-detail to Account) and `KYC_Document__c` (files metadata) with lookups to Account/Contact.  
- **Files**: upload proofs to `Files` (ContentVersion) and relate via `ContentDocumentLink`.  
- **Security**: use field-level encryption (Shield) for sensitive IDs and permission sets to restrict access.  
- **Fields**: `Verification_Status__c`, `Risk_Score__c`, `Screening_Result__c`, `Verification_Provider_ID__c`, `Last_Reviewed__c`.

Zoho CRM (recommended)
- **`Accounts`**: company-level mapping for KYB fields.  
- **`Contacts`**: map individuals and link UBOs via related lists.  
- **`Deals`**: use for onboarding pipeline.  
- **Custom Modules**: create `KYC_Profile` and `KYC_Documents` modules and link them to Accounts/Contacts.  
- **Attachments**: store documents in Zoho attachments or an external secure file store and save links in the document module.  
- **Fields**: `Verification Status`, `Risk Score`, `Screening Results`, `Verification Provider Ref`, `Consent Timestamp`.

Minimal required fields (for compliance + operations)
- Business: legal name, registration number, country, registered address, tax ID.  
- Primary person: full name, role, contact email, phone, government ID type & hash/encrypted value, ownership %.  
- Verification: verification status, verifier id/provider, timestamp, screening result, risk score.  
- Documents: document type, storage link, upload timestamp, checksum.

Documents & attachments
- Prefer storing large binaries in secure blob storage (S3, GCS) and save immutable links + checksum in CRM document records.  
- Always keep original submission JSON as raw evidence (attached to the KYC Profile).  
- Maintain document expiry and automated reminders (next review due).

Security, privacy & audit (non-optional)
- Encrypt sensitive fields at rest and restrict read access via roles/permission sets.  
- Capture user consent (timestamp, IP, form version) and retention policy fields.  
- Log who exported/uploaded the data and when (audit trail).  
- Store PII minimised: consider hashing ID numbers and keeping plaintext only where required and encrypted.  
- Keep screening/third-party provider IDs to enable re-checks and reconciliation.

Operational notes / integration tips
- Use CRM IDs in your onboarding system so re-exports update existing records (upsert by registration number, tax ID, or email + domain matching).  
- For batch exports, include mapping version and form version to allow future migrations.  
- Add a `raw_form_json` field on the KYC record for forensic traceability.  
- Automate status transitions in CRM (webhooks/workflows) once verification completes.

If you want, I can:
- produce a concrete JSON->HubSpot/ Salesforce/Zoho mapping file for your current form, or  
- sketch the custom object schemas and example API payloads for one CRM. Which would you prefer?

**export overview**
