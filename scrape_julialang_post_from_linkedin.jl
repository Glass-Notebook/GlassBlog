### A Pluto.jl notebook ###
# v0.19.43

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

# ╔═╡ ea8534d0-3217-11ef-16ee-ed791b315d4e
begin
	using Pkg
	Pkg.activate(temp=true)
	Pkg.add(
		url="https://github.com/terasakisatoshi/WebDriver.jl", rev="terasaki/glass-notebook-patch"
	)
	Pkg.add(["AbstractTrees", "CondaPkg", "DotEnv","Gumbo", "PythonCall"])
	Pkg.add("PlutoUI")
	
	using AbstractTrees
	using CondaPkg
	using DotEnv
	using Gumbo
	using WebDriver

	CondaPkg.add("python", version="3.11", channel="conda-forge")
	CondaPkg.add_pip("selenium")
	CondaPkg.add_pip("chromedriver-binary")

	using PythonCall
	webdriver = pyimport("selenium.webdriver")
end

# ╔═╡ e182b627-a743-43c8-b3b5-e17bcfb8270b
using PlutoUI

# ╔═╡ 52a68121-06b7-41f4-93b9-e4ff52303dc9
md"""
In this notebook, we aim to collect JuliaLang's posts from LinkedIn. We utilize WebDriver.jl to automate web browser operations and sign in to LinkedIn,
subsequently capturing the HTML elements that contain JuliaLang's posts.

To set up a development environment easily, we leverage Python's `selenium` and `chromedriver-binary` packages through CondaPkg.jl.

Before running this notebook, store `LINKEDIN_USERNAME` and `LINKEDIN_PASSWORD` in `.env` so that you can sign in to LinkedIn through WebDriver.jl.

```
# .env
LINKEDIN_USERNAME="your-linkedin-username"
LINKEDIN_PASSWORD="your-password"
```
"""

# ╔═╡ 07e3fbd7-2059-45e0-9132-651dff7ec923
begin
	driver = webdriver.Chrome() # Python object
	command_executor_url = pyconvert(String, driver.command_executor._url)::String
	
	m = match(r"http://[^:]+:(?P<port>\d+)", command_executor_url)
	_port = m.captures |> only
	m = match(r"http://(?P<hostname>[^:]+)", command_executor_url)
	host = m.captures |> only
	
	port = parse(Int, _port)
	
	capabilities = Capabilities("chrome")
	
	wd = RemoteWebDriver(
	    capabilities;
	    host, port
	)
	
	# close the default session binded by Python process
	driver.close()
end

# ╔═╡ 9a7e496a-8424-4920-8f71-d9ab2e00fbb4
# Prepare `.env` file and store `USERNAME` and `PASSWORD`
DotEnv.load!(".env")

# ╔═╡ ed4c1730-087e-4a6b-a3cc-60981768616c
begin
	# New Session
	session = Session(wd)
	
	#Open login page
	navigate!(session, "https://www.linkedin.com/login")
	
	username = Element(session, "css selector", "username")
	password = Element(session, "css selector", "password")
	login_button = Element(session, "class name", "btn__primary--large")
	sleep(rand())
	element_keys!(username, ENV["LINKEDIN_USERNAME"])
	sleep(rand())
	element_keys!(password, ENV["LINKEDIN_PASSWORD"])
	sleep(rand())
	click!(login_button)
end

# ╔═╡ 2379fe80-88b2-4b4f-b98c-3cc831ec7d53
begin
	navigate!(session, "https://www.linkedin.com/company/the-julia-language/posts/")
end

