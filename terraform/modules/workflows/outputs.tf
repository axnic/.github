output "files" {
  description = "Caller workflow file names generated in .github/workflows/ of the repository."
  value       = sort(keys(local.callers))
}
