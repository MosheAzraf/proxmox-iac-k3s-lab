resource "google_project_service" "iam_api" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_credentials_api" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "ansible_backup" {
  account_id   = "ansible-backup"
  display_name = "Ansible GCS Backup"

  depends_on = [google_project_service.iam_api]
}

resource "google_storage_bucket_iam_member" "ansible_backup_create" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.ansible_backup.email}"
}

resource "google_storage_bucket_iam_member" "ansible_backup_read" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.ansible_backup.email}"
}
