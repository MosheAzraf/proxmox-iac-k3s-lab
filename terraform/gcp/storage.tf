resource "google_storage_bucket" "backups" {
  name                        = "proxmox-iac-lab-backups"
  location                    = "ME-WEST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age            = 30
      matches_prefix = ["k3s/"]
      matches_suffix = [".tar.gz"]
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_object" "k3s" {
  name    = "k3s/"
  content = " "
  bucket  = google_storage_bucket.backups.name
}


# Optional:
# Additional subfolders for PVC backups can be added in the future.
# For now, this project focuses only on k3s backup and restore.
