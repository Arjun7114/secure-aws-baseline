output "web_server_public_ip" {
  description = "The public IP to access the web server"
  value       = module.compute.public_ip
}