# azure-sys-check-ps

PowerShell script to monitor Linux disk space, memory and CPU usage on all hosts within an Azure subscription and display results as a table.

## Exercise

> Goal: Easily monitor core services onsite (e.g., check they haven’t failed or errored).
>
> Write a PowerShell script to check Linux disk space, memory, and CPU usage across all hosts in an Azure subscription. Display results as a table. Use judgement for additional useful features. Note any potential next steps for further development.

## Conclusion

The script works. Setting up the Azure environment took more effort than writing the monitoring script.

Interesting exercise, but PowerShell is not ideal for Linux. Modern SRE practice would use an OpenTelemetry stack such as **LGTM**:

* **Loki** – logs
* **Grafana** – visualisation
* **Tempo** – traces
* **Mimir** – metrics (scalable Prometheus)

---

## Exercise Notes

### Core Issues Encountered

**Linux disk usage**

* Azure metrics don’t capture Linux disk usage reliably. Use shell `df` commands instead.

**Linting**

* PSAvoidUsingConvertToSecureStringWithPlainText → use a different auth mechanism.
* DevSkim rules to fix: DS162092, DS440020, DS440001, DS440000

**Container apps**

* Need more research on usable metrics.

---

### Resources

**PowerShell**

* [GitHub](https://github.com/PowerShell/PowerShell)
* OCI container: `mcr.microsoft.com/powershell:latest`
* OCI container: `mcr.microsoft.com/azure-cli:latest`

**Azure**

* Portal, CLI, ARM, etc.

---

## Setup

Use [Azure Cloud Shell](https://portal.azure.com/#cloudshell)

```bash
# (Optional if using Cloud Shell)
az login

export AZURE_SUBSCRIPTION_ID=xxx

# Create a service principal scoped to a subscription
az ad sp create-for-rbac \
  --name "azure-sys-check-ps" \
  --role "Contributor" \
  --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}" \
  --sdk-auth
```

---

## Usage

* GitHub action will trigger on push
* Run the PowerShell script from local machine or container
* Requires either service principal credentials (`AZURE_CREDENTIALS`) or interactive login
