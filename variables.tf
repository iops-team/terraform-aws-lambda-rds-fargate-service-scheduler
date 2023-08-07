variable "events" {
  description = "Map of event objects"
  type = map(object({
    desired_count            = optional(string)
    tag_key                  = string
    tag_value                = string
    cron_schedule_expression = string
    rds_action               = string
  }))
  default = {}
}

variable "timeout" {
  default     = 60
  type        = number
  description = "Lambda functions have a timeout of 60 seconds. When the Lambda service first launched, it allowed a maximum of only 900 seconds"
}

variable "event_description" {
  description = "Cloudwatch event description"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}