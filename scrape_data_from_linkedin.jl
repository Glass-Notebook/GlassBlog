### A Pluto.jl notebook ###
# v0.19.40

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ c9cc8ad2-209b-11ef-0ca4-a31a8e4c77eb
begin
	using HTTP
	using Gumbo
	using AbstractTrees
end

# ╔═╡ ad90096e-980a-44a0-964f-f5ad546070db
using PlutoUI

# ╔═╡ 74b9737f-824a-46f2-bbbe-34774e136f88
TableOfContents()

# ╔═╡ da19ed56-b763-428b-8e7a-4cf62462caf2
md"""
# Find jobs mentions "Julia" in LinkedIn

Do you find job oppotunities that mentions "Julia(Lang)"? Let's scrape data from LinkedIn: https://www.linkedin.com/. This idea is based on [How to Scrape LinkedIn with Python: Step-by-Step Guide](https://www.scraperapi.com/blog/linkedin-scraper-python/) by [Leonardo Rodriguez](https://www.scraperapi.com/author/leo/). This blog post is using Python. In our case, we would like to use Julia!

We have prepared a dashboard displays results based on KEYWORD and LOCATION query.
"""

# ╔═╡ 3c8bf216-0bc0-4992-8c5c-906bd2a67310
md"""
## Dashboard
"""

# ╔═╡ aa8badc3-95d9-4a3b-beb5-dfb94c7baa34
begin
	ui_KEYWORD = @bind KEYWORD confirm(TextField(default="Julia"))
	ui_LOCATION = @bind LOCATION confirm(TextField(default="USA"))
end;

# ╔═╡ b610028a-0066-4310-82c0-4d17472054e5
md"""
KEYWORD: $(ui_KEYWORD)

LOCATION: $(ui_LOCATION)
"""

# ╔═╡ 7e0f8ad6-554d-470a-a20a-f62cb76ee43f
md"""
---
"""

# ╔═╡ aefc60d7-c305-4b0f-9564-788826354d6e
md"""
## How it works

We make a `GET` request to the `url` constructed using the `KEYWORD` and `LOCATION` parameters. This retrieves a list of jobs mentioning the `KEYWORD` and located in the specified `LOCATION`.

To scrape a list of jobs, we use [JuliaWeb/Gumbo.jl](https://github.com/JuliaWeb/Gumbo.jl) for parsing HTML.
"""

# ╔═╡ 49903ea0-ae46-4da8-afa5-97f234cfc048
begin
	# See https://www.scraperapi.com/blog/linkedin-scraper-python/ how to get url
	url = "https://www.linkedin.com/jobs/search?keywords=Julia&location=$(LOCATION)&geoId=&trk=public_jobs_jobs-search-bar_search-submit&position=1&pageNum=0"
	response = HTTP.get(url)
	parsed_response = Gumbo.parsehtml(String(response.body))
	root = parsed_response.root
	htmlelement_body = filter(root.children) do c
		isa(c, HTMLElement{:body})
	end |> first
	nothing
end

# ╔═╡ 54323818-4cba-4f44-9d32-8f39c511c008
"""
	get_job_list(htmlelement_body)

Get a list of jobs from `htmlelement_body`.
"""
function get_job_list(htmlelement_body)
	# This is an extremely complicated code, but it actually works...
	divs = filter(htmlelement_body.children) do c
		isa(c, HTMLElement{:div})
	end
	
	target_div = filter(divs) do d
		d.attributes["class"] == "base-serp-page"
	end |> first

	target_div = filter(target_div.children) do c
		isa(c, HTMLElement{:div})
	end |> first

	target_div.attributes["class"] == "base-serp-page__content"
	div_main = filter(target_div.children) do c
		isa(c, Gumbo.HTMLElement{:main})
	end |> first

	sections = filter(div_main.children) do c
		isa(c, Gumbo.HTMLElement{:section})
	end

	target_section = filter(sections) do s
		s.attributes["class"] == "two-pane-serp-page__results-list"
	end |> first

	target_ul = filter(target_section.children) do c
		isa(c, Gumbo.HTMLElement{:ul})
	end |> first

	target_li_elements = filter(target_ul.children) do c
		isa(c, Gumbo.HTMLElement{:li})
	end
	return target_li_elements
end;

# ╔═╡ 98952a53-3eff-4fd0-aff2-82329889f4c5
begin
	target_li_elements = get_job_list(htmlelement_body)
	ui_index = @bind index Select(collect(keys(target_li_elements)))
	nothing
end

# ╔═╡ 0d8607a2-6f63-499a-802b-4f2a3458d792
md"""
You've found $(length(target_li_elements)) job oppotunities.
"""

# ╔═╡ 9b11b02b-d8b3-4357-b1e0-723310c2b3bd
md"""
$(ui_index)
"""

# ╔═╡ 79bb3079-e344-4bb4-aed9-d9dcf0e79705
md"""
Here, `target_li_elements = get_job_list(htmlelement_body)` contains lots of useful information such as "link to description", "company name", "job title", "modified date".
"""

# ╔═╡ e75f0ae3-b7a2-4b8a-9d70-b151066c6373
li_elem = target_li_elements[index];

