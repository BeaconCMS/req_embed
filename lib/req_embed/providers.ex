defmodule ReqEmbed.Providers do
  @moduledoc false

  @external_resource "priv/vendor/providers.json"

  @providers Path.join([Application.app_dir(:req_embed), "priv/vendor/providers.json"])
             |> File.read!()
             |> Jason.decode!()
             |> Enum.map(fn provider ->
               endpoints =
                 Enum.map(provider["endpoints"] || [], fn endpoint ->
                   %{
                     url: String.replace(endpoint["url"], "{format}", "json") |> URI.new!(),
                     schemes:
                       Enum.map(endpoint["schemes"] || [], fn pattern ->
                         pattern =
                           pattern
                           |> String.replace(".", "\\.")
                           |> String.replace("*", ".*")

                         Regex.compile!(pattern)
                       end)
                   }
                 end)

               %{
                 name: provider["provider_name"],
                 url: provider["provider_url"],
                 endpoints: endpoints
               }
             end)

  def all, do: @providers

  def get_by_url(url) when is_binary(url) do
    Enum.find(@providers, fn provider ->
      Enum.any?(provider.endpoints, fn endpoint ->
        Enum.any?(endpoint.schemes, fn pattern ->
          Regex.match?(pattern, url)
        end)
      end)
    end)
  end
end
