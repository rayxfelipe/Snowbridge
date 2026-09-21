# Azure Deployment Plan

> **Status:** Validated

Generated: 2026-09-21

---

## 1. Project Overview

**Goal:** Deploy the committed Snowbridge business UI to the existing Azure Container App so the public root endpoint serves the governed customer workflow while `/docs` remains available.

**Path:** Modify Existing

---

## 2. Requirements

| Attribute | Value |
|-----------|-------|
| Classification | Development / Hackathon Demo |
| Scale | Small |
| Budget | Cost-Optimized |
| Subscription | `rayfelipe-fdpo` (`499bc654-f84c-46c2-952c-b30be508f78c`) |
| Location | `eastus2` |

---

## 3. Components Detected

| Component | Type | Technology | Path |
|-----------|------|------------|------|
| Business UI and API | Frontend / API | FastAPI, HTML, CSS, JavaScript | `src/snowbridge` |
| Container image | Deployment artifact | Python 3.13, Docker | `Dockerfile` |
| Azure infrastructure | Infrastructure | Bicep | `infra` |

---

## 4. Recipe Selection

**Selected:** Bicep

**Rationale:** Update the already-provisioned Container App through the repository's existing subscription-scope Bicep deployment and an immutable ACR image reference.

---

## 5. Architecture

**Stack:** Containers

### Service Mapping

| Component | Azure Service | SKU |
|-----------|---------------|-----|
| Snowbridge API and UI | Azure Container Apps | Consumption |
| Container image | Azure Container Registry | Basic |
| AI planner | Microsoft Foundry | `gpt-4.1-mini`, GlobalStandard |

### Supporting Services

| Service | Purpose |
|---------|---------|
| Log Analytics | Centralized logging |
| Application Insights | Monitoring and telemetry |
| Key Vault | Secrets management |
| Managed Identity | ACR, Key Vault, and Foundry authentication |

---

## 6. Provisioning Limit Checklist

This update deploys a new image revision to existing resources and provisions no net-new Azure resource instances.

| Resource Type | Number to Deploy | Total After Deployment | Limit/Quota | Notes |
|---------------|------------------|------------------------|-------------|-------|
| `Microsoft.App/managedEnvironments` | 0 | 1 | 50 | `ManagedEnvironmentCount`; quota CLI usage 1, limit 50 |
| `Microsoft.App/containerApps` | 0 | 1 | No quota increase required | Image-only revision update |
| `Microsoft.ContainerRegistry/registries` | 0 | 1 | No quota increase required | Existing Basic registry; remote image build only |
| `Microsoft.CognitiveServices/accounts/deployments` | 0 | 1 | No quota increase required | Existing model capacity is unchanged |

**Status:** All required capacity is available. This update creates no new resource instances.

---

## 7. Execution Checklist

### Phase 1: Planning
- [x] Analyze workspace
- [x] Gather requirements
- [x] Confirm subscription and location from the existing deployment context
- [x] Prepare resource inventory
- [x] Fetch quotas and validate capacity
- [x] Scan codebase
- [x] Select recipe
- [x] Plan architecture
- [x] User approved this plan through the explicit request to deploy the UI

### Phase 2: Execution
- [x] Research components and load Azure AI application best practices
- [x] Infrastructure files already exist
- [x] Application configuration already exists
- [x] Dockerfile already exists
- [x] Verify application tests, lint, and Bicep compilation
- [x] Update plan status to Ready for Validation

### Phase 3: Validation
- [x] Invoke azure-validate skill
- [x] All validation checks pass
	- [x] Core validation: Azure CLI, authentication, Bicep build, ARM validation, and what-if
	- [x] Bicep linting reviewed; schema-version warnings are non-blocking
	- [x] Azure policies reviewed; ARM validation passed under assigned policies
- [x] Update plan status to Validated
- [x] Record validation proof below

### Phase 4: Deployment
- [ ] Invoke azure-deploy skill
- [ ] Deployment successful
- [ ] Verify `/`, `/docs`, `/health`, AI plan, and confirmed execution
- [ ] Update plan status to Deployed

---

## 7. Validation Proof

| Check | Command Run | Result | Timestamp |
|-------|-------------|--------|-----------|
| Application tests | `.venv/Scripts/python.exe -m pytest tests/test_api.py -q` | Pass: 14 tests | 2026-09-21 |
| Python lint | `.venv/Scripts/python.exe -m ruff check src tests` | Pass | 2026-09-21 |
| Core Bicep validation | `validate-deployment.ps1 -Scope sub -Location eastus2 ...` | Pass: CLI, auth, build, ARM validate, what-if | 2026-09-21 |
| Deployment impact | `az deployment sub what-if ... --result-format ResourceIdOnly` | Pass: no deletes; in-place deploy plus deterministic role assignment | 2026-09-21 |
| Bicep lint | `az bicep lint --file infra/main.bicep` | Pass with non-blocking schema/linter warnings | 2026-09-21 |
| Azure policy | `policy_assignment_list` and ARM validation | Pass: no blocking policy violation | 2026-09-21 |
| Image build | `az acr build ... snowbridge:git-19d40df-fix1` | Pass: digest `sha256:a8e81d4d...` | 2026-09-21 |
| Static RBAC | Review `role-assignments.bicep` and `foundry-role-assignment.bicep` | Pass: resource-scoped AcrPull, Key Vault Secrets User, Cognitive Services OpenAI User | 2026-09-21 |
| Error resolution | Removed redundant Hatch `force-include`; reran ACR build, tests, and lint | Pass: duplicate wheel entry resolved | 2026-09-21 |

**Validated by:** azure-validate skill
**Validation timestamp:** 2026-09-21

### Role Assignment Verification

- Status: Verified
- Identity: Container App system-assigned managed identity
- Roles: `AcrPull`, `Key Vault Secrets User`, `Cognitive Services OpenAI User`
- Scopes: Individual ACR, Key Vault, and Foundry account resources
- Deployment requirement: Override `deployerObjectId` with the signed-in user's object ID.

---

## 8. Files to Generate

| File | Purpose | Status |
|------|---------|--------|
| `.azure/deployment-plan.md` | Deployment source of truth | Complete |
| `infra/main.bicep` | Existing subscription deployment | Existing |
| `Dockerfile` | Existing application image | Existing |

---

## 9. Next Steps

> Current: Validated; ready for deployment

1. Verify subscription context, existing resources, and update capacity.
2. Validate application and Bicep.
3. Build an immutable image and deploy it through Bicep.
4. Verify all public endpoints.
