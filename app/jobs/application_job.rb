class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Chamadas à API de validação feitas pelo job levam o id do job como X-Request-ID.
  around_perform do |job, block|
    Current.set(request_id: "job-#{job.job_id}") { block.call }
  end
end
