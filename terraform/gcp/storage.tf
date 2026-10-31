resource "google_storage_bucket" "backups" {
  name                        = "proxmox-iac-k3s-lab-backups-mosheazraf"
  location                    = "ME-WEST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  depends_on = [google_project_service.apis]
}
