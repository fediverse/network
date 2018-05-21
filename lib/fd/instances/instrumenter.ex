defmodule Fd.Instances.Instrumenter do
  @moduledoc """
  # Instances Instrumenter

  This is a Prometheus Instrumenter for the various operations in `Fd.Instances.Server` and `Fd.Instances.Crawler`.

  ## Crawler Metrics (fdc_)

  * http requests:
    * fdc_http_requests_total (count)
      * {status, request_path}
    * fdc_http_request_duration_microseconds (histogram)
      * {status_class, request_path}
  * pipeline runs:
    * fdc_pipelines_total (count)
      * {result}
    * fdc_pipeline_duration_microseconds (histogram)
    * fdc_pipeline_mod_duration_microseconds (histogram)
      * duration of each module in the pipeline
      * {module}

  """
  use Prometheus.Metric

  def setup() do
    Counter.declare([name: :fdc_http_requests_total,
                     help: "Crawler HTTP requests total",
                     labels: [:status, :request_path, :result]])
    Counter.declare([name: :fdc_http_retries_total,
                     help: "Crawler HTTP requests total",
                     labels: []])

    Histogram.new([name: :fdc_http_request_duration_microseconds,
                   labels: [:status, :request_path, :result],
                   buckets: [100, 300, 500, 750, 1000],
                   help: "Crawler HTTP requests ."])
  end

  def http_request(path, response, start) do
    stop = :erlang.monotonic_time
    duration = stop - start
    time = :erlang.convert_time_unit(duration, :native, :microsecond)
    {status, result} = case response do
      %HTTPoison.Response{status_code: code} -> {code, "ok"}
      %HTTPoison.Error{reason: reason} -> {"0", inspect(reason)}
      _error -> {"0", "error"}
    end
    Counter.inc([name: :fdc_http_requests_total, labels: [status, path, result]])
    Histogram.observe([name: :fdc_http_request_duration_microseconds, labels: [simplify_status(status), path, result]], time)
  end

  def retry_http_request() do
    Counter.inc([name: :fdc_http_retries_total, labels: []])
  end

  defp simplify_status("0"), do: "0"
  defp simplify_status(status) when is_integer(status), do: simplify_status(to_string(status))
  defp simplify_status(<<x::bytes-size(1)>><>_) when x in ["2", "3", "4", "5"] do
    x <> "xx"
  end
  defp simplify_status(status), do: status


end
