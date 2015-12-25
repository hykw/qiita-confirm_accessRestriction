defmodule ConfirmAccessRestriction do

  require Logger
  @cpu_core 4

  def main(), do: main(:dummy)

  def main(_) do
    # テストした環境では並列度は CPU core * 12 ぐらいが限界っぽい
    proc_nums = @cpu_core * 12

    url_lists
    |> Enum.chunk(proc_nums, proc_nums, [])
    |> Enum.map(&(do_check/1))
  end

  defp do_check(urls) do
    urls
    |> Enum.map(&(Task.async(fn -> access_url(&1) end)))
    |> Enum.map(&(Task.await/1))
    |> Enum.map(&(build_results/1))
    |> Enum.sort(&(&1 > &2))
    |> Enum.map(&(IO.puts/1))
  end

  defp access_url(url) do
    # 遅めのサイトが多いなど、必要に応じて 1000～2000位まで
    # 上げるのがいいかと思います。
    timeout = 500
    http_opt = [{:timeout, timeout}, {:recv_timeout, timeout}, {:max_redirect, 1}]

    user_agent = [{"User-agent", "elixir access check"}]

    # HEAD/GET で挙動が違うサイトがあるので GET でアクセスする
    case HTTPoison.get(url, user_agent, http_opt) do
      {:ok, res} -> {:ok, res.status_code, url}
      {:error, reason} -> {:error, reason.reason, url}
    end
  end

  defp build_results(result) do
    # アクセスできなければ OK(つまり 200 はエラー)
    case result do
      {:ok, 200, url} -> "x NG: #{url}(status_code = #{200})"

      # 200以外(401, 404とか)、タイムアウト、その他のエラー（ドメインが存在しないとか）
      # なら、OKとする
      {:ok, status_code, url} -> "o OK: #{url}(status_code = #{status_code})"
      {:error, _connect_timeout, url} -> "o OK: #{url}(timeout)"
      {_, reason, url} -> "o OK: #{url}(reason = #{reason}"
    end
  end


  defp url_lists() do

    # アクセスチェックするURL

    ~w"""
    http://example.co.jp/login/
    http://example.co.jp/admin/

    """
  end

end