# ╔═╡ 51a749e9-ea58-428f-b8c7-c68716c5e804
begin
	function get_link2description(li_elem::HTMLElement{:li})
		return li_elem.children[begin].children[begin].attributes["href"]
	end
	
	function get_companyname(li_elem::HTMLElement{:li})
		target_div = li_elem.children[begin].children[end]
		
		h4 = filter(target_div.children) do c
			isa(c, Gumbo.HTMLElement{:h4})
		end |> first
		
		company_name = h4.children[1][1].text|> lstrip |> rstrip
		return company_name
	end

	function get_jobtitle(li_elem::HTMLElement{:li})
		target_div = li_elem.children[begin].children[end]
		h3 = filter(target_div.children) do c
			isa(c, Gumbo.HTMLElement{:h3})
		end |> first
		
		job_title = h3.children[1].text |> lstrip |> rstrip
		return job_title
	end

	function get_lastupdated(li_elem::HTMLElement{:li})
		try
			target_div = li_elem.children[begin].children[end]
			div = filter(target_div.children) do c
				isa(c, Gumbo.HTMLElement{:div})
			end |> first
			
			location = div[1].children[1].text |> lstrip |> rstrip
			lastupdated = div[3].children[1].text |> lstrip |> rstrip
		catch
			nothing
		end
	end
end

# ╔═╡ 622f778f-3aad-4029-b69f-719ad8f76214
HTML("""
<h4>index=$(index)</h4>

<li>
Title: $(get_jobtitle(li_elem))
</li>
<li>
Company name: $(get_companyname(li_elem))
</li>
<li>
Last Updated: $(get_lastupdated(li_elem))
</li>
<li>
<a href=$(get_link2description(li_elem))>link to job description</a>
</li>
"""
)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AbstractTrees = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
Gumbo = "708ec375-b3d6-5a57-a7ce-8257bf98657a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
AbstractTrees = "~0.4.5"
Gumbo = "~0.8.2"
HTTP = "~1.10.8"
PlutoUI = "~0.7.59"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.4"
manifest_format = "2.0"
project_hash = "99977be56e5ce612e0e4c2c6bc916b8d8542ceec"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitFlags]]
git-tree-sha1 = "2dc09997850d68179b69dafb58ae806167a32b1b"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.8"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "59939d8a997469ee05c4b4944560a820f9ba0d73"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.4"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "6cbbd4d241d7e6579ab354737f4dd95ca43946e1"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.1"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "dcb08a0d93ec0b1cdc4af184b26b591e9695423a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.10"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Gumbo]]
deps = ["AbstractTrees", "Gumbo_jll", "Libdl"]
git-tree-sha1 = "a1a138dfbf9df5bace489c7a9d5196d6afdfa140"
uuid = "708ec375-b3d6-5a57-a7ce-8257bf98657a"
version = "0.8.2"

[[deps.Gumbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "29070dee9df18d9565276d68a596854b1764aa38"
uuid = "528830af-5a63-567c-a44a-034ed33b8444"
version = "0.10.2+0"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "d1d712be3164d61d1fb98e7ce9bcbc6cc06b45ed"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.8"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "8b72179abc660bfab5e28472e019392b97d0985c"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.4"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7e5d6779a1e09a36db2a7b6cff50942a0a7d0fca"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.5.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "c1dd6d7978c12545b4179fb6153b9250c96b0075"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.3"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3da7367955dcc5c54c1ba4d402ccdc09a1a3e046"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.13+1"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "ab55ee1510ad2af0ff674dbcced5e94921f867a9"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.59"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
git-tree-sha1 = "5d54d076465da49d6746c647022f3b3674e64156"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.8"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

[[deps.Tricks]]
git-tree-sha1 = "eae1bb484cd63b36999ee58be2de6c178105112f"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.8"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╠═c9cc8ad2-209b-11ef-0ca4-a31a8e4c77eb
# ╠═ad90096e-980a-44a0-964f-f5ad546070db
# ╠═74b9737f-824a-46f2-bbbe-34774e136f88
# ╟─da19ed56-b763-428b-8e7a-4cf62462caf2
# ╟─3c8bf216-0bc0-4992-8c5c-906bd2a67310
# ╠═aa8badc3-95d9-4a3b-beb5-dfb94c7baa34
# ╟─b610028a-0066-4310-82c0-4d17472054e5
# ╟─98952a53-3eff-4fd0-aff2-82329889f4c5
# ╟─0d8607a2-6f63-499a-802b-4f2a3458d792
# ╟─9b11b02b-d8b3-4357-b1e0-723310c2b3bd
# ╟─622f778f-3aad-4029-b69f-719ad8f76214
# ╟─7e0f8ad6-554d-470a-a20a-f62cb76ee43f
# ╟─aefc60d7-c305-4b0f-9564-788826354d6e
# ╠═49903ea0-ae46-4da8-afa5-97f234cfc048
# ╠═54323818-4cba-4f44-9d32-8f39c511c008
# ╟─79bb3079-e344-4bb4-aed9-d9dcf0e79705
# ╠═e75f0ae3-b7a2-4b8a-9d70-b151066c6373
# ╠═51a749e9-ea58-428f-b8c7-c68716c5e804
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
