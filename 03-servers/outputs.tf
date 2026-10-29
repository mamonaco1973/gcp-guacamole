# ==============================================================================
# Outputs (read by validate.sh)
# ==============================================================================

output "guacamole_url" {
  description = "Guacamole sign-in page (self-signed certificate)"
  value       = "https://${google_compute_global_address.guacamole.address}/"
}

output "backend_service_name" {
  description = "Load balancer backend service in front of Guacamole"
  value       = google_compute_backend_service.guacamole.name
}

output "guacamole_vm_name" {
  description = "Guacamole server (private)"
  value       = google_compute_instance.guacamole.name
}

output "mate_vm_name" {
  description = "MATE desktop host (private)"
  value       = google_compute_instance.mate.name
}

output "windows_vm_name" {
  description = "Windows host (private)"
  value       = google_compute_instance.windows.name
}

output "zone" {
  description = "Zone of the servers"
  value       = var.zone
}
