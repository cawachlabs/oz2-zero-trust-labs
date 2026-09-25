# M06 · Partner Endpoint — Azure Windows 11 VM

This folder contains the Terraform configuration to deploy the external partner (`partner-01`) workstation in Azure for Module 06.

## Architecture

```text
Workstation (Desktop)                 Azure (East US)
  │                                     │
  │ mstsc (RDP :3389)                   ▼
  └───────────────────────────────>  partner-01 Windows 11 VM
                                        │
                                        │ Ziti Desktop Edge (enrolled partner-01.jwt)
                                        │ (dials portal.meridian.internal)
                                        ▼
                                     er-pub-01 / er-pub-02 (Ingress Edge Routers)
                                        │
                                        ▼
                                     er-pp-01 (Docker on Workstation)
                                        │
                                        ▼
                                     partner-portal (nginx :80)
```

- Reuses existing Resource Group `rg-meridian-ziti-lab-01` and VNet `vnet-meridian-ziti-lab-eus-01`.
- Creates dedicated subnet `snet-partner-eus-01` (`10.10.3.0/24`).
- Windows 11 Pro (`Standard_B2ms`) with RDP enabled.
- Connect via RDP to install Ziti Desktop Edge manually.

## Deployment Steps

1. Copy and edit `terraform.tfvars`:
   ```powershell
   PS> cd oz2-zero-trust-labs\m06-policies-and-services\terraform\azure-partner-vm
   PS> Copy-Item terraform.tfvars.example terraform.tfvars
   ```
   Set your `subscription_id`, `dns_prefix`, and a strong `admin_password`.

2. Initialize and deploy:
   ```powershell
   PS> tofu init
   PS> tofu apply
   ```

3. Connect via Remote Desktop:
   ```powershell
   PS> mstsc /v:(tofu output -raw partner_vm_fqdn)
   ```
   Log in with `azureuser` and your configured password.

4. Install Ziti Desktop Edge and enroll `partner-01`:
   - On the VM, open Edge browser or run PowerShell to download the official ZDEW installer:
     ```powershell
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
     Invoke-WebRequest -Uri 'https://github.com/openziti/desktop-edge-win/releases/download/2.11.3.2/Ziti.Desktop.Edge.Client-2.11.3.2.exe' -OutFile "$HOME\Desktop\Ziti.Desktop.Edge.Client.exe"
     ```
   - Run the installer on the desktop to complete installation.
   - Copy `partner-01.jwt` from your local workstation to the VM desktop (via RDP clipboard).
   - Open **Ziti Desktop Edge** on the VM.
   - Click **Add Identity** → **With JWT** → select `partner-01.jwt`.
   - Complete TOTP enrollment at first sign-in.
   - Verify connection to the partner portal from the VM PowerShell:
     ```powershell
     curl.exe -i http://portal.meridian.internal
     ```

## Cleanup

When finished with M06–M10 testing:
```powershell
terraform destroy
```
*(Only destroys the partner VM and its subnet; does not touch your M03/M04 controllers or routers).*