# ╔═╡ 61278ed8-72b8-482f-84b3-fb8baa7170fc
begin
	SCROLL_COMMAND = "window.scrollTo(0, document.body.scrollHeight);"
	GET_SCROLL_HEIGHT_COMMAND = "return document.body.scrollHeight"
	last_height = script!(session, GET_SCROLL_HEIGHT_COMMAND)
	scrolls = 0
	no_change_count = 0
	for _ in 1:3
	    global no_change_count, last_height, scrolls
	    script!(session, SCROLL_COMMAND)
	    sleep(1.5)
	    new_height = script!(session, GET_SCROLL_HEIGHT_COMMAND)
	    # Increment no change count or reset it
	    no_change_count = new_height == last_height ?  no_change_count + 1 : 0
	    # Break loop if the scroll height has not changed for 3 cycles or reached the maximum scrolls
	    if no_change_count >= 3
	        break
	    end
	    last_height = new_height
	    scrolls += 1
	end
	
	linkedin_posts_str = source(session)
	window_close!(session)
end

# ╔═╡ 81ed364a-2002-447f-a1a7-fd05405a94c3
begin
	parsed_html = Gumbo.parsehtml(linkedin_posts_str)
	root = parsed_html.root
	htmlelement_body = filter(root.children) do c
		c isa Gumbo.HTMLElement{:body}
	end |> only
	
	spans = filter(collect(PreOrderDFS(root))) do e
		if e isa Gumbo.HTMLElement{:span}
			cs = get(e.attributes, "class", nothing)
			isnothing(cs) && return false
			if split(cs) == ["break-words", "tvm-parent-container"]
				return true
			end
			return false
		else
			return false
		end
	end
	nothing
end

# ╔═╡ 5c77104f-8a49-45b9-bef5-616d4bd10afc
function extractpost(s)
	texts = String[]
	for e in PreOrderDFS(s)
		if e isa Gumbo.HTMLElement{:span}
			for c in PreOrderDFS(e)
				if c isa Gumbo.HTMLText
					if get(c.parent.attributes, "class", "") == "visually-hidden"
						continue
					end
					push!(texts, c.text)
				end
			end
		end
		break
	end
	# post process text merge hashtag
	ishastag = false
	ishastagname = false
	text = ""
	for t in texts
		ishastag = (t == "#")
		if ishastag
			s = isspace(text[lastindex(text)]) ? "" : " "
			text *= s * t
			ishastagname = true
		elseif ishastagname
			text *= t * " "
			# reset
			ifhashtagname = false
		else
			text *= t
		end
			
	end
	println(text)
end

# ╔═╡ 91e12d5c-e3f6-4aee-95fa-9ae8c34d9192
@bind nth Select(eachindex(spans))

# ╔═╡ 44005657-9cfb-41af-b78a-3dcc5f1b5906
begin
	s = spans[nth]
	extractpost(s)
end

# ╔═╡ 7280054f-c556-4b39-81e6-deb0f20ca2db
md"""
# References

- [christophegaron's blog post: Scraping Linkedin Posts With Selenium & Beautiful Soup](https://christophegaron.com/articles/mind/automation/scraping-linkedin-posts-with-selenium-and-beautiful-soup/#google_vignette)
- [Ron Erdos's blog post: How to scrape web pages with Julia](https://julia.school/julia/scraping/)
"""

# ╔═╡ Cell order:
# ╟─52a68121-06b7-41f4-93b9-e4ff52303dc9
# ╠═ea8534d0-3217-11ef-16ee-ed791b315d4e
# ╠═e182b627-a743-43c8-b3b5-e17bcfb8270b
# ╠═07e3fbd7-2059-45e0-9132-651dff7ec923
# ╠═9a7e496a-8424-4920-8f71-d9ab2e00fbb4
# ╠═ed4c1730-087e-4a6b-a3cc-60981768616c
# ╠═2379fe80-88b2-4b4f-b98c-3cc831ec7d53
# ╠═61278ed8-72b8-482f-84b3-fb8baa7170fc
# ╠═81ed364a-2002-447f-a1a7-fd05405a94c3
# ╠═5c77104f-8a49-45b9-bef5-616d4bd10afc
# ╠═91e12d5c-e3f6-4aee-95fa-9ae8c34d9192
# ╠═44005657-9cfb-41af-b78a-3dcc5f1b5906
# ╟─7280054f-c556-4b39-81e6-deb0f20ca2db
