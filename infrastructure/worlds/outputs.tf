# A tidy summary of every world this stack defines, keyed by world slug.
output "worlds" {
  description = "Per-world service, task definition, EFS access point/directory, and log group"
  value = {
    for name, w in module.world : name => {
      service       = w.service_name
      task_def      = w.task_definition_arn
      access_point  = w.access_point_id
      efs_directory = w.efs_root_directory
      log_group     = w.log_group
      endpoint      = w.nlb_dns_name
    }
  }
}
