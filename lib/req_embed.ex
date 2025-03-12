defmodule ReqEmbed do
  @moduledoc """
  oEmbed for Req

  Supports [discovery](https://oembed.com/#section4) and #{length(ReqEmbed.Providers.all())} providers.
  """

  @doc """
  Attach the oEmbed plugin into Req.

  ## Options

    * `:query` (t:map/0) - Defaults to `%{}`. The query parameters to be sent to the oEmbed endpoint.
      The parameters `:url` and `:format` are managed by the plugin, you can't override them.
      See section [2.2 Consumer Request](https://oembed.com/#section2) for more info.

  """
  @spec attach(Req.Request.t(), keyword()) :: Req.Request.t()
  def attach(%Req.Request{} = request, options \\ []) do
    request
    |> Req.Request.register_options([:oembed_query])
    |> Req.Request.merge_options(oembed_query: options[:query] || %{})
    |> Req.Request.prepend_request_steps(oembed_url: &oembed_url/1)
    |> Req.Request.append_response_steps(oembed_decode: &decode/1)
  end

  defp oembed_url(request) do
    case find_endpoint(request) do
      %URI{} = uri ->
        query =
          request
          |> Req.Request.get_option(:oembed_query)
          |> Map.put(:format, "json")
          |> URI.encode_query()

        %{request | url: URI.append_query(uri, query)}

      _ ->
        # TODO: error
        request
    end
  end

  defp find_endpoint(request) do
    case discover_link(to_string(request.url)) do
      %URI{} = uri -> uri
      _ -> discover_provider(to_string(request.url))
    end
  end

  @doc false
  def discover_link(url) when is_binary(url) do
    with {:ok, %{body: body}} <- Req.get(url),
         {:ok, doc} <- Floki.parse_document(body),
         [href] <- Floki.attribute(doc, ~s|link[type="application/json+oembed"]|, "href"),
         {:ok, uri} <- URI.new(href) do
      uri
    else
      _ -> nil
    end
  end

  @doc false
  def discover_provider(url) when is_binary(url) do
    case ReqEmbed.Providers.get_by_url(url) do
      %{endpoints: [%{url: url} | _]} -> url
      _ -> nil
    end
  end

  defp decode({request, %{status: 200} = response}) do
    if request.options[:raw] == true or request.options[:decode_body] == false do
      {request, response}
    else
      {request, update_in(response.body, &decode_oembed_response/1)}
    end
  end

  defp decode({request, response}) do
    {request, response}
  end

  defp decode_oembed_response(%{"type" => "photo"} = body) do
    %ReqEmbed.Photo{
      type: body["type"],
      version: body["version"],
      title: body["title"],
      author_name: body["author_name"],
      author_url: body["author_url"],
      provider_name: body["provider_name"],
      provider_url: body["provider_url"],
      cache_age: body["cache_age"],
      thumbnail_url: body["thumbnail_url"],
      thumbnail_width: body["thumbnail_width"],
      thumbnail_height: body["thumbnail_height"],
      url: body["url"],
      width: body["width"],
      height: body["height"]
    }
  end

  defp decode_oembed_response(%{"type" => "video"} = body) do
    %ReqEmbed.Video{
      type: body["type"],
      version: body["version"],
      title: body["title"],
      author_name: body["author_name"],
      author_url: body["author_url"],
      provider_name: body["provider_name"],
      provider_url: body["provider_url"],
      cache_age: body["cache_age"],
      thumbnail_url: body["thumbnail_url"],
      thumbnail_width: body["thumbnail_width"],
      thumbnail_height: body["thumbnail_height"],
      html: body["html"],
      width: body["width"],
      height: body["height"]
    }
  end

  defp decode_oembed_response(%{"type" => "rich"} = body) do
    %ReqEmbed.Rich{
      type: body["type"],
      version: body["version"],
      title: body["title"],
      author_name: body["author_name"],
      author_url: body["author_url"],
      provider_name: body["provider_name"],
      provider_url: body["provider_url"],
      cache_age: body["cache_age"],
      thumbnail_url: body["thumbnail_url"],
      thumbnail_width: body["thumbnail_width"],
      thumbnail_height: body["thumbnail_height"],
      html: body["html"],
      width: body["width"],
      height: body["height"]
    }
  end

  defp decode_oembed_response(%{"type" => "link"} = body) do
    %ReqEmbed.Link{
      type: body["type"],
      version: body["version"],
      title: body["title"],
      author_name: body["author_name"],
      author_url: body["author_url"],
      provider_name: body["provider_name"],
      provider_url: body["provider_url"],
      cache_age: body["cache_age"],
      thumbnail_url: body["thumbnail_url"],
      thumbnail_width: body["thumbnail_width"],
      thumbnail_height: body["thumbnail_height"]
    }
  end

  defp decode_oembed_response(body) do
    %ReqEmbed.Content{
      type: body["type"],
      version: body["version"],
      title: body["title"],
      author_name: body["author_name"],
      author_url: body["author_url"],
      provider_name: body["provider_name"],
      provider_url: body["provider_url"],
      cache_age: body["cache_age"],
      thumbnail_url: body["thumbnail_url"],
      thumbnail_width: body["thumbnail_width"],
      thumbnail_height: body["thumbnail_height"]
    }
  end
end
